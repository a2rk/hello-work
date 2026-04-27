import AppKit

/// NSStatusItem с переменной шириной. min = маленький chevron, max = широкий пробел,
/// который выталкивает все правые иконки за край экрана.
@MainActor
final class HiderStatusItem {
    private(set) var item: NSStatusItem
    private(set) var isCollapsed: Bool = true

    /// Ширина в "развёрнутом" состоянии — 10000pt достаточно даже для 5K-моников.
    private static let expandedWidth: CGFloat = 10000
    private static let collapsedWidth: CGFloat = 24

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
        let symbol = isCollapsed ? "chevron.left.2" : "chevron.right.2"
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "Toggle menubar items") {
            img.isTemplate = true
            button.image = img
        }
    }

    private func applyWidth(animated: Bool) {
        let target: CGFloat = isCollapsed ? Self.collapsedWidth : Self.expandedWidth
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
