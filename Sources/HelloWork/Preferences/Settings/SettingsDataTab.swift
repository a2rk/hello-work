import SwiftUI

struct SettingsDataTab: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    @State private var showResetStatsAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard.section(title: t.settingsSectionStats) {
                SettingsCard.card {
                    statsResetRow
                }
            }
        }
        .alert(t.statsResetAlertTitle, isPresented: $showResetStatsAlert) {
            Button(t.cancel, role: .cancel) { }
            Button(t.statsResetAlertConfirm, role: .destructive) {
                state.stats.resetAll()
            }
        } message: {
            Text(t.statsResetAlertMessage)
        }
    }

    private var statsResetRow: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t.statsResetTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text(t.statsResetDescription)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(t.statsPrivacyNote)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            Spacer()
            Button {
                showResetStatsAlert = true
            } label: {
                Text(t.statsResetButton)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.danger)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.danger.opacity(0.10)))
                    .overlay(Capsule().stroke(Theme.danger.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
