import AppKit

enum AppWindowFinder {
    /// Bulk-вариант — один проход по CGWindowList на N приложений вместо N
    /// отдельных вызовов CGWindowListCopyWindowInfo. Используется в refresh()
    /// чтобы при 4Hz-tick'е не делать N полных enumeration'ов.
    static func findMultiple(bundleIDs: Set<String>) -> [String: (NSRect, Int)] {
        guard !bundleIDs.isEmpty else { return [:] }
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return [:]
        }

        // Cache pid → bundleID — одинаковые pid'ы встречаются у нескольких окон.
        var pidToBundle: [pid_t: String?] = [:]
        func bundle(for pid: pid_t) -> String? {
            if let cached = pidToBundle[pid] { return cached }
            let bid = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
            pidToBundle[pid] = bid
            return bid
        }

        var bestPerBundle: [String: (NSRect, Int, CGFloat)] = [:]

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
            guard let bid = bundle(for: pid), bundleIDs.contains(bid) else { continue }

            let area = width * height
            if let existing = bestPerBundle[bid], area <= existing.2 { continue }
            let frame = cgFrameToScreenFrame(NSRect(x: x, y: y, width: width, height: height))
            bestPerBundle[bid] = (frame, winNum, area)
        }

        var result: [String: (NSRect, Int)] = [:]
        for (bid, (frame, winNum, _)) in bestPerBundle {
            result[bid] = (frame, winNum)
        }
        return result
    }

    /// Convenience-обёртка для одного приложения.
    static func find(bundleID: String) -> (NSRect, Int)? {
        findMultiple(bundleIDs: [bundleID])[bundleID]
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
