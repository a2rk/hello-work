import AppKit
import Combine

/// Точная копия Hidden Bar approach (https://github.com/dwarvesf/hidden) с одной нашей
/// надстройкой: между chevron и separator стоит main item с H + menu, всегда видимый.
///
/// Layout (LTR, X слева направо):
///   [items дрэгнутые юзером] [separator |] [main H+menu] [chevron ‹] [Apple zone]
///        скрываются           visible 1pt    visible       visible
///                             расширяется
///
/// Order creation влияет на default-position. По наблюдениям macOS:
/// «созданный позже = X меньше = левее в LTR layout».
/// Поэтому создаём:
///   1. chevron     — rightmost (close to Apple)
///   2. main        — middle
///   3. separator   — leftmost (visible line marker)
///
/// При collapse separator.length 1pt → ~screenWidth+200 → items LEFT of separator
/// (юзер ⌘+drag-нул их туда) пушатся за visible area. main + chevron остаются
/// (right of separator, anchored к Apple zone).
@MainActor
final class MenubarHiderController: ObservableObject {
    @Published private(set) var isCollapsed: Bool = false
    @Published private(set) var enabled: Bool = false

    private(set) var mainItem: NSStatusItem?
    private var separatorItem: NSStatusItem?
    private var chevronItem: NSStatusItem?

    private var lastAutoState: Bool? = nil
    private var peekTimer: Timer?

    private var isToggling = false
    private var screenObserver: NSObjectProtocol?

    /// Callback при появлении/смене mainItem (AppDelegate переустанавливает menu).
    var onMainItemReady: ((NSStatusItem) -> Void)?

    private static let collapsedSeparatorLength: CGFloat = 1
    private var expandedSeparatorLength: CGFloat = 2000   // динамически пересчитывается

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateExpandedLength() }
        }
        updateExpandedLength()
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Configuration

    /// Создаёт/пересоздаёт status items под новую конфигурацию.
    func configure(hiderEnabled: Bool, initialCollapsed: Bool, iconStyle: StatusIconStyle) {
        tearDownItems()
        updateExpandedLength()

        // Order: chevron → main → separator. Чтобы layout был [separator] [main] [chevron].
        if hiderEnabled {
            createChevron()
        }
        createMain(iconStyle: iconStyle)
        if hiderEnabled {
            createSeparator()
        }

        enabled = hiderEnabled
        isCollapsed = false  // стартуем expanded — гарантия что юзер увидит layout

        if hiderEnabled && initialCollapsed {
            // Re-collapse через 1с после init — даёт menubar layout устаканиться.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self, self.enabled else { return }
                self.collapseInternal()
            }
        }
    }

    func tearDown() {
        tearDownItems()
        enabled = false
        isCollapsed = false
        cancelPeek()
    }

    func updateMainIcon(style: StatusIconStyle) {
        mainItem?.button?.image = MenuBarIcon.makeWithSeparator(style: style)
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

    func collapseAll() { guard enabled else { return }; collapseInternal(); lastAutoState = nil }
    func expandAll()   { guard enabled else { return }; expandInternal();   lastAutoState = nil }

    func applyAuto(collapsed: Bool) {
        guard enabled else { return }
        if let last = lastAutoState, last == isCollapsed {
            // мы сами поставили — можно менять
        } else if lastAutoState != nil {
            lastAutoState = collapsed
            return
        }
        if isCollapsed != collapsed {
            if collapsed { collapseInternal() } else { expandInternal() }
        }
        lastAutoState = collapsed
    }

    // MARK: - Peek

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

    private func cancelPeek() {
        peekTimer?.invalidate()
        peekTimer = nil
    }

    // MARK: - Internal collapse/expand

    private func collapseInternal() {
        guard let separator = separatorItem else { return }
        guard isValidPosition else {
            // Юзер сломал layout cmd+drag'ом — игнорируем collapse.
            return
        }
        guard !isCollapsed else { return }
        separator.length = expandedSeparatorLength
        chevronItem?.button?.image = chevronImage(collapsed: true)
        isCollapsed = true
    }

    private func expandInternal() {
        guard let separator = separatorItem else { return }
        guard isCollapsed else { return }
        separator.length = Self.collapsedSeparatorLength
        chevronItem?.button?.image = chevronImage(collapsed: false)
        isCollapsed = false
    }

    /// Layout valid только если: chevron.x >= main.x >= separator.x (LTR).
    /// Иначе юзер cmd+drag-ом сломал порядок и collapse не сработает корректно.
    private var isValidPosition: Bool {
        guard
            let chevronX = chevronItem?.button?.window?.frame.origin.x,
            let mainX = mainItem?.button?.window?.frame.origin.x,
            let separatorX = separatorItem?.button?.window?.frame.origin.x
        else { return false }
        return chevronX >= mainX && mainX >= separatorX
    }

    // MARK: - Build items

    private func createChevron() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = chevronImage(collapsed: false)
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(chevronClicked)
        item.autosaveName = "helloWork_chevron"
        chevronItem = item
    }

    private func createMain(iconStyle: StatusIconStyle) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = MenuBarIcon.makeWithSeparator(style: iconStyle)
        item.button?.imagePosition = .imageOnly
        item.autosaveName = "helloWork_main"
        mainItem = item
        onMainItemReady?(item)
    }

    private func createSeparator() {
        let item = NSStatusBar.system.statusItem(withLength: Self.collapsedSeparatorLength)
        item.button?.image = MenuBarIcon.separatorLine()
        item.button?.imagePosition = .imageOnly
        item.autosaveName = "helloWork_separator"
        separatorItem = item
    }

    private func tearDownItems() {
        if let m = mainItem { NSStatusBar.system.removeStatusItem(m) }
        if let s = separatorItem { NSStatusBar.system.removeStatusItem(s) }
        if let c = chevronItem { NSStatusBar.system.removeStatusItem(c) }
        mainItem = nil
        separatorItem = nil
        chevronItem = nil
    }

    private func updateExpandedLength() {
        let screenWidth = NSScreen.main?.visibleFrame.width ?? 1728
        // Hidden Bar формула — bounded чтобы избежать pathological layout на новых macOS.
        expandedSeparatorLength = max(500, min(screenWidth + 200, 4000))

        // Применить если уже collapsed.
        if isCollapsed {
            separatorItem?.length = expandedSeparatorLength
        }
    }

    // MARK: - Chevron icon

    private func chevronImage(collapsed: Bool) -> NSImage? {
        // collapsed: `‹` — направление куда схлопнуто
        // expanded: `›` — указывает «click меня — items уйдут вправо за край»
        let symbol = collapsed ? "chevron.left" : "chevron.right"
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "Toggle hidden menubar items")
        img?.isTemplate = true
        return img
    }

    @objc private func chevronClicked() {
        toggle()
    }
}
