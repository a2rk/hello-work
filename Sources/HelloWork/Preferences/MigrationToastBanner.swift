import SwiftUI

/// One-time баннер после успешной миграции со stub+engine layout на single-app
/// в /Applications. Показывается в верху Prefs detail. Auto-dismiss через 8 сек
/// или клик «Got it». После dismiss — `state.queueMigrationToast = false`,
/// больше не возвращается до следующей миграции (которой уже не будет — флаг).
struct MigrationToastBanner: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState

    @State private var autoDismissWorkItem: DispatchWorkItem?

    var body: some View {
        if state.queueMigrationToast {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.uturn.right.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(t.migrationToastTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text(t.migrationToastBody)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text(t.migrationToastDismiss)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.accent.opacity(0.20)))
                        .overlay(Capsule().stroke(Theme.accent.opacity(0.50), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.accent.opacity(0.40), lineWidth: 1)
            )
            .onAppear { scheduleAutoDismiss() }
            .onDisappear { autoDismissWorkItem?.cancel() }
        }
    }

    private func scheduleAutoDismiss() {
        autoDismissWorkItem?.cancel()
        let work = DispatchWorkItem { dismiss() }
        autoDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: work)
    }

    private func dismiss() {
        autoDismissWorkItem?.cancel()
        state.queueMigrationToast = false
    }
}
