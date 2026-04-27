import AppKit
import Combine

/// Hidden Bar approach: три status item'а.
/// 1. `mainItem` ("H │")  — visible, носит наше menu и иконку.
/// 2. `separatorItem`     — invisible, length меняется (24pt ↔ 10000pt). Это «двигатель».
/// 3. `chevronItem` (">") — visible, toggle button.
///
/// Юзер cmd+drag'ом расставляет свои menubar items **между** mainItem и chevronItem.
/// При collapse — separator расширяется и пихает их за visible area.
@MainActor
final class MenubarHiderController: ObservableObject {
    @Published private(set) var isCollapsed: Bool = true
    @Published private(set) var enabled: Bool = false

    private(set) var mainItem: NSStatusItem?
    private var separatorItem: NSStatusItem?
    private var chevronItem: NSStatusItem?

    private var lastAutoState: Bool? = nil
    private var peekTimer: Timer?

    /// Callback при появлении/смене mainItem (AppDelegate переустанавливает menu).
    var onMainItemReady: ((NSStatusItem) -> Void)?

    private static let collapsedLength: CGFloat = 24
    private static let expandedLength: CGFloat = 10000

    init() {}

    // MARK: - Public

    /// Создаёт/пересоздаёт status items под новую конфигурацию.
    /// `hiderEnabled = true`  → 3 items (main + separator + chevron)
    /// `hiderEnabled = false` → 1 item (только main)
    func configure(hiderEnabled: Bool, initialCollapsed: Bool, iconStyle: StatusIconStyle) {
        tearDownItems()

        // ВАЖНО: порядок создания влияет на позицию в menubar.
        // В macOS: позже созданный = ЛЕВЕЕ.
        // Нам нужен такой layout (справа налево от Apple-зоны):
        //   [chevron] [separator] [main]  [Apple zone]
        //                                  ↑ rightmost, всегда видим
        // При collapse separator расширяется → items LEFT of separator (chevron + что юзер
        // ⌘+drag-нул в зону между main и chevron) уходят за край экрана. main остаётся.
        //
        // Поэтому создаём main ПЕРВЫМ (rightmost), separator вторым, chevron последним (leftmost).

        createMain(iconStyle: iconStyle)
        if hiderEnabled {
            createSeparator()
            createChevron()
        }

        enabled = hiderEnabled
        if hiderEnabled {
            isCollapsed = initialCollapsed
        } else {
            isCollapsed = false
        }
        applyState()
    }

    func tearDown() {
        tearDownItems()
        enabled = false
        isCollapsed = false
        cancelPeek()
    }

    func collapseAll() {
        guard enabled else { return }
        isCollapsed = true
        applyState()
        lastAutoState = nil
    }

    func expandAll() {
        guard enabled else { return }
        isCollapsed = false
        applyState()
        lastAutoState = nil
    }

    func toggle() {
        guard enabled else { return }
        isCollapsed.toggle()
        applyState()
        lastAutoState = nil
    }

    func applyAuto(collapsed: Bool) {
        guard enabled else { return }
        if let last = lastAutoState, last == isCollapsed {
            // мы сами поставили — можно менять
        } else if lastAutoState != nil {
            // юзер вмешался — не дёргаем
            lastAutoState = collapsed
            return
        }
        if isCollapsed != collapsed {
            isCollapsed = collapsed
            applyState()
        }
        lastAutoState = collapsed
    }

    /// Меняет иконку main без recreate всех items.
    func updateMainIcon(style: StatusIconStyle) {
        guard let main = mainItem else { return }
        main.button?.image = MenuBarIcon.makeWithSeparator(style: style)
    }

    // MARK: - Peek

    func peek(seconds: Int) {
        guard enabled, seconds > 0, isCollapsed else { return }
        isCollapsed = false
        applyState()

        peekTimer?.invalidate()
        let t = Timer(timeInterval: TimeInterval(seconds), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isCollapsed = true
                self?.applyState()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        peekTimer = t
    }

    private func cancelPeek() {
        peekTimer?.invalidate()
        peekTimer = nil
    }

    // MARK: - Build items

    private func createMain(iconStyle: StatusIconStyle) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = MenuBarIcon.makeWithSeparator(style: iconStyle)
        item.button?.imagePosition = .imageOnly
        // Клик откроет menu, если оно будет установлено через item.menu (это делает AppDelegate).
        mainItem = item
        onMainItemReady?(item)
    }

    private func createSeparator() {
        let item = NSStatusBar.system.statusItem(withLength: Self.collapsedLength)
        // Невидимый — нет ни image ни title.
        item.button?.image = nil
        item.button?.title = ""
        item.button?.imagePosition = .imageOnly
        // Disable click — separator никак не реагирует.
        item.button?.target = nil
        item.button?.action = nil
        separatorItem = item
    }

    private func createChevron() {
        let item = NSStatusBar.system.statusItem(withLength: 24)
        item.button?.image = chevronImage(collapsed: true)
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(chevronClicked)
        chevronItem = item
    }

    private func tearDownItems() {
        if let m = mainItem { NSStatusBar.system.removeStatusItem(m) }
        if let s = separatorItem { NSStatusBar.system.removeStatusItem(s) }
        if let c = chevronItem { NSStatusBar.system.removeStatusItem(c) }
        mainItem = nil
        separatorItem = nil
        chevronItem = nil
    }

    // MARK: - Apply state

    private func applyState() {
        guard enabled else { return }
        let length: CGFloat = isCollapsed ? Self.expandedLength : Self.collapsedLength
        separatorItem?.length = length
        chevronItem?.button?.image = chevronImage(collapsed: isCollapsed)
    }

    // MARK: - Chevron icon

    private func chevronImage(collapsed: Bool) -> NSImage? {
        // collapsed (всё спрятано): `‹` — кнопка слева от main, как «свёрнуто»
        // expanded (всё видно): `›` — указывает направление куда схлопнется при click
        let symbol = collapsed ? "chevron.left" : "chevron.right"
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "Toggle hidden menubar items")
        img?.isTemplate = true
        return img
    }

    // MARK: - Click handlers

    @objc private func chevronClicked() {
        toggle()
    }
}
