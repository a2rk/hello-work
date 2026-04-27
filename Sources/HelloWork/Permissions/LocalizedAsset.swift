import SwiftUI
import AppKit

/// Загружает локализованный image asset из Bundle.module по текущему языку.
/// При отсутствии файлов — рисует SwiftUI-плейсхолдер с пунктирной рамкой и текстом.
struct LocalizedAsset: View {
    let baseName: String       // например "onboarding_permissions"
    let language: AppLanguage
    let aspectRatio: CGFloat   // ширина / высота
    let placeholderText: String

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                placeholder
            }
        }
    }

    private func loadImage() -> NSImage? {
        let langCode = resolvedLanguageCode(language)
        if let img = NSImage(named: "\(baseName)_\(langCode)") { return img }
        // Fallback на en если запрашиваемый язык отсутствует.
        if langCode != "en", let img = NSImage(named: "\(baseName)_en") { return img }
        return nil
    }

    private func resolvedLanguageCode(_ language: AppLanguage) -> String {
        switch language {
        case .ru: return "ru"
        case .zh: return "zh"
        case .en: return "en"
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("ru") { return "ru" }
            if preferred.hasPrefix("zh") { return "zh" }
            return "en"
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    Theme.surfaceStroke,
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.02))
                )

            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(Theme.textTertiary)
                Text(placeholderText)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }
}
