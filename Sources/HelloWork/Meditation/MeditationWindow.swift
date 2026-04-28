import AppKit

/// Fullscreen overlay-window для meditation. Один на screen.
/// level = statusBar+1 чтобы перекрывать menubar; collectionBehavior
/// — присутствует на всех Spaces, не ломает fullscreen apps.
/// canBecomeKey=true чтобы получать ESC keypress.
final class MeditationWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.setFrame(screen.frame, display: false)

        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isReleasedWhenClosed = false
        self.alphaValue = 0  // start invisible, fade-in отдельно
    }

    /// Window НЕ titled, но key-status нам нужен для ESC keypress.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Перехват ESC: KeyDown event с keyCode 53 → callback.
    var onEscapePressed: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // ESC
            onEscapePressed?()
            return
        }
        super.keyDown(with: event)
    }
}
