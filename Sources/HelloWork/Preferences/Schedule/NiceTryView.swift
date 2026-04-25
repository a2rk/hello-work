import SwiftUI

/// Что юзер видит, если попытается заблокировать самого Hello work.
struct NiceTryView: View {
    @Environment(\.t) var t

    private let phrases: [(lang: String, text: String)] = [
        ("RU", "ну ты даёшь"),
        ("DE", "schöner Versuch"),
        ("FR", "bien essayé"),
        ("ES", "buen intento"),
        ("ZH", "想得美"),
        ("JA", "むり"),
        ("IT", "bel tentativo"),
        ("PT", "boa tentativa"),
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("nice try")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.accent)
                .shadow(color: Theme.accent.opacity(0.45), radius: 24)

            VStack(spacing: 8) {
                ForEach(Array(phrases.enumerated()), id: \.offset) { idx, item in
                    HStack(spacing: 14) {
                        Text(item.lang)
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.4)
                            .foregroundColor(Theme.textTertiary)
                            .frame(width: 28, alignment: .trailing)
                        Text(item.text)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.78 - Double(idx) * 0.06))
                    }
                }
            }

            Spacer()

            Text(t.niceTryFooter)
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
