import SwiftUI

struct SettingsScheduleTab: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    @State private var customGraceInput: String = ""
    @State private var showGraceTooBigAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard.section(title: t.settingsSectionBehavior) {
                SettingsCard.card {
                    SettingsCard.row(
                        title: t.settingEnableTitle,
                        description: t.settingEnableDesc
                    ) {
                        Toggle("", isOn: $state.enabled)
                            .toggleStyle(.switch).controlSize(.small)
                            .tint(Theme.accent).labelsHidden()
                    }
                    SettingsCard.divider()
                    SettingsCard.row(
                        title: t.settingPatternOverlayTitle,
                        description: t.settingPatternOverlayDesc
                    ) {
                        Toggle("", isOn: $state.patternOverlay)
                            .toggleStyle(.switch).controlSize(.small)
                            .tint(Theme.accent).labelsHidden()
                    }
                }
            }

            SettingsCard.section(title: t.settingsSectionSchedule) {
                VStack(spacing: 12) {
                    SettingsCard.card {
                        SettingsCard.row(
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
        }
        .alert(t.graceTooBigTitle, isPresented: $showGraceTooBigAlert) {
            Button(t.graceTooBigOk, role: .cancel) { }
        } message: {
            Text(t.graceTooBigMessage)
        }
    }

    // MARK: - Grace card

    private var graceCard: some View {
        SettingsCard.card {
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
}

// MARK: - Chips (used by Schedule grace card)

struct ChipModel: Identifiable {
    let id = UUID()
    let label: String
    let isOn: Bool
    let accent: Bool
    var removable: Bool = false
    let action: () -> Void
}

struct FlowChips: View {
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
