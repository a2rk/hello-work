import AppKit

/// Полупрозрачное чёрное окно на весь экран. Клики проходят насквозь.
final class FocusOverlayWindow: NSWindow {
    init(screen: NSScreen, opacity: Double) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.hasShadow = false
        self.backgroundColor = NSColor.black.withAlphaComponent(CGFloat(opacity))
        self.ignoresMouseEvents = true
        self.isMovable = false
        self.isReleasedWhenClosed = false
        self.level = .normal              // мы будем переставлять order'ом, не уровнем
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.alphaValue = 0
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Сменить непрозрачность подложки.
    func setDimOpacity(_ opacity: Double) {
        self.backgroundColor = NSColor.black.withAlphaComponent(CGFloat(opacity))
    }
}
