import AppKit

/// NSStatusItem с переменной шириной. min = маленький chevron, max = широкий пробел,
/// который выталкивает все правые иконки за край экрана.
@MainActor
final class HiderStatusItem {
    private(set) var item: NSStatusItem
    private(set) var isCollapsed: Bool = true

    /// Стиль chevron-иконки.
    var chevronStyle: HiderChevronStyle = .chevron {
        didSet { updateImage() }
    }

    /// Показывать ли иконку. Если false — рисуем прозрачный pixel, чтобы клик-зона осталась.
    var showChevron: Bool = true {
        didSet { updateImage() }
    }

    /// Ширина в "развёрнутом" состоянии — 10000pt достаточно даже для 5K-моников.
    private static let expandedWidth: CGFloat = 10000
    private static let collapsedWidth: CGFloat = 24
    private static let invisibleWidth: CGFloat = 8

    var onClick: (() -> Void)?

    init() {
        self.item = NSStatusBar.system.statusItem(withLength: Self.collapsedWidth)
        self.item.behavior = []
        self.item.isVisible = true
        configureButton()
    }

    /// Снять status item из menubar. Вызвать перед уничтожением.
    func tearDown() {
        NSStatusBar.system.removeStatusItem(item)
    }

    // MARK: - State

    func setCollapsed(_ collapsed: Bool, animated: Bool = true) {
        guard collapsed != isCollapsed else { return }
        isCollapsed = collapsed
        applyWidth(animated: animated)
        updateImage()
    }

    func toggle() {
        setCollapsed(!isCollapsed)
    }

    // MARK: - Internal

    private func configureButton() {
        guard let button = item.button else { return }
        updateImage()
        button.target = self
        button.action = #selector(buttonClicked(_:))
        button.imagePosition = .imageOnly
    }

    @objc private func buttonClicked(_ sender: Any?) {
        onClick?()
    }

    private func updateImage() {
        guard let button = item.button else { return }
        if !showChevron {
            // Рисуем 1×1 прозрачный — клик-зона остаётся, но визуально пусто.
            let img = NSImage(size: NSSize(width: 1, height: 1))
            button.image = img
            return
        }
        let symbol = isCollapsed ? chevronStyle.collapsedSymbol : chevronStyle.expandedSymbol
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "Toggle menubar items") {
            img.isTemplate = true
            button.image = img
        }
    }

    private func applyWidth(animated: Bool) {
        let collapsedTarget: CGFloat = showChevron ? Self.collapsedWidth : Self.invisibleWidth
        let target: CGFloat = isCollapsed ? collapsedTarget : Self.expandedWidth
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                item.length = target
            }
        } else {
            item.length = target
        }
    }
}
