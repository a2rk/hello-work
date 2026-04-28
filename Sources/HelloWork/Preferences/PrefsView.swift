import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PrefsView: View {
    @ObservedObject var state: AppState
    // selection теперь живёт в state.prefsSelection — AppDelegate тоже умеет её менять

    /// Pulse-animation для «+» кнопки когда юзер тыкает её повторно
    /// (уже на .onboarding) — даёт визуальный feedback что клик зарегистрирован.
    @State private var createButtonPulse: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: Layout.sidebarWidth)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: Layout.prefsWindow.width, height: Layout.prefsWindow.height)
        .background(BackgroundView())
        .preferredColorScheme(.dark)
        .environment(\.t, state.t)
        .onAppear {
            if state.prefsSelection == nil {
                state.prefsSelection = state.managedApps.first.map { .app($0.bundleID) } ?? .onboarding
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            BrandMark()
                .padding(.horizontal, 12)
                .padding(.top, 24)
                .padding(.bottom, 22)

            createButton

            if combinedScheduleVisible {
                CombinedScheduleSidebarRow(
                    isSelected: state.prefsSelection == .combined
                ) {
                    state.prefsSelection = .combined
                }
            }

            ForEach(state.managedApps) { app in
                AppSidebarRow(
                    app: app,
                    isSelected: state.prefsSelection == .app(app.bundleID),
                    isAllowedNow: state.isAllowed(app: app)
                ) {
                    state.prefsSelection = .app(app.bundleID)
                }
            }

            sidebarDivider

            ForEach(visibleSections) { section in
                SidebarItem(
                    section: section,
                    isSelected: state.prefsSelection == .section(section),
                    showsBadge: section == .updates && state.updateAvailable
                ) {
                    state.prefsSelection = .section(section)
                }
            }

            PermissionsSidebarRow(
                title: state.t.sectionPermissions,
                isSelected: state.prefsSelection == .permissions,
                missing: state.permissions.anyMissing
            ) {
                state.prefsSelection = .permissions
            }

            Spacer()
        }
        .padding(.horizontal, 10)
    }

    private var visibleSections: [PrefSection] {
        PrefSection.allCases.filter { section in
            if section == .updates { return state.updateAvailable }
            return true
        }
    }

    /// Combined schedule item visible if 2+ active (non-archived) apps.
    private var combinedScheduleVisible: Bool {
        state.managedApps.filter { !$0.isArchived }.count >= 2
    }

    private var sidebarDivider: some View {
        Rectangle()
            .fill(Theme.surfaceStroke)
            .frame(height: 1)
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
    }

    private var createButton: some View {
        Button {
            if state.prefsSelection == .onboarding {
                // Уже на onboarding — pulse для подтверждения что клик зашёл.
                createButtonPulse.toggle()
            } else {
                state.prefsSelection = .onboarding
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 16)
                Text(state.t.addApp)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .foregroundColor(state.prefsSelection == .onboarding ? .white : Color.white.opacity(0.78))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(state.prefsSelection == .onboarding ? Color.white.opacity(0.06) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Theme.surfaceStroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(createButtonPulse ? 1.04 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.45), value: createButtonPulse)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !state.corruptionWarnings.isEmpty {
                    corruptionBanners
                        .padding(.bottom, 14)
                }
                content
            }
            .padding(.horizontal, Layout.detailPaddingH)
            .padding(.vertical, Layout.detailPaddingV)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Каждый sidebar-выбор = свой ScrollView identity → SwiftUI создаёт fresh
        // scroll state, контент всегда показывается с верха. Без этого ScrollView
        // переиспользует offset между разными views, что давало неуместные «прыжки».
        .id(scrollIdentity)
    }

    /// Стабильный ключ для .id() ScrollView — отличается между selection'ами.
    private var scrollIdentity: String {
        switch state.prefsSelection {
        case .app(let bid):       return "app:\(bid)"
        case .section(let s):     return "section:\(s.rawValue)"
        case .onboarding:         return "onboarding"
        case .combined:           return "combined"
        case .permissions:        return "permissions"
        case .none:               return "none"
        }
    }

    @ViewBuilder
    private var corruptionBanners: some View {
        VStack(spacing: 8) {
            ForEach(state.corruptionWarnings) { warning in
                let title: String = {
                    switch warning.kind {
                    case .schedules: return state.t.corruptionSchedulesTitle
                    case .stats:     return state.t.corruptionStatsTitle
                    case .legends:   return state.t.corruptionLegendsTitle
                    }
                }()
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.danger)
                        .font(.system(size: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        HStack(spacing: 4) {
                            Text(state.t.corruptionBackupAt)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                            Text(warning.backupPath)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.textTertiary)
                                .textSelection(.enabled)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Spacer()
                    Button {
                        state.dismissCorruption(warning.id)
                    } label: {
                        Text(state.t.corruptionDismiss)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                            .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.danger.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.danger.opacity(0.45), lineWidth: 1)
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.prefsSelection {
        case .app(let bid):
            if bid == Bundle.main.bundleIdentifier {
                NiceTryView()
            } else if let app = state.managedApps.first(where: { $0.bundleID == bid }) {
                ScheduleView(state: state, app: app)
                    .id(bid)
            } else {
                OnboardingView(action: openAppPicker)
            }
        case .combined:
            if combinedScheduleVisible {
                CombinedScheduleView(state: state)
            } else {
                OnboardingView(action: openAppPicker)
            }
        case .permissions:
            PermissionsOnboardingView(state: state) {
                state.prefsSelection = state.managedApps.first.map { .app($0.bundleID) } ?? .onboarding
            }
        case .section(.legends):
            // TASK-L21 заменит на полноценный LegendsListView.
            VStack(alignment: .leading, spacing: 8) {
                Text(state.t.sectionLegends)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text("Coming soon")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
        case .section(.stats):
            StatsView(state: state)
        case .section(.menubar):
            MenubarView(state: state)
        case .section(.updates):
            UpdatesView(state: state)
        case .section(.settings):
            SettingsView(state: state)
        case .section(.contacts):
            ContactsView()
        case .section(.about):
            AboutView()
        case .onboarding, nil:
            OnboardingView(action: openAppPicker)
        }
    }

    private func openAppPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = state.t.pickerMessage
        panel.prompt = state.t.pickerPrompt

        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else { return }

        let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent

        let app = ManagedApp(bundleID: bundleID, name: name, appURL: url, slots: [])
        state.addManagedApp(app)
        state.prefsSelection = .app(bundleID)
    }
}
