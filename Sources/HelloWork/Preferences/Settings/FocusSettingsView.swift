import SwiftUI
import AppKit
import Carbon.HIToolbox

struct FocusSettingsView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState

    @State private var showingRecorder = false
    @State private var conflictWarning: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Включение фичи
            settingRow(
                title: t.focusEnableTitle,
                description: t.focusEnableDesc
            ) {
                Toggle("", isOn: $state.focusModeEnabled)
                    .toggleStyle(.switch).controlSize(.small)
                    .tint(Theme.accent).labelsHidden()
            }

            rowDivider()

            // 2. Hotkey
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t.focusHotkeyTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text(t.focusHotkeyDesc)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }

                HStack(spacing: 6) {
                    ForEach(FocusHotkey.Preset.allCases, id: \.self) { preset in
                        hotkeyChip(
                            label: FocusHotkey.preset(preset).displayString(),
                            isOn: state.focusHotkey == .preset(preset)
                        ) {
                            state.focusHotkey = .preset(preset)
                            updateConflictWarning()
                        }
                    }
                    customChip
                }

                if let warn = conflictWarning {
                    Text(warn)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.danger.opacity(0.85))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .disabled(!state.focusModeEnabled)
            .opacity(state.focusModeEnabled ? 1 : 0.5)

            rowDivider()

            // 3. Затемнение
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t.focusOpacityTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text(t.focusOpacityDesc)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Text("\(Int(state.focusDimOpacity * 100))%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                Slider(value: $state.focusDimOpacity, in: 0.50...0.95, step: 0.05)
                    .tint(Theme.accent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .disabled(!state.focusModeEnabled)
            .opacity(state.focusModeEnabled ? 1 : 0.5)

            rowDivider()

            // 4. Accessibility
            settingRow(
                title: t.focusUseAXTitle,
                description: t.focusUseAXDesc
            ) {
                Toggle("", isOn: axBinding)
                    .toggleStyle(.switch).controlSize(.small)
                    .tint(Theme.accent).labelsHidden()
            }
            .disabled(!state.focusModeEnabled)
            .opacity(state.focusModeEnabled ? 1 : 0.5)
        }
        .onAppear { updateConflictWarning() }
        .sheet(isPresented: $showingRecorder) {
            HotkeyRecorderSheet(
                onCancel: { showingRecorder = false },
                onConfirm: { keyCode, mods in
                    state.focusHotkey = .custom(keyCode: keyCode, modifiers: mods)
                    showingRecorder = false
                    updateConflictWarning()
                }
            )
        }
    }

    // MARK: - AX prompt

    private var axBinding: Binding<Bool> {
        Binding(
            get: { state.focusUseAccessibility },
            set: { newValue in
                if newValue && !AXIsProcessTrusted() {
                    // Запрашиваем доступ. Системный prompt появится один раз.
                    let prompt = "AXTrustedCheckOptionPrompt" as CFString
                    let opts = [prompt: true] as CFDictionary
                    _ = AXIsProcessTrustedWithOptions(opts)
                }
                state.focusUseAccessibility = newValue
            }
        )
    }

    // MARK: - Custom chip

    @ViewBuilder
    private var customChip: some View {
        let isCustom: Bool = {
            if case .custom = state.focusHotkey { return true }
            return false
        }()
        let label: String = {
            if case .custom = state.focusHotkey {
                return state.focusHotkey.displayString()
            }
            return t.focusHotkeyCustom
        }()

        Button {
            showingRecorder = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "pencil")
                    .font(.system(size: 9, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isCustom ? .white : Theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(isCustom ? Theme.accent.opacity(0.18) : Color.white.opacity(0.04))
            )
            .overlay(
                Capsule().stroke(isCustom ? Theme.accent.opacity(0.45) : Theme.surfaceStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func hotkeyChip(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundColor(isOn ? .white : Theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(isOn ? Theme.accent.opacity(0.18) : Color.white.opacity(0.04))
                )
                .overlay(
                    Capsule().stroke(isOn ? Theme.accent.opacity(0.45) : Theme.surfaceStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func updateConflictWarning() {
        if let warn = HotkeyManager.systemConflict(for: state.focusHotkey) {
            conflictWarning = "\(t.focusHotkeyConflict): \(warn)"
        } else {
            conflictWarning = nil
        }
    }

    // MARK: - Row helpers (упрощённые копии из SettingsView, чтобы не выносить отдельно)

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
}

// MARK: - Recorder

struct HotkeyRecorderSheet: View {
    @Environment(\.t) var t
    let onCancel: () -> Void
    let onConfirm: (UInt32, UInt32) -> Void

    @State private var captured: (keyCode: UInt32, modifiers: UInt32)?
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t.focusRecorderTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(t.focusRecorderHint)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.surfaceStroke, lineWidth: 1)
                    )

                Text(displayCaptured)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(captured == nil ? Theme.textTertiary : .white)
            }
            .frame(height: 80)

            HStack {
                Button(t.cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(t.focusRecorderConfirm) {
                    if let c = captured {
                        onConfirm(c.keyCode, c.modifiers)
                    }
                }
                .disabled(captured == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .background(Color.black.opacity(0.6))
        .onAppear { startMonitoring() }
        .onDisappear { stopMonitoring() }
    }

    private var displayCaptured: String {
        guard let c = captured else {
            return t.focusRecorderPlaceholder
        }
        let hk = FocusHotkey.custom(keyCode: c.keyCode, modifiers: c.modifiers)
        return hk.displayString()
    }

    private func startMonitoring() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let kc = UInt32(event.keyCode)
            let mods = nsModifiersToCarbon(event.modifierFlags)
            // Требуем хотя бы один модификатор (кроме F-клавиш).
            let isFKey = (kc >= UInt32(kVK_F1) && kc <= UInt32(kVK_F20))
            if mods == 0 && !isFKey {
                return event   // даём системе обработать (юзер может Cmd+Q закрыть)
            }
            captured = (kc, mods)
            return nil  // съедаем event
        }
    }

    private func stopMonitoring() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    private func nsModifiersToCarbon(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command)  { mods |= UInt32(cmdKey) }
        if flags.contains(.shift)    { mods |= UInt32(shiftKey) }
        if flags.contains(.option)   { mods |= UInt32(optionKey) }
        if flags.contains(.control)  { mods |= UInt32(controlKey) }
        return mods
    }
}
