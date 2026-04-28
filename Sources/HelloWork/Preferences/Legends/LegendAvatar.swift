import SwiftUI

/// Круглый аватар легенды: 1-2 буквы из name + цвет фона derived from id-hash.
/// avatarUrl в JSON сейчас всегда nil → монограмма единственный путь.
struct LegendAvatar: View {
    let legend: Legend
    let size: CGFloat
    /// Локаль определяет какой алфавит использовать для монограммы.
    let language: AppLanguage

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
            Text(monogram)
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }

    private var monogram: String {
        let pickedName = pickName()
        let parts = pickedName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }.joined()
        return letters.isEmpty ? String(legend.id.prefix(1)).uppercased() : letters.uppercased()
    }

    /// Берём имя в локали интерфейса. zh-локаль использует en (chinese chars
    /// в монограмме плохо смотрятся, и в JSON для большинства легенд chinese
    /// нет — фолбэк через TASK-L65).
    private func pickName() -> String {
        switch language {
        case .ru:           return legend.name.ru
        case .en, .zh:      return legend.name.en
        case .system:       return legend.name.en
        }
    }

    /// Стабильный цвет per-id: hash → один из 12 спокойных оттенков.
    private var backgroundColor: Color {
        let hash = legend.id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let palette: [Color] = [
            Color(red: 0.35, green: 0.42, blue: 0.55),
            Color(red: 0.50, green: 0.40, blue: 0.55),
            Color(red: 0.55, green: 0.45, blue: 0.40),
            Color(red: 0.40, green: 0.55, blue: 0.45),
            Color(red: 0.45, green: 0.50, blue: 0.55),
            Color(red: 0.55, green: 0.50, blue: 0.40),
            Color(red: 0.50, green: 0.55, blue: 0.45),
            Color(red: 0.40, green: 0.45, blue: 0.55),
            Color(red: 0.55, green: 0.45, blue: 0.50),
            Color(red: 0.45, green: 0.55, blue: 0.50),
            Color(red: 0.50, green: 0.55, blue: 0.40),
            Color(red: 0.42, green: 0.42, blue: 0.50),
        ]
        return palette[abs(hash) % palette.count]
    }
}
