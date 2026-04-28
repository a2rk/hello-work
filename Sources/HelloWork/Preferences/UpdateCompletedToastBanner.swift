import SwiftUI

/// Кратковременный info-banner после успешного auto-update'а. Auto-dismiss
/// 5 сек или click. Показывается только если AppState.queueUpdateToastVersion
/// != nil (set'ится в AppState.init при detection version-change).
struct UpdateCompletedToastBanner: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState

    @State private var autoDismissWorkItem: DispatchWorkItem?

    var body: some View {
        if let version = state.queueUpdateToastVersion {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.accent)
                Text(t.updateCompletedToast(version))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.accent.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.accent.opacity(0.30), lineWidth: 1)
            )
            .onAppear { scheduleAutoDismiss() }
            .onDisappear { autoDismissWorkItem?.cancel() }
        }
    }

    private func scheduleAutoDismiss() {
        autoDismissWorkItem?.cancel()
        let work = DispatchWorkItem { dismiss() }
        autoDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)
    }

    private func dismiss() {
        autoDismissWorkItem?.cancel()
        state.queueUpdateToastVersion = nil
    }
}
