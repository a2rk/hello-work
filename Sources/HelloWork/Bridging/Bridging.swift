// Bridging.swift — wrapper над приватными CGS API.
// Адаптация из Ice (https://github.com/jordanbaird/Ice) — GPLv3.

import Cocoa

enum Bridging { }

// MARK: - Window Frame

extension Bridging {
    /// Возвращает frame окна (в screen coords) через приватный CGSGetScreenRectForWindow.
    static func getWindowFrame(for windowID: CGWindowID) -> CGRect? {
        var rect = CGRect.zero
        let result = CGSGetScreenRectForWindow(CGSMainConnectionID(), windowID, &rect)
        guard result == .success else { return nil }
        return rect
    }

    /// Возвращает pid процесса-владельца окна через приватный CGSGetWindowOwner.
    /// Надёжнее, чем CGWindowListCopyWindowInfo для menubar items (layer 25),
    /// которые публичный API часто пропускает.
    static func getWindowOwnerPID(for windowID: CGWindowID) -> pid_t? {
        var ownerCID: CGSConnectionID = 0
        let r1 = CGSGetWindowOwner(CGSMainConnectionID(), windowID, &ownerCID)
        guard r1 == .success else { return nil }
        var pid: pid_t = 0
        let r2 = CGSConnectionGetPID(ownerCID, &pid)
        guard r2 == .success, pid > 0 else { return nil }
        return pid
    }
}

// MARK: - Window Alpha

extension Bridging {
    /// Устанавливает alpha окна. Используется для hide-by-alpha menubar items
    /// (без CGEvent drag). 0.0 = полностью невидимо.
    @discardableResult
    static func setWindowAlpha(_ wid: CGWindowID, alpha: CGFloat) -> Bool {
        let result = CGSSetWindowAlpha(CGSMainConnectionID(), wid, alpha)
        return result == .success
    }

    /// Текущий alpha окна.
    static func getWindowAlpha(_ wid: CGWindowID) -> CGFloat? {
        var alpha: CGFloat = 0
        let r = CGSGetWindowAlpha(CGSMainConnectionID(), wid, &alpha)
        return r == .success ? alpha : nil
    }
}

// MARK: - Window List

extension Bridging {
    struct WindowListOption: OptionSet {
        let rawValue: Int
        static let onScreen = WindowListOption(rawValue: 1 << 0)
        static let menuBarItems = WindowListOption(rawValue: 1 << 1)
    }

    /// Список window IDs по фильтру.
    static func getWindowList(option: WindowListOption = []) -> [CGWindowID] {
        if option.contains(.menuBarItems) {
            if option.contains(.onScreen) {
                let onScreen = Set(getOnScreenWindowList())
                return getMenuBarWindowList().filter(onScreen.contains)
            }
            return getMenuBarWindowList()
        }
        if option.contains(.onScreen) {
            return getOnScreenWindowList()
        }
        return getAllWindowList()
    }

    // MARK: - Internals

    private static func getWindowCount() -> Int {
        var count: Int32 = 0
        _ = CGSGetWindowCount(CGSMainConnectionID(), 0, &count)
        return Int(count)
    }

    private static func getOnScreenWindowCount() -> Int {
        var count: Int32 = 0
        _ = CGSGetOnScreenWindowCount(CGSMainConnectionID(), 0, &count)
        return Int(count)
    }

    private static func getAllWindowList() -> [CGWindowID] {
        let count = getWindowCount()
        var list = [CGWindowID](repeating: 0, count: count)
        var realCount: Int32 = 0
        let result = CGSGetWindowList(CGSMainConnectionID(), 0, Int32(count), &list, &realCount)
        guard result == .success else { return [] }
        return [CGWindowID](list[..<Int(realCount)])
    }

    private static func getOnScreenWindowList() -> [CGWindowID] {
        let count = getOnScreenWindowCount()
        var list = [CGWindowID](repeating: 0, count: count)
        var realCount: Int32 = 0
        let result = CGSGetOnScreenWindowList(CGSMainConnectionID(), 0, Int32(count), &list, &realCount)
        guard result == .success else { return [] }
        return [CGWindowID](list[..<Int(realCount)])
    }

    private static func getMenuBarWindowList() -> [CGWindowID] {
        // Точного count нет — берём общий и режем по realCount.
        let buffer = max(getWindowCount(), 256)
        var list = [CGWindowID](repeating: 0, count: buffer)
        var realCount: Int32 = 0
        let result = CGSGetProcessMenuBarWindowList(CGSMainConnectionID(), 0, Int32(buffer), &list, &realCount)
        guard result == .success else { return [] }
        return [CGWindowID](list[..<Int(realCount)])
    }
}
