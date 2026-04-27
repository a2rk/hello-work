import SwiftUI

struct SettingsAppTab: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard.section(title: t.settingsSectionInterface) {
                SettingsCard.card {
                    SettingsCard.row(
                        title: t.settingLanguageTitle,
                        description: t.settingLanguageDesc
                    ) {
                        Picker("", selection: $state.language) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName(t)).tag(lang)
                            }
                        }
                        .labelsHidden().pickerStyle(.menu)
                        .controlSize(.small).frame(width: 160)
                    }
                    SettingsCard.divider()
                    SettingsCard.row(
                        title: t.settingLaunchAtLoginTitle,
                        description: t.settingLaunchAtLoginDesc
                    ) {
                        Toggle("", isOn: launchAtLoginBinding)
                            .toggleStyle(.switch).controlSize(.small)
                            .tint(Theme.accent).labelsHidden()
                    }
                }
            }

            SettingsCard.section(title: t.settingsSectionUpdates) {
                SettingsCard.card {
                    SettingsCard.row(
                        title: t.settingAutoUpdateTitle,
                        description: t.settingAutoUpdateDesc
                    ) {
                        Toggle("", isOn: $state.autoUpdate)
                            .toggleStyle(.switch).controlSize(.small)
                            .tint(Theme.accent).labelsHidden()
                    }
                    SettingsCard.divider()
                    updateRow
                }
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { state.launchAtLogin },
            set: { state.setLaunchAtLogin($0) }
        )
    }

    // MARK: - Updates row (адаптировано под общие хелперы)

    private var updateRow: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(t.settingsUpdatesTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    if state.updateAvailable {
                        Circle().fill(Theme.accent).frame(width: 5, height: 5)
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
            HStack(spacing: 6) {
                Button {
                    Task { await state.checkForUpdates(force: true) }
                } label: {
                    HStack(spacing: 5) {
                        if state.isCheckingUpdates {
                            ProgressView().controlSize(.small).scaleEffect(0.6)
                        } else {
                            Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .semibold))
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

                Button {
                    state.prefsSelection = .section(.updates)
                } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                        .overlay(Circle().stroke(Theme.surfaceStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help(t.updatesOpenPage)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
}
