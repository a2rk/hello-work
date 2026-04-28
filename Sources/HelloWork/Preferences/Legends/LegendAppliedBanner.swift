import SwiftUI

/// Subtle-accent banner: «Сейчас применено: <legend.name>» + Revert button.
/// Используется в LegendsListView (показывает если приложен ЛЮБОЙ legend) и
/// LegendDetailView (показывает если приложен именно ТОТ что открыт).
struct LegendAppliedBanner: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    /// Если задан — показывать только когда `appliedLegendId == legendId`.
    /// nil — показывать для любого applied.
    var legendIdFilter: String? = nil

    @State private var showRevertAlert: Bool = false

    private var appliedLegend: Legend? {
        guard let id = state.appliedLegendId else { return nil }
        if let f = legendIdFilter, f != id { return nil }
        return LegendsLibrary.shared.all.first { $0.id == id }
    }

    var body: some View {
        if let legend = appliedLegend {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.accent)
                Text(t.legendsAppliedBanner(localizedName(legend)))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                Spacer()
                revertButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.accent.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.accent.opacity(0.35), lineWidth: 1)
            )
            .alert(t.legendsRevertConfirmTitle, isPresented: $showRevertAlert) {
                Button(t.legendsApplyCancel, role: .cancel) {}
                Button(t.legendsRevert, role: .destructive) {
                    LegendApplyEngine.revert(state: state)
                }
            } message: {
                Text(t.legendsRevertConfirmMessage)
            }
        }
    }

    private var revertButton: some View {
        Button {
            showRevertAlert = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10, weight: .semibold))
                Text(t.legendsRevert)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Theme.accent.opacity(0.30)))
            .overlay(Capsule().stroke(Theme.accent.opacity(0.60), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func localizedName(_ legend: Legend) -> String {
        switch state.language {
        case .ru:                  return legend.name.ru
        case .en, .zh, .system:    return legend.name.en
        }
    }
}
