// MenubarHiderController.swift — Ice-style hider.
// Один наш status item (H), физическое перемещение чужих items за край экрана
// через CGEvent simulation. Адаптация подхода Ice (https://github.com/jordanbaird/Ice) — GPLv3.

import AppKit
import ApplicationServices
import Combine

@MainActor
final class MenubarHiderController: ObservableObject {
    @Published private(set) var isCollapsed: Bool = false
    @Published private(set) var enabled: Bool = false

    private(set) var mainItem: NSStatusItem?
    private var currentIconStyle: StatusIconStyle = .solid

    /// Сохранённые позиции items при collapse — для восстановления при expand.
    /// Key: windowID, Value: original X на экране.
    private var savedPositions: [CGWindowID: CGFloat] = [:]
    /// Сохранённые items с их полными данными (нужны для restore через mover).
    private var savedItems: [MenuBarItem] = []

    /// Последний auto-сигнал, переданный в `applyAuto` (focus-mode / schedule).
    /// Семантика: применяем auto только когда СИГНАЛ изменился. Если сигнал
    /// не менялся, а юзер успел вручную переключить — не лезем поверх его выбора.
    private var lastAutoIntent: Bool? = nil
    private var isToggling = false

    /// Токен deferred-collapse'а из `configure(initialCollapsed: true)`.
    /// Любой пользовательский toggle/applyAuto/peek — invalidate'ит его,
    /// так что отложенный через 1с collapse не отменяет уже выбранное состояние.
    private var deferredCollapseToken: UUID?

    /// Callback при создании mainItem (AppDelegate переустанавливает menu).
    var onMainItemReady: ((NSStatusItem) -> Void)?

    /// Срабатывает, когда collapse заблокирован отсутствием Accessibility —
    /// AppDelegate показывает prompt и/или открывает System Settings.
    var onAccessibilityRequired: (() -> Void)?

    init() {}

    // MARK: - Configuration

