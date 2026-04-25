import SwiftUI

struct SettingsView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    @State private var customGraceInput: String = ""
    @State private var showGraceTooBigAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text(t.settingsTitle)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text(t.settingsSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.bottom, 4)

            section(title: t.settingsSectionBehavior) {
                multiRowCard {
                    settingRow(
                        title: t.settingEnableTitle,
                        description: t.settingEnableDesc
                    ) {
                        Toggle("", isOn: $state.enabled)
                            .toggleStyle(.switch).controlSize(.small)
                            .tint(Theme.accent).labelsHidden()
                    }
                    rowDivider()
                    settingRow(
                        title: t.settingLaunchAtLoginTitle,
                        description: t.settingLaunchAtLoginDesc
                    ) {
                        Toggle("", isOn: launchAtLoginBinding)
                            .toggleStyle(.switch).controlSize(.small)
                            .tint(Theme.accent).labelsHidden()
                    }
                    rowDivider()
                    settingRow(
                        title: t.settingAutoUpdateTitle,
                        description: t.settingAutoUpdateDesc
                    ) {
                        Toggle("", isOn: $state.autoUpdate)
                            .toggleStyle(.switch).controlSize(.small)
                            .tint(Theme.accent).labelsHidden()
                    }
                    rowDivider()
                    settingRow(
                        title: t.settingPatternOverlayTitle,
                        description: t.settingPatternOverlayDesc
                    ) {
                        Toggle("", isOn: $state.patternOverlay)
                            .toggleStyle(.switch).controlSize(.small)
                            .tint(Theme.accent).labelsHidden()
                    }
                }
            }

            section(title: t.settingsSectionSchedule) {
                VStack(spacing: 12) {
                    multiRowCard {
                        settingRow(
                            title: t.settingSnapStepTitle,
                            description: t.settingSnapStepDesc
                        ) {
                            Picker("", selection: $state.snapStep) {
                                ForEach(AppState.snapStepOptions, id: \.self) { step in
                                    Text("\(step) \(t.unitMin)").tag(step)
                                }
                            }
                            .labelsHidden().pickerStyle(.menu)
                            .controlSize(.small).frame(width: 110)
                        }
                    }
                    graceCard
                }
            }

            section(title: t.settingsSectionUpdates) {
                multiRowCard {
                    updateRow
                }
            }

            section(title: t.settingsSectionInterface) {
                multiRowCard {
                    settingRow(
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
                }
            }

            Spacer(minLength: 0)
        }
        .alert(t.graceTooBigTitle, isPresented: $showGraceTooBigAlert) {
            Button(t.graceTooBigOk, role: .cancel) { }
        } message: {
            Text(t.graceTooBigMessage)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { state.launchAtLogin },
            set: { state.setLaunchAtLogin($0) }
        )
    }

    // MARK: - Section helper

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Theme.textTertiary)
                .padding(.horizontal, 4)
            content()
        }
        .frame(maxWidth: Layout.settingsCardMaxWidth, alignment: .leading)
    }

    // MARK: - Updates row

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
            Button {
                Task { await state.checkForUpdates() }
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

    // MARK: - Grace card

    private var graceCard: some View {
        multiRowCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t.settingGraceTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Text(t.settingGraceDesc)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                FlowChips(items: AppState.gracePresetSeconds.map { secs in
                    ChipModel(
                        label: t.menuGraceLabel(secs),
                        isOn: state.enabledGracePresets.contains(secs),
                        accent: true
                    ) {
                        if state.enabledGracePresets.contains(secs) {
                            state.enabledGracePresets.remove(secs)
                        } else {
                            state.enabledGracePresets.insert(secs)
                        }
                    }
                })

                if !state.customGraceMinutes.isEmpty {
                    FlowChips(items: state.customGraceMinutes.map { mins in
                        ChipModel(
                            label: t.menuGraceLabel(mins * 60),
                            isOn: true,
                            accent: false,
                            removable: true
                        ) {
                            state.customGraceMinutes.removeAll { $0 == mins }
                        }
                    })
                }

                HStack(spacing: 8) {
                    TextField(t.settingGraceCustomPlaceholder, text: $customGraceInput)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(width: 100)
                        .onSubmit { addCustomGrace() }
                    Button(t.settingGraceCustomAdd) { addCustomGrace() }
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func addCustomGrace() {
        let trimmed = customGraceInput.trimmingCharacters(in: .whitespaces)
        guard let mins = Int(trimmed), mins > 0 else { return }
        if mins > 30 {
            showGraceTooBigAlert = true
            customGraceInput = ""
            return
        }
        if !state.customGraceMinutes.contains(mins) {
            state.customGraceMinutes.append(mins)
            state.customGraceMinutes.sort()
        }
        customGraceInput = ""
    }

    // MARK: - Row + card helpers

    @ViewBuilder
    private func settingRow<Trailing: View>(
        title: String,
        description: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func rowDivider() -> some View {
        Rectangle()
            .fill(Theme.surfaceStroke)
            .frame(height: 1)
            .padding(.leading, 16)
    }

    @ViewBuilder
    private func multiRowCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.surfaceStroke, lineWidth: 1)
        )
    }
}

// MARK: - Chips

private struct ChipModel: Identifiable {
    let id = UUID()
    let label: String
    let isOn: Bool
    let accent: Bool
    var removable: Bool = false
    let action: () -> Void
}

private struct FlowChips: View {
    let items: [ChipModel]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { chip in
                Button(action: chip.action) {
                    HStack(spacing: 5) {
                        Text(chip.label)
                            .font(.system(size: 11, weight: .medium))
                        if chip.removable {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .semibold))
                                .opacity(0.55)
                        }
                    }
                    .foregroundColor(chip.isOn ? .white : Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(
                            chip.isOn
                            ? (chip.accent ? Theme.accent.opacity(0.18) : Color.white.opacity(0.10))
                            : Color.white.opacity(0.04)
                        )
                    )
                    .overlay(
                        Capsule().stroke(
                            chip.isOn
                            ? (chip.accent ? Theme.accent.opacity(0.45) : Theme.surfaceStroke)
                            : Theme.surfaceStroke,
                            lineWidth: 1
                        )
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}
