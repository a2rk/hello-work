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

    /// Сравнение строк-версий вида "0.2.0" / "1.10.3". Возвращает .orderedDescending если a > b.
    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(aParts.count, bParts.count) {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av != bv { return av > bv ? .orderedDescending : .orderedAscending }
        }
        return .orderedSame
    }
}
