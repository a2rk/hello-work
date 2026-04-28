import SwiftUI

/// Sheet apply legend schedule: список активных managedApps + picker категории
/// на каждом + preview ('будет создано N slots'). TASK-L59 свяжет Confirm
/// с реальным LegendApplyEngine.apply.
struct LegendApplySheet: View {
    @Environment(\.t) var t
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var state: AppState
    let legend: Legend
    /// Вызывается при подтверждении с финальным набором assignments.
    let onApply: ([String: LegendApplyCategory]) -> Void

    /// bundleID → выбранная категория. По умолчанию все .skip.
    @State private var assignments: [String: LegendApplyCategory] = [:]

    private var activeApps: [ManagedApp] {
        state.managedApps.filter { !$0.isArchived }
    }

    private var hasAnyAssignment: Bool {
        assignments.values.contains { $0 != .skip }
    }

    /// Сумма slots, которые будут созданы: для каждого app != skip считаем
    /// slotsFor(category) и суммируем длины. Уникальные windows × apps.
    private var previewSlotCount: Int {
        activeApps.reduce(0) { acc, app in
            let cat = assignments[app.bundleID] ?? .skip
            return acc + LegendApplyEngine.slotsFor(legend: legend, category: cat).count
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider().background(Theme.surfaceStroke)
            if activeApps.isEmpty {
                emptyState
            } else {
                appsList
            }
            Divider().background(Theme.surfaceStroke)
            previewBar
            actionRow
        }
        .padding(20)
        .frame(minWidth: 460, idealWidth: 520, minHeight: 360)
        .onAppear { initializeAssignments() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t.legendsApplyTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text(t.legendsApplySubtitle)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private var emptyState: some View {
        Text(t.legendsApplyNoAppsHint)
            .font(.system(size: 12))
            .foregroundColor(Theme.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
    }

    private var appsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(activeApps) { app in
                    appRow(app)
                }
            }
        }
        .frame(maxHeight: 280)
    }

    private func appRow(_ app: ManagedApp) -> some View {
        let current = assignments[app.bundleID] ?? .skip
        return HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 24, height: 24)
            Text(app.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            categoryPicker(bundleID: app.bundleID, current: current)
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

    private func categoryPicker(bundleID: String, current: LegendApplyCategory) -> some View {
        Menu {
            categoryButton(.skip,     for: bundleID, current: current, title: t.legendsApplyAppCategorySkip)
            categoryButton(.work,     for: bundleID, current: current, title: t.legendsApplyAppCategoryWork)
            categoryButton(.personal, for: bundleID, current: current, title: t.legendsApplyAppCategoryPersonal)
        } label: {
            HStack(spacing: 4) {
                Text(categoryTitle(current))
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(categoryColor(current).opacity(current == .skip ? 0.04 : 0.16)))
            .overlay(Capsule().stroke(categoryColor(current).opacity(current == .skip ? 0.20 : 0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .menuStyle(.borderlessButton)
        .frame(width: 150)
    }

    private func categoryButton(
        _ category: LegendApplyCategory,
        for bundleID: String,
        current: LegendApplyCategory,
        title: String
    ) -> some View {
        Button {
            assignments[bundleID] = category
        } label: {
            HStack {
                Text(title)
                if current == category {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    private func categoryTitle(_ c: LegendApplyCategory) -> String {
        switch c {
        case .skip:     return t.legendsApplyAppCategorySkip
        case .work:     return t.legendsApplyAppCategoryWork
        case .personal: return t.legendsApplyAppCategoryPersonal
        }
    }

    private func categoryColor(_ c: LegendApplyCategory) -> Color {
        switch c {
        case .skip:     return Color.white
        case .work:     return Theme.accent
        case .personal: return Color(red: 0.70, green: 0.55, blue: 0.95)
        }
    }

    @ViewBuilder
    private var previewBar: some View {
        let nApps = assignments.values.filter { $0 != .skip }.count
        let total = previewSlotCount
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
            if nApps == 0 {
                Text("—")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            } else {
                Text("\(nApps) apps → \(total) slots")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
    }

    private var actionRow: some View {
        HStack {
            Spacer()
            Button(t.legendsApplyCancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            Button(t.legendsApplyConfirm) {
                onApply(assignments)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!hasAnyAssignment)
        }
    }

    private func initializeAssignments() {
        for app in activeApps where assignments[app.bundleID] == nil {
            assignments[app.bundleID] = .skip
        }
    }
}