    func configure(hiderEnabled: Bool, initialCollapsed: Bool, iconStyle: StatusIconStyle) {
        devlog("hider", "configure(hiderEnabled=\(hiderEnabled), initialCollapsed=\(initialCollapsed), iconStyle=\(iconStyle.rawValue))")
        tearDownItems()
        currentIconStyle = iconStyle

        createMain(iconStyle: iconStyle)

        enabled = hiderEnabled
        isCollapsed = false
        updateMainIcon(style: iconStyle)

        if hiderEnabled && initialCollapsed {
            let token = UUID()
            deferredCollapseToken = token
            // Применяем persist через 1с после init — даём menubar layout устаканиться.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self, self.enabled else { return }
                guard self.deferredCollapseToken == token else {
                    devlog("hider", "deferred initialCollapsed cancelled — user или auto уже изменили состояние")
                    return
                }
                self.deferredCollapseToken = nil
                devlog("hider", "deferred initialCollapsed → collapseInternal")
                self.collapseInternal()
            }
        }
    }

    func tearDown() {
        // На выход — гарантируем что чужие items вернутся на места.
        if isCollapsed {
            restoreAllItems()
        }
        tearDownItems()
        enabled = false
        isCollapsed = false
        deferredCollapseToken = nil
    }

    func updateMainIcon(style: StatusIconStyle) {
        currentIconStyle = style
        mainItem?.button?.image = MenuBarIcon.make(style: style, collapsed: isCollapsed)
    }

    // MARK: - Public toggle API

    func toggle() {
        devlog("hider", "toggle() called — enabled=\(enabled), isToggling=\(isToggling), isCollapsed=\(isCollapsed)")
        guard enabled, !isToggling else {
            devlog("hider", "toggle() — guard rejected")
            return
        }
        deferredCollapseToken = nil  // юзер выбрал — отложенный collapse отменён
        isToggling = true
        if isCollapsed {
            expandInternal()
        } else {
            collapseInternal()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isToggling = false
        }
        // НЕ обнуляем lastAutoIntent — наоборот, держим его, чтобы повторные
        // applyAuto с тем же сигналом (что было ДО toggle) не возвращали
        // состояние «как auto хочет». Юзер сам выбрал — auto уважит до тех
        // пор, пока сам сигнал не изменится.
    }

    func collapseAll() {
        guard enabled else { return }
        deferredCollapseToken = nil
        collapseInternal()
    }

    func expandAll() {
        guard enabled else { return }
        deferredCollapseToken = nil
        expandInternal()
    }

    /// Применяем auto-сигнал (focus-mode / schedule) только когда он ИЗМЕНИЛСЯ.
    /// Если signal == lastAutoIntent → значит источник auto не менялся,
    /// и если юзер за это время вручную переключил — оставляем его выбор.
    func applyAuto(collapsed: Bool) {
        guard enabled else { return }
        if lastAutoIntent == collapsed {
            devlog("hider", "applyAuto(\(collapsed)) — signal unchanged, respect user")
            return
        }
        devlog("hider", "applyAuto(\(collapsed)) — signal changed (was \(lastAutoIntent.map(String.init(describing:)) ?? "nil"))")
        lastAutoIntent = collapsed
        deferredCollapseToken = nil  // auto-сигнал перетёр initialCollapsed
        if isCollapsed != collapsed {
            if collapsed {
                collapseInternal()
            } else {
                expandInternal()
            }
        }
    }

    /// Временно раскрыть menubar на N секунд при peek.
    /// Если уже expanded — игнор.
    private var peekTimer: Timer?
    func peek(seconds: Int) {
        guard enabled, seconds > 0, isCollapsed else { return }
        expandInternal()
        peekTimer?.invalidate()
        let t = Timer(timeInterval: TimeInterval(seconds), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.collapseInternal() }
        }
        RunLoop.main.add(t, forMode: .common)
        peekTimer = t
    }

    // MARK: - Internal collapse/expand

    private func collapseInternal() {
        guard !isCollapsed else {
            devlog("hider", "collapseInternal — already collapsed, skip")
            return
        }

        let trusted = AXIsProcessTrusted()
        let sr = CGPreflightScreenCaptureAccess()
        devlog("hider", "collapseInternal — AXIsProcessTrusted=\(trusted) ScreenRecording=\(sr)")
        guard trusted else {
            onAccessibilityRequired?()
            return
        }

        let all = MenuBarItem.currentItems()
        let items = all.filter { $0.isHideable }
        devlog("hider", "currentItems total=\(all.count) hideable=\(items.count)")
        for item in all {
            devlog("hider.item",
                   "wid=\(item.windowID) pid=\(item.pid) bid=\(item.bundleID ?? "nil") owner=\(item.ownerName ?? "nil") midX=\(String(format: "%.0f", item.frame.midX)) hideable=\(item.isHideable)")
        }
        guard !items.isEmpty else {
            devlog("hider", "collapseInternal — nothing hideable, abort")
            return
        }

        savedItems = items
        savedPositions = Dictionary(uniqueKeysWithValues: items.map { ($0.windowID, $0.frame.midX) })

        // Берём актуальный frame через дешёвый CGS-запрос на ОДНО окно
        // (Bridging.getWindowFrame) вместо полного перечисления menubar
        // (MenuBarItem.currentItems) на каждой итерации цикла.
        var movedAny = false
        for item in items.sorted(by: { $0.frame.midX > $1.frame.midX }) {
            let liveFrame = Bridging.getWindowFrame(for: item.windowID) ?? item.frame
            let current = MenuBarItem(
                windowID: item.windowID,
                pid: item.pid,
                frame: liveFrame,
                title: item.title,
                ownerName: item.ownerName
            )
            let beforeX = current.frame.midX
            let ok = MenuBarItemMover.hide(current)
            let afterFrame = Bridging.getWindowFrame(for: item.windowID)
            let afterX = afterFrame?.midX ?? .nan
            devlog("hider.move",
                   "hide wid=\(item.windowID) before=\(String(format: "%.0f", beforeX)) after=\(String(format: "%.0f", afterX)) success=\(ok)")
            if ok { movedAny = true }
            Thread.sleep(forTimeInterval: 0.03)
        }

        guard movedAny else {
            devlog("hider", "collapseInternal — movedAny=false, rolling back")
            if !CGPreflightScreenCaptureAccess() {
                devlog("hider", "hint: Screen Recording НЕ выдан — Sequoia требует его для drag'а menubar items")
                onAccessibilityRequired?()
            }
            savedItems.removeAll()
            savedPositions.removeAll()
            return
        }

        isCollapsed = true
        updateMainIcon(style: currentIconStyle)
        devlog("hider", "collapseInternal done — isCollapsed=true")
    }

    private func expandInternal() {
        devlog("hider", "expandInternal — isCollapsed=\(isCollapsed) saved=\(savedItems.count)")
        guard isCollapsed else { return }
        restoreAllItems()
        isCollapsed = false
        updateMainIcon(style: currentIconStyle)
        devlog("hider", "expandInternal done")
    }

    private func restoreAllItems() {
        guard AXIsProcessTrusted() else {
            // Без AX откатить не сможем — просто чистим state, чтобы не зависнуть.
            savedItems.removeAll()
            savedPositions.removeAll()
            return
        }
        // Восстанавливаем слева направо: сначала те что были левее,
        // чтобы они «упёрлись» в левый край и более правые встали корректно.
        // Frame обновляем через лёгкий per-window CGS-запрос вместо полного перечисления.
        for item in savedItems.sorted(by: { $0.frame.midX < $1.frame.midX }) {
            let liveFrame = Bridging.getWindowFrame(for: item.windowID) ?? item.frame
            let current = MenuBarItem(
                windowID: item.windowID,
                pid: item.pid,
                frame: liveFrame,
                title: item.title,
                ownerName: item.ownerName
            )
            if let originalX = savedPositions[item.windowID] {
                MenuBarItemMover.restore(current, toX: originalX)
                Thread.sleep(forTimeInterval: 0.03)
            }
        }
        savedItems.removeAll()
        savedPositions.removeAll()
    }

    // MARK: - Build items

    private func createMain(iconStyle: StatusIconStyle) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = MenuBarIcon.make(style: iconStyle, collapsed: isCollapsed)
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(mainClicked)
        item.button?.sendAction(on: [.leftMouseUp])
        item.autosaveName = "helloWork_main"
        mainItem = item
        onMainItemReady?(item)
    }

    private func tearDownItems() {
        if let m = mainItem { NSStatusBar.system.removeStatusItem(m) }
        mainItem = nil
    }

    // MARK: - Click

    /// Правый/option-click → toggle. Обычный click → menu (через item.menu).
    @objc private func mainClicked() {
        // sendAction(on:) ставим только .leftMouseUp выше → этот метод вызывается на клик
        // только при leftMouseUp. Обычный click открывает menu (если установлено).
        // Toggle делается через хоткей или menu item.
        devlog("hider", "mainClicked() fired (action selector — usually overshadowed by item.menu)")
    }
}
