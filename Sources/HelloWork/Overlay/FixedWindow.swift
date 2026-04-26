import AppKit

final class FixedWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// bundleID жертвы — нужен collector'у, чтобы знать чей это event.
    var bundleID: String?
    weak var collector: StatsCollector?

    override func sendEvent(_ event: NSEvent) {
        recordIfNeeded(event)
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
             .otherMouseDown, .otherMouseUp,
             .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
             .scrollWheel, .keyDown, .keyUp, .flagsChanged:
            return
        default:
            super.sendEvent(event)
        }
    }

    private func recordIfNeeded(_ event: NSEvent) {
        guard let bid = bundleID, let c = collector else { return }
        let stat: StatEvent?
        switch event.type {
        case .leftMouseDown:
            stat = .tap
        case .rightMouseDown, .otherMouseDown:
            stat = .secondaryTap
        case .scrollWheel:
            // Дебаунс — серия wheel-events за один свайп = 1 запись.
            stat = c.shouldRecordScroll(bundleID: bid) ? .scrollSwipe : nil
        case .keyDown:
            // Авто-repeat (зажатая клавиша) считаем как одно нажатие.
            stat = event.isARepeat ? nil : .keystroke
        default:
            stat = nil
        }
        guard let e = stat else { return }
        // collector — @MainActor; sendEvent вызывается на main thread.
        MainActor.assumeIsolated { c.record(event: e, bundleID: bid) }
    }
}
