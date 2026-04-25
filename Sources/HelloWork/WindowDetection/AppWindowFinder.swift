import AppKit

enum AppWindowFinder {
    static func find(bundleID: String) -> (NSRect, Int)? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        var bestRect: NSRect?
        var bestWindowNumber: Int?
        var bestArea: CGFloat = 0

        for w in info {
            guard
                let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                let bounds = w[kCGWindowBounds as String] as? [String: CGFloat],
                let x = bounds["X"], let y = bounds["Y"],
                let width = bounds["Width"], let height = bounds["Height"],
                let winNum = w[kCGWindowNumber as String] as? Int,
                let pidNum = w[kCGWindowOwnerPID as String] as? Int,
                width > 100, height > 100
            else { continue }

            let pid = pid_t(pidNum)
            guard NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == bundleID
            else { continue }

            let area = width * height
            if area > bestArea {
                bestArea = area
                bestRect = cgFrameToScreenFrame(NSRect(x: x, y: y, width: width, height: height))
                bestWindowNumber = winNum
            }
        }
        if let r = bestRect, let n = bestWindowNumber {
            return (r, n)
        }
        return nil
    }

    private static func cgFrameToScreenFrame(_ cg: NSRect) -> NSRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(
            x: cg.origin.x,
            y: primaryHeight - cg.origin.y - cg.size.height,
            width: cg.size.width,
            height: cg.size.height
        )
    }
}
