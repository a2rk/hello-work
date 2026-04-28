import SwiftUI

/// Корневой view модуля «Легенды». Внутри своя push-style навигация
/// (List ↔ Detail) через @State selectedLegend — без дополнительных
/// SidebarSelection-кейсов.
///
/// На этом этапе skeleton: TASK-L25 наполняет list, TASK-L37 — detail.
struct LegendsListView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState

    @State private var selectedLegend: Legend?

    var body: some View {
        if let legend = selectedLegend {
            LegendDetailView(state: state, legend: legend, onBack: {
                selectedLegend = nil
            })
        } else {
            listPlaceholder
        }
    }

    private var listPlaceholder: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(t.sectionLegends)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text("\(LegendsLibrary.shared.all.count) loaded")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            // Минимальный preview-список — TASK-L25..L36 заменят на полноценный
            // grid/list с поиском и фильтрами.
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(LegendsLibrary.shared.all) { legend in
                        Button {
                            selectedLegend = legend
                        } label: {
                            HStack {
                                Text("\(legend.order). \(legend.name.en)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(legend.yearsOfLife)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textTertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
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
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }
}

/// Skeleton detail view — наполнится в TASK-L37..L48.
struct LegendDetailView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    let legend: Legend
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                onBack()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text(t.sectionLegends)
                        .font(.system(size: 12))
                }
                .foregroundColor(Theme.textSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(legend.name.en)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text("\(legend.fullName.en) · \(legend.yearsOfLife)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer(minLength: 0)
        }
    }
}
