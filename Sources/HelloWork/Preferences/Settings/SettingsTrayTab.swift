import SwiftUI

struct SettingsTrayTab: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard.section(title: t.traySectionIcon) {
                SettingsCard.card {
                    SettingsCard.row(
                        title: t.trayShowIconTitle,
                        description: t.trayShowIconDesc
                    ) {
                        Toggle("", isOn: $state.showStatusBarIcon)
                            .toggleStyle(.switch).controlSize(.small)
                            .tint(Theme.accent).labelsHidden()
                    }
                    SettingsCard.divider()
                    SettingsCard.row(
                        title: t.trayIconStyleTitle,
                        description: t.trayIconStyleDesc
                    ) {
                        Picker("", selection: $state.statusIconStyle) {
                            Text(t.trayIconStyleSolid).tag(StatusIconStyle.solid)
                            Text(t.trayIconStyleOutline).tag(StatusIconStyle.outline)
                        }
                        .labelsHidden().pickerStyle(.menu)
                        .controlSize(.small).frame(width: 130)
                        .disabled(!state.showStatusBarIcon)
                    }
                    SettingsCard.divider()
                    SettingsCard.row(
                        title: t.trayCountdownTitle,
                        description: t.trayCountdownDesc
                    ) {
                        Toggle("", isOn: $state.showGraceCountdownInBar)
                            .toggleStyle(.switch).controlSize(.small)
                            .tint(Theme.accent).labelsHidden()
                            .disabled(!state.showStatusBarIcon)
                    }
                }
            }

            SettingsCard.section(title: t.traySectionBehavior) {
                SettingsCard.card {
                    SettingsCard.row(
                        title: t.trayPeekTitle,
                        description: t.trayPeekDesc
                    ) {
                        Picker("", selection: $state.menubarPeekSeconds) {
                            ForEach(AppState.menubarPeekOptions, id: \.self) { secs in
                                Text(peekLabel(secs)).tag(secs)
                            }
                        }
                        .labelsHidden().pickerStyle(.menu)
                        .controlSize(.small).frame(width: 130)
                        .disabled(!state.menubarHiderEnabled)
                    }
                    SettingsCard.divider()
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t.trayOpenMenubarPageTitle)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text(t.trayOpenMenubarPageDesc)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button {
                            state.prefsSelection = .section(.menubar)
                        } label: {
                            HStack(spacing: 5) {
                                Text(t.trayOpenMenubarPageButton)
                                    .font(.system(size: 11, weight: .medium))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                            .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
    }

    private func peekLabel(_ secs: Int) -> String {
        if secs == 0 { return t.trayPeekOff }
        return "\(secs) \(t.unitSec)"
    }
}
