import SwiftUI
import AppKit

/// Detail view легенды: hero + bio + sources + ring chart + quotes + messenger windows.
/// TASK-L37 заложил hero + back-button + fav-star.
/// TASK-L39 добавил bio + sources.
/// L41/L43/L45/L47 наполняют остальные секции.
struct LegendDetailView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    let legend: Legend
    let onBack: () -> Void

    @State private var showApplySheet: Bool = false

    var body: some View {
        // Parent PrefsView.detail уже оборачивает в ScrollView. Не вкладываем второй
        // — иначе nested-scroll даёт неконсистентный bounce и мешает hit-testing.
        VStack(alignment: .leading, spacing: 18) {
            backButton
            hero
            ringSection
            bioSection
            LegendQuotesCarousel(state: state, legend: legend)
            LegendMessengerWindows(state: state, legend: legend)
            sourcesSection
        }
    }

    private var ringSection: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                LegendRingChart(legend: legend)
                Spacer()
            }
            LegendBlockTypeLegend(legend: legend)
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                Text(t.sectionLegends)
                    .font(.system(size: 12))
            }
            .foregroundColor(Theme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 18) {
            LegendAvatar(legend: legend, size: 96, language: state.language)

            VStack(alignment: .leading, spacing: 6) {
                Text(localizedName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text(localizedFullName)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                metaRow
                intensityDots
            }

            Spacer(minLength: 8)
            applyButton
            favoriteStar
        }
        .padding(.bottom, 4)
        .sheet(isPresented: $showApplySheet) {
            LegendApplySheet(state: state, legend: legend) {
                // TASK-L59 заменит на реальный apply call.
            }
        }
    }

    private var applyButton: some View {
        let hasApps = !activeManagedApps.isEmpty
        return Button {
            showApplySheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11, weight: .semibold))
                Text(t.legendsApply)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(hasApps ? .black : Theme.textTertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(hasApps ? Theme.accent : Color.white.opacity(0.04))
            )
            .overlay(
                Capsule().stroke(hasApps ? Theme.accent.opacity(0.4) : Theme.surfaceStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!hasApps)
        .help(hasApps ? t.legendsApply : t.legendsApplyNoAppsHint)
    }

    /// Активные managed-apps (не archived) — нужны как минимум для одного
    /// assignment. Если пусто — apply-кнопка disabled.
    private var activeManagedApps: [ManagedApp] {
        state.managedApps.filter { !$0.isArchived }
    }

    private var metaRow: some View {
        HStack(spacing: 10) {
            metaItem(legend.yearsOfLife)
            metaDivider
            metaItem(nationalityFlag(legend.nationality))
            metaDivider
            metaItem(legend.field.replacingOccurrences(of: "_", with: " "))
        }
        .padding(.top, 2)
    }

    /// "US" → 🇺🇸, "US/ZA" → 🇺🇸 🇿🇦. Невалидный код → исходная строка.
    private func nationalityFlag(_ raw: String) -> String {
        let parts = raw.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        let flags: [String] = parts.compactMap { code in
            let upper = code.uppercased()
            guard upper.count == 2,
                  upper.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
            let base: UInt32 = 127397
            var flag = ""
            for scalar in upper.unicodeScalars {
                if let s = UnicodeScalar(base + scalar.value) {
                    flag.unicodeScalars.append(s)
                }
            }
            return flag
        }
        return flags.isEmpty ? raw : flags.joined(separator: " ")
    }

    private func metaItem(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Theme.textTertiary)
    }

    private var metaDivider: some View {
        Circle()
            .fill(Theme.textTertiary.opacity(0.5))
            .frame(width: 2, height: 2)
    }

    private var intensityDots: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= legend.intensity ? Theme.accent : Theme.textTertiary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.top, 4)
    }

    private var favoriteStar: some View {
        LegendFavoriteStar(state: state, legendId: legend.id, size: 16, background: 36)
            .overlay(Circle().stroke(Theme.surfaceStroke, lineWidth: 1).frame(width: 36, height: 36))
    }

    // MARK: - Bio

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(t.legendsDetailBio)
            Text(localizedBio)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var localizedBio: String {
        switch state.language {
        case .ru:                  return legend.bio.ru
        case .en, .zh, .system:    return legend.bio.en
        }
    }

    // MARK: - Sources

    @ViewBuilder
    private var sourcesSection: some View {
        if !legend.sources.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader(t.legendsDetailSources)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(legend.sources) { src in
                        sourceRow(src)
                    }
                }
            }
        }
    }

    private func sourceRow(_ src: LegendSource) -> some View {
        Button {
            if let url = URL(string: src.url) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: sourceIcon(src.type))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .frame(width: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text(src.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(src.author)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(src.url)
    }

    private func sourceIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "book":      return "book"
        case "article":   return "doc.text"
        case "interview": return "mic"
        case "letter":    return "envelope"
        case "video":     return "play.rectangle"
        case "podcast":   return "headphones"
        default:          return "link"
        }
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundColor(Theme.textTertiary)
    }

    private var localizedName: String {
        switch state.language {
        case .ru:                  return legend.name.ru
        case .en, .zh, .system:    return legend.name.en
        }
    }

    private var localizedFullName: String {
        switch state.language {
        case .ru:                  return legend.fullName.ru
        case .en, .zh, .system:    return legend.fullName.en
        }
    }
}
