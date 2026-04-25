import SwiftUI

struct SettingsView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text(t.settingsTitle)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text(t.settingsSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            settingCard {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t.settingEnableTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text(t.settingEnableDesc)
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

            languageBlock

            updatesBlock

            Spacer(minLength: 0)
        }
    }

    // MARK: - Language

    private var languageBlock: some View {
        settingCard {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t.settingLanguageTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Text(t.settingLanguageDesc)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Picker("", selection: $state.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName(t)).tag(lang)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 140)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Updates block

    private var updatesBlock: some View {
        settingCard {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(t.settingsUpdatesTitle)
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
                        Text(state.isCheckingUpdates ? t.checkingButton : t.checkButton)
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
            return t.settingsUpdateAvailable(v, AppVersion.marketing)
        }
        if let last = state.lastUpdateCheck {
            return t.settingsCurrentVersion(AppVersion.marketing, formatRelativeTime(last))
        }
        return t.settingsCurrentVersionShort(AppVersion.marketing)
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        switch state.language {
        case .ru: formatter.locale = Locale(identifier: "ru_RU")
        case .zh: formatter.locale = Locale(identifier: "zh_CN")
        case .en: formatter.locale = Locale(identifier: "en_US")
        case .system: formatter.locale = Locale.current
        }
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
