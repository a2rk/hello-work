import SwiftUI

enum Theme {
    static let accent = Color(red: 0.62, green: 1.0, blue: 0.58)
    static let accentMid = Color(red: 0.40, green: 0.95, blue: 0.45)
    static let accentDeep = Color(red: 0.10, green: 0.65, blue: 0.20)
    static let danger = Color(red: 1.0, green: 0.40, blue: 0.40)
    static let dangerDim = Color(red: 1.0, green: 0.38, blue: 0.38).opacity(0.30)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.40)
    static let surface = Color.white.opacity(0.045)
    static let surfaceStroke = Color.white.opacity(0.08)
    static let glow = Color(red: 0.55, green: 1.0, blue: 0.50).opacity(0.16)
}
