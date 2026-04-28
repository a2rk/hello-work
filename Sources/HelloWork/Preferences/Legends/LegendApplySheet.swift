import SwiftUI

/// Скелет sheet'а для apply legend schedule. TASK-L55 закладывает только
/// title + Cancel/Confirm кнопки. TASK-L57 наполнит — список managedApps,
/// picker категории на каждом, предпросмотр.
struct LegendApplySheet: View {
    @Environment(\.t) var t
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var state: AppState
    let legend: Legend
    /// Вызывается при подтверждении (TASK-L57 наполнит assignments).
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t.legendsApplyTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(t.legendsApplySubtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }

            Text("— TASK-L57 наполнит этот sheet —")
                .font(.system(size: 11))
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

            HStack {
                Spacer()
                Button(t.legendsApplyCancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(t.legendsApplyConfirm) {
                    onApply()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(true)  // L57 включит когда будут assignments.
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }
}
