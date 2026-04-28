import SwiftUI

/// Settings card модуля Meditation. Hero stats + Start button + hotkey row +
/// 2 toggle'а. Запускает сессию через state.meditation.start().
struct MeditationSettingsCard: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    @State private var showingHotkeyRecorder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            heroStat
            startButton
            settingsBlock
            Spacer(minLength: 0)
        }
        .sheet(isPresented: $showingHotkeyRecorder) {
            HotkeyRecorderSheet(
                onCancel: { showingHotkeyRecorder = false },
                onConfirm: { keyCode, mods in
                    state.meditationHotkey = .custom(keyCode: keyCode, modifiers: mods)
                    showingHotkeyRecorder = false
                }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t.meditationTitle)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
            Text(t.meditationSubtitle)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroStat: some View {
        let stats = state.meditationStats
        return HStack(spacing: 12) {
            Image(systemName: "circle.dotted")
                .font(.system(size: 20))
                .foregroundColor(Theme.accent)
            Text(t.meditationStatsLine(stats.sessionsCount, stats.totalMinutes))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.accent.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.accent.opacity(0.30), lineWidth: 1)
        )
    }

    private var startButton: some View {
        Button {
            state.meditation.start()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(t.meditationStartButton)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(t.meditationDurationLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.black.opacity(0.65))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Theme.accent))
        }
        .buttonStyle(.plain)
        .disabled(state.meditation.isActive)
    }

    private var settingsBlock: some View {
        SettingsCard.section(title: "") {
            SettingsCard.card {
                SettingsCard.row(
                    title: t.meditationHotkeyLabel,
                    description: state.meditationHotkey.displayString()
                ) {
                    Button("Change") { showingHotkeyRecorder = true }
                        .controlSize(.small)
                }
                SettingsCard.divider()
                SettingsCard.row(
                    title: t.meditationShowProgressTitle,
                    description: t.meditationShowProgressDesc
                ) {
                    Toggle("", isOn: $state.meditationShowProgress)
                        .toggleStyle(.switch).controlSize(.small)
                        .tint(Theme.accent).labelsHidden()
                }
                SettingsCard.divider()
                SettingsCard.row(
                    title: t.meditationCompletionSoundTitle,
                    description: t.meditationCompletionSoundDesc
                ) {
                    Toggle("", isOn: $state.meditationCompletionSound)
                        .toggleStyle(.switch).controlSize(.small)
                        .tint(Theme.accent).labelsHidden()
                }
            }
        }
    }
}
