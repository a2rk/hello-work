import Foundation

enum AppVersion {
    static var marketing: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// Что показываем юзеру в About.
    static var displayString: String {
        "v\(marketing) · macOS"
    }

    /// Полная для логов / диагностики.
    static var fullString: String {
        "v\(marketing) (build \(build))"
    }

    /// Сравнение строк-версий вида "0.2.0" / "1.10.3" / "0.9.10-beta".
    /// Возвращает .orderedDescending если a > b. Pre-release suffix (после "-")
    /// делает версию МЕНЬШЕ release с тем же base (semver-style: 0.9.10-beta < 0.9.10).
    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let (aBase, aSuffix) = splitVersion(a)
        let (bBase, bSuffix) = splitVersion(b)
        for i in 0..<max(aBase.count, bBase.count) {
            let av = i < aBase.count ? aBase[i] : 0
            let bv = i < bBase.count ? bBase[i] : 0
            if av != bv { return av > bv ? .orderedDescending : .orderedAscending }
        }
        // Base equal — учитываем suffix. release (no suffix) > pre-release (any suffix).
        // Между двумя pre-release сравниваем лексикографически.
        switch (aSuffix, bSuffix) {
        case (nil, nil):     return .orderedSame
        case (nil, _?):      return .orderedDescending
        case (_?, nil):      return .orderedAscending
        case let (.some(x), .some(y)):
            if x == y { return .orderedSame }
            return x > y ? .orderedDescending : .orderedAscending
        }
    }

    /// Разделяет "0.9.10-beta.1" на ([0,9,10], "beta.1"). Без suffix → ([..], nil).
    private static func splitVersion(_ s: String) -> ([Int], String?) {
        let parts = s.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let baseStr = parts.first.map(String.init) ?? s
        let suffix = parts.count > 1 ? String(parts[1]) : nil
        let base = baseStr.split(separator: ".").compactMap { Int($0) }
        return (base, suffix)
    }
}
