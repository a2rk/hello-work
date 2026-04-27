import SwiftUI
import AppKit
import Carbon.HIToolbox

struct MenubarView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    @ObservedObject var hider: MenubarHiderController
    @ObservedObject var perms: PermissionsManager

    @State private var items: [MenubarItemsScanner.Item] = []
    @State private var refreshTimer: Timer?
    @State private var conflictWarning: String?
    @State private var showingRecorder = false

    init(state: AppState) {
        self.state = state
        self.hider = state.menubarHider
        self.perms = state.permissions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            heroButtons

            previewSection

            settingsSection

            disclaimer

            Spacer(minLength: 0)
        }
        .onAppear {
            items = MenubarItemsScanner.scan()
            startRefreshTimer()
            updateConflictWarning()
        }
        .onDisappear { stopRefreshTimer() }
        .sheet(isPresented: $showingRecorder) {
            HotkeyRecorderSheet(
                onCancel: { showingRecorder = false },
                onConfirm: { keyCode, mods in
                    state.menubarHotkey = .custom(keyCode: keyCode, modifiers: mods)
                    showingRecorder = false
                    updateConflictWarning()
                }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t.sectionMenubar)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
            Text(t.menubarSubtitle)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Hero

    private var heroButtons: some View {
        HStack(spacing: 10) {
            heroButton(
                title: t.menubarHideAll,
                primary: true,
                action: { hider.collapseAll() }
            )
            heroButton(
                title: t.menubarShowAll,
                primary: false,
                action: { hider.expandAll() }
            )

            Spacer()

            if !state.menubarHiderEnabled {
                Toggle(isOn: $state.menubarHiderEnabled) {
                    Text(t.menubarEnableLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .toggleStyle(.switch).controlSize(.small)
                .tint(Theme.accent)
            } else {
                statusPill
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(hider.isCollapsed ? Theme.accent : Theme.danger.opacity(0.7))
                .frame(width: 5, height: 5)
            Text(hider.isCollapsed ? t.menubarStateCollapsed : t.menubarStateExpanded)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.05)))
        .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
    }

    private func heroButton(title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(primary ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(primary ? Theme.accent : Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule().stroke(primary ? Color.clear : Theme.surfaceStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!state.menubarHiderEnabled)
        .opacity(state.menubarHiderEnabled ? 1 : 0.45)
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t.menubarPreviewNow.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Theme.textTertiary)

            MenubarPreviewCard(items: items, isCollapsed: false)

            Text(t.menubarItemCount(items.count))
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)

            Text(t.menubarPreviewAfter.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Theme.textTertiary)
                .padding(.top, 4)

            MenubarPreviewCard(items: items, isCollapsed: true)

            Text(t.menubarHiddenHint)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: Layout.settingsCardMaxWidth, alignment: .leading)
    }

    // MARK: - Settings

    @ViewBuilder
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Hotkey
            VStack(alignment: .leading, spacing: 8) {
                Text(t.menubarHotkeyTitle.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundColor(Theme.textTertiary)
                HStack(spacing: 6) {
                    ForEach(MenubarHotkey.Preset.allCases, id: \.self) { preset in
                        hotkeyChip(
                            label: MenubarHotkey.preset(preset).displayString(),
                            isOn: state.menubarHotkey == .preset(preset)
                        ) {
                            state.menubarHotkey = .preset(preset)
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
            .opacity(state.menubarHiderEnabled ? 1 : 0.45)
            .disabled(!state.menubarHiderEnabled)

            // Auto
            VStack(alignment: .leading, spacing: 6) {
                Text(t.menubarAutoTitle.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundColor(Theme.textTertiary)
                autoToggle(t.menubarAutoFocus, binding: $state.menubarHideOnFocus)
                autoToggle(t.menubarAutoSchedule, binding: $state.menubarHideOnSchedule)
                autoToggle(t.menubarPersist, binding: $state.menubarPersistCollapsed)
            }
            .opacity(state.menubarHiderEnabled ? 1 : 0.45)
            .disabled(!state.menubarHiderEnabled)
        }
        .frame(maxWidth: Layout.settingsCardMaxWidth, alignment: .leading)
    }

    private func autoToggle(_ label: String, binding: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Toggle("", isOn: binding)
                .toggleStyle(.switch).controlSize(.small)
                .tint(Theme.accent).labelsHidden()
        }
    }

    @ViewBuilder
    private var customChip: some View {
        let isCustom: Bool = {
            if case .custom = state.menubarHotkey { return true }
            return false
        }()
        let label: String = {
            if case .custom = state.menubarHotkey {
                return state.menubarHotkey.displayString()
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

    // MARK: - Disclaimer

    private var disclaimer: some View {
        Text(t.menubarDisclaimer)
            .font(.system(size: 11))
            .foregroundColor(Theme.textTertiary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: Layout.settingsCardMaxWidth, alignment: .leading)
    }

    // MARK: - Refresh

    private func startRefreshTimer() {
        let timer = Timer(timeInterval: 2, repeats: true) { _ in
            Task { @MainActor in
                items = MenubarItemsScanner.scan()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func updateConflictWarning() {
        if let warn = HotkeyManager.systemConflict(for: state.menubarHotkey.asFocusHotkey) {
            conflictWarning = "\(t.focusHotkeyConflict): \(warn)"
        } else {
            conflictWarning = nil
        }
    }
}
