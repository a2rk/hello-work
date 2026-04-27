import SwiftUI

/// Детерминированная палитра «нейтральных пастельных» цветов.
/// hash(bundleID) → 1 из 12 цветов. Apple-style: средняя насыщенность, высокая светлота —
/// читаемо на тёмном фоне без агрессивного контраста.
enum AppPalette {
    /// 12 пастельных оттенков. Названия для отладки/документации.
    private static let palette: [Color] = [
        Color(red: 0.62, green: 0.86, blue: 0.79),    // Mint
        Color(red: 0.78, green: 0.78, blue: 0.95),    // Lavender
        Color(red: 0.97, green: 0.79, blue: 0.66),    // Peach
        Color(red: 0.65, green: 0.84, blue: 0.94),    // Sky
        Color(red: 0.74, green: 0.86, blue: 0.70),    // Sage
        Color(red: 0.96, green: 0.71, blue: 0.69),    // Coral
        Color(red: 0.96, green: 0.91, blue: 0.66),    // Butter
        Color(red: 0.86, green: 0.74, blue: 0.92),    // Lilac
        Color(red: 0.84, green: 0.74, blue: 0.65),    // Clay
        Color(red: 0.96, green: 0.72, blue: 0.84),    // Rose
        Color(red: 0.84, green: 0.81, blue: 0.62),    // Khaki
        Color(red: 0.55, green: 0.81, blue: 0.83)     // Teal
    ]

    /// Стабильный hash для строки — FNV-1a 32 bit.
    private static func stableHash(_ s: String) -> UInt32 {
        var h: UInt32 = 2166136261
        for byte in s.utf8 {
            h ^= UInt32(byte)
            h &*= 16777619
        }
        return h
    }

    static func color(for bundleID: String) -> Color {
        let h = stableHash(bundleID)
        let idx = Int(h % UInt32(palette.count))
        return palette[idx]
    }

    /// Чуть более насыщенная версия — для бордеров и hover.
    static func borderColor(for bundleID: String) -> Color {
        color(for: bundleID).opacity(0.85)
    }
}
