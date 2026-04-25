import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Настройки")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text("Глобальные параметры Hello work.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            settingCard {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Включить")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Глобальный режим. Если выключено — все оверлеи скрываются и приложения работают без ограничений.")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("", isOn: $state.enabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(Theme.accent)
                        .labelsHidden()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }

            updatesBlock

            Spacer(minLength: 0)
        }
    }

    // MARK: - Updates block

    private var updatesBlock: some View {
        settingCard {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Обновления")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        if state.updateAvailable {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 5, height: 5)
                        }
                    }
                    Text(updatesSubtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let err = state.lastUpdateCheckError {
                        Text(err)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.danger.opacity(0.85))
                    }
                }
                Spacer()
                Button {
                    Task { await state.checkForUpdates() }
                } label: {
                    HStack(spacing: 5) {
                        if state.isCheckingUpdates {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        Text(state.isCheckingUpdates ? "Проверяю" : "Проверить")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                    .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(state.isCheckingUpdates)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private var updatesSubtitle: String {
        if state.updateAvailable, let v = state.latestRemoteVersion {
            return "Доступна v\(v). Текущая v\(AppVersion.marketing)."
        }
        if let last = state.lastUpdateCheck {
            return "Текущая v\(AppVersion.marketing). Проверено \(formatRelativeTime(last))."
        }
        return "Текущая v\(AppVersion.marketing)."
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    @ViewBuilder
    private func settingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: 460, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
    }
}
