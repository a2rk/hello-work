// MenubarHiderController.swift — Ice-style hider.
// Один наш status item (H), физическое перемещение чужих items за край экрана
// через CGEvent simulation. Адаптация подхода Ice (https://github.com/jordanbaird/Ice) — GPLv3.

import AppKit
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

    private var lastAutoState: Bool? = nil
    private var isToggling = false

    /// Callback при создании mainItem (AppDelegate переустанавливает menu).
    var onMainItemReady: ((NSStatusItem) -> Void)?

    init() {}

    // MARK: - Configuration

    func configure(hiderEnabled: Bool, initialCollapsed: Bool, iconStyle: StatusIconStyle) {
        tearDownItems()
        currentIconStyle = iconStyle

        createMain(iconStyle: iconStyle)

        enabled = hiderEnabled
        isCollapsed = false
        updateMainIcon(style: iconStyle)

        if hiderEnabled && initialCollapsed {
            // Применяем persist через 1с после init — даём menubar layout устаканиться.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self, self.enabled else { return }
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
    }

    func updateMainIcon(style: StatusIconStyle) {
        currentIconStyle = style
        mainItem?.button?.image = MenuBarIcon.make(style: style, collapsed: isCollapsed)
    }

    // MARK: - Public toggle API

    func toggle() {
        guard enabled, !isToggling else { return }
        isToggling = true
        if isCollapsed {
            expandInternal()
        } else {
            collapseInternal()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isToggling = false
        }
        lastAutoState = nil
    }

    func collapseAll() {
        guard enabled else { return }
        collapseInternal()
        lastAutoState = nil
    }

    func expandAll() {
        guard enabled else { return }
        expandInternal()
        lastAutoState = nil
    }

    func applyAuto(collapsed: Bool) {
        guard enabled else { return }
        if let last = lastAutoState, last == isCollapsed {
            // мы сами поставили
        } else if lastAutoState != nil {
            lastAutoState = collapsed
            return
        }
        if isCollapsed != collapsed {
            if collapsed {
                collapseInternal()
            } else {
                expandInternal()
            }
        }
        lastAutoState = collapsed
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
        guard !isCollapsed else { return }

        // Сохраняем текущий список hideable items + их X-координаты.
        let items = MenuBarItem.currentItems().filter { $0.isHideable }
        savedItems = items
        savedPositions = Dictionary(uniqueKeysWithValues: items.map { ($0.windowID, $0.frame.midX) })

        // Двигаем всех за левый край.
        for item in items {
            MenuBarItemMover.hide(item)
            // Маленькая задержка между items — чтобы macOS успевал обработать каждый event.
            Thread.sleep(forTimeInterval: 0.02)
        }

        isCollapsed = true
        updateMainIcon(style: currentIconStyle)
    }

    private func expandInternal() {
        guard isCollapsed else { return }
        restoreAllItems()
        isCollapsed = false
        updateMainIcon(style: currentIconStyle)
    }

    private func restoreAllItems() {
        // Восстанавливаем в сохранённые позиции.
        // Двигаем в обратном порядке — сначала те что были левее (минимальный X),
        // чтобы они оказались на своих местах когда правые items ещё не вставлены.
        for item in savedItems.sorted(by: { $0.frame.midX < $1.frame.midX }) {
            // Получаем актуальный item (frame мог измениться).
            let current = MenuBarItem.currentItems().first { $0.windowID == item.windowID } ?? item
            if let originalX = savedPositions[item.windowID] {
                MenuBarItemMover.restore(current, toX: originalX)
                Thread.sleep(forTimeInterval: 0.02)
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
        // Это упрощение — в дальнейшем можно добавить cmd+click → toggle.
    }
}
