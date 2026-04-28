import SwiftUI
import Combine

/// Карусель цитат в detail view: 3-5 цитат с auto-rotate (5с) + стрелки + dots.
/// Если quotes пуст — секция скрывается. Hover на цитате паузит auto-rotate.
struct LegendQuotesCarousel: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    let legend: Legend

    @State private var currentIndex: Int = 0
    @State private var hovered: Bool = false
    /// До этого времени auto-rotate не срабатывает — даёт юзеру время прочитать
    /// цитату, на которую он перешёл вручную через стрелки или dots.
    @State private var pauseUntil: Date = .distantPast

    /// Каждый тик публикуется только когда .autoconnect; .onReceive хэндлит инкремент.
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        if !legend.quotes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                header
                quoteCard
                if legend.quotes.count > 1 {
                    controls
                }
            }
            .onReceive(timer) { now in
                guard !hovered, legend.quotes.count > 1, now >= pauseUntil else { return }
                advance(by: 1, manual: false)
            }
            .onAppear {
                clampIndex()
            }
        }
    }

    private var header: some View {
        Text(t.legendsDetailQuotes)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundColor(Theme.textTertiary)
    }

    private var quoteCard: some View {
        let quote = legend.quotes[safe: currentIndex] ?? legend.quotes[0]
        return HStack(alignment: .top, spacing: 12) {
            Text("“")
                .font(.system(size: 36, weight: .bold, design: .serif))
                .foregroundColor(Theme.accent.opacity(0.6))
                .padding(.top, -6)
            VStack(alignment: .leading, spacing: 4) {
                Text(localized(quote))
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundColor(.white)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
                    .id(currentIndex)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                Text("— \(legendShortName)")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.surfaceStroke, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: currentIndex)
        .onHover { hovered = $0 }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            arrowButton(system: "chevron.left") { advance(by: -1, manual: true) }
            HStack(spacing: 6) {
                ForEach(0..<legend.quotes.count, id: \.self) { idx in
                    Button {
                        withAnimation { currentIndex = idx }
                        pauseUntil = Date().addingTimeInterval(5)
                    } label: {
                        Circle()
                            .fill(idx == currentIndex ? Theme.accent : Color.white.opacity(0.20))
                            .frame(width: 6, height: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            arrowButton(system: "chevron.right") { advance(by: 1, manual: true) }
            Spacer()
            Text("\(currentIndex + 1) / \(legend.quotes.count)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.textTertiary)
        }
    }

    private func arrowButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(0.04)))
                .overlay(Circle().stroke(Theme.surfaceStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func advance(by step: Int, manual: Bool) {
        let n = legend.quotes.count
        guard n > 0 else { return }
        let next = ((currentIndex + step) % n + n) % n
        withAnimation { currentIndex = next }
        if manual {
            // Юзер кликнул — даём 5с прочитать без перебивки auto-rotate'ом.
            pauseUntil = Date().addingTimeInterval(5)
        }
    }

    private func clampIndex() {
        if currentIndex < 0 || currentIndex >= legend.quotes.count {
            currentIndex = 0
        }
    }

    private func localized(_ q: LegendQuote) -> String {
        // LegendQuote — самостоятельная struct (ru/en поля), не LocalizedRuEn,
        // поэтому inline mapping. Empty-fallback на противоположный язык.
        let ruEn = LocalizedRuEn(ru: q.ru, en: q.en)
        let resolved = LegendLocalized.text(ruEn, in: state.language)
        return resolved.isEmpty
            ? (state.language == .ru ? q.en : q.ru)
            : resolved
    }

    private var legendShortName: String {
        LegendLocalized.text(legend.name, in: state.language)
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}
