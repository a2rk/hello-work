import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PrefsView: View {
    @ObservedObject var state: AppState
    // selection теперь живёт в state.prefsSelection — AppDelegate тоже умеет её менять

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

    private var sidebarDivider: some View {
        Rectangle()
            .fill(Theme.surfaceStroke)
            .frame(height: 1)
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
    }

    private var createButton: some View {
        Button {
            state.prefsSelection = .onboarding
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
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, Layout.detailPaddingH)
            .padding(.vertical, Layout.detailPaddingV)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.prefsSelection {
        case .app(let bid):
            if state.managedApps.contains(where: { $0.bundleID == bid }) {
                ScheduleView(state: state, bundleID: bid)
                    .id(bid)
            } else {
                OnboardingView(action: openAppPicker)
            }
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
