import AppKit
import ApplicationServices

/// Находит активное окно frontmost-приложения для focus mode.
/// Приоритет: AX (точно), fallback: CGWindowList (без permissions).
enum FrontmostWindowFinder {
    struct Target {
        let bundleID: String
        let pid: pid_t
        let frame: NSRect          // в screen coordinates (origin bottom-left)
        let windowNumber: Int      // CGWindowID для z-order операций
        let screen: NSScreen?
        let isFullScreen: Bool
    }

    /// Находит frontmost-окно. Если useAccessibility=true и доступ есть — точное определение.
    static func find(useAccessibility: Bool = false) -> Target? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        guard let bundleID = app.bundleIdentifier else { return nil }
        let pid = app.processIdentifier

        // 1. AX путь — точный focused window внутри app.
        if useAccessibility, AXIsProcessTrusted() {
            if let target = findViaAX(pid: pid, bundleID: bundleID) {
                return target
            }
        }

        // 2. CG путь — топ окно с layer=0 от этого pid.
        return findViaCG(pid: pid, bundleID: bundleID)
    }

    // MARK: - CGWindowList

    private static func findViaCG(pid: pid_t, bundleID: String) -> Target? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // CGWindowList отдаёт окна сверху вниз z-order. Берём первое, принадлежащее pid с layer=0.
        for w in info {
            guard
                let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                let bounds = w[kCGWindowBounds as String] as? [String: CGFloat],
                let x = bounds["X"], let y = bounds["Y"],
                let width = bounds["Width"], let height = bounds["Height"],
                let winNum = w[kCGWindowNumber as String] as? Int,
                let pidNum = w[kCGWindowOwnerPID as String] as? Int,
                pid_t(pidNum) == pid,
                width > 50, height > 50
            else { continue }

            let cgRect = CGRect(x: x, y: y, width: width, height: height)
            let frame = cgFrameToScreenFrame(cgRect)
            let screen = bestScreen(for: frame)
            let isFull = isFullScreen(frame: frame, screen: screen)
            return Target(
                bundleID: bundleID,
                pid: pid,
                frame: frame,
                windowNumber: winNum,
                screen: screen,
                isFullScreen: isFull
            )
        }
        return nil
    }

    // MARK: - AX

    private static func findViaAX(pid: pid_t, bundleID: String) -> Target? {
        let appElement = AXUIElementCreateApplication(pid)

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focused) == .success,
              let window = focused
        else { return nil }
        let axWindow = window as! AXUIElement

        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeValue) == .success
        else { return nil }

        var pos = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

        let cgRect = CGRect(origin: pos, size: size)
        let frame = cgFrameToScreenFrame(cgRect)
        let screen = bestScreen(for: frame)

        // Получаем CGWindowID через приватный API _AXUIElementGetWindow.
        // Без него мы не можем сделать NSWindow.order(.below, relativeTo: ...).
        // Fallback: ищем подходящее CG-окно по совпадению bounds.
        let winNum = matchCGWindowNumber(pid: pid, frame: cgRect)

        let isFull = isFullScreen(frame: frame, screen: screen)

        return Target(
            bundleID: bundleID,
            pid: pid,
            frame: frame,
            windowNumber: winNum ?? 0,
            screen: screen,
            isFullScreen: isFull
        )
    }

    /// Находит CGWindowID для AX-окна через сравнение bounds.
    private static func matchCGWindowNumber(pid: pid_t, frame: CGRect) -> Int? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        for w in info {
            guard
                let pidNum = w[kCGWindowOwnerPID as String] as? Int,
                pid_t(pidNum) == pid,
                let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                let bounds = w[kCGWindowBounds as String] as? [String: CGFloat],
                let x = bounds["X"], let y = bounds["Y"],
                let width = bounds["Width"], let height = bounds["Height"],
                let winNum = w[kCGWindowNumber as String] as? Int
            else { continue }
            // Допуск ±2px
            if abs(x - frame.origin.x) < 2,
               abs(y - frame.origin.y) < 2,
               abs(width - frame.size.width) < 2,
               abs(height - frame.size.height) < 2 {
                return winNum
            }
        }
        return nil
    }

    // MARK: - Helpers

    /// CG-координаты (origin top-left главного экрана) → AppKit screen-координаты (origin bottom-left).
    private static func cgFrameToScreenFrame(_ cg: CGRect) -> NSRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(
            x: cg.origin.x,
            y: primaryHeight - cg.origin.y - cg.size.height,
            width: cg.size.width,
            height: cg.size.height
        )
    }

    private static func bestScreen(for frame: NSRect) -> NSScreen? {
        var best: NSScreen?
        var bestArea: CGFloat = 0
        for screen in NSScreen.screens {
            let inter = screen.frame.intersection(frame)
            if inter.isNull { continue }
            let area = inter.width * inter.height
            if area > bestArea {
                bestArea = area
                best = screen
            }
        }
        return best ?? NSScreen.main
    }

    /// Эвристика fullscreen: окно занимает практически весь screen без menubar gap.
    private static func isFullScreen(frame: NSRect, screen: NSScreen?) -> Bool {
        guard let s = screen else { return false }
        // Frame экрана в screen-coords (включает menubar). visibleFrame — без menubar/dock.
        let full = s.frame
        let dx = abs(frame.origin.x - full.origin.x)
        let dy = abs(frame.origin.y - full.origin.y)
        let dw = abs(frame.width - full.width)
        let dh = abs(frame.height - full.height)
        return dx < 2 && dy < 2 && dw < 2 && dh < 2
    }
}
