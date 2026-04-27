import SwiftUI

struct SettingsView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState

    /// Счётчик быстрых тапов по «Данные» — 10 кликов в окне 2с разблокируют Diagnostics.
    @State private var dataTapCount: Int = 0
    @State private var dataLastTap: Date = .distantPast

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            content
            Spacer(minLength: 0)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(t.settingsTitle)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text(t.settingsSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            tabPicker
        }
    }

    private var visibleTabs: [SettingsTab] {
        SettingsTab.allCases.filter { tab in
            tab != .diagnostics || state.developerMode
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(visibleTabs) { tab in
                Button {
                    handleTabTap(tab)
                } label: {
                    Text(tab.title(t))
                        .font(.system(size: 11, weight: state.settingsTab == tab ? .semibold : .regular))
                        .foregroundColor(state.settingsTab == tab ? .white : Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(state.settingsTab == tab ? Color.white.opacity(0.10) : Color.clear)
                        )
                        .overlay(
                            Capsule().stroke(
                                state.settingsTab == tab ? Theme.surfaceStroke : Color.clear,
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.03)))
        .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
    }

    private func handleTabTap(_ tab: SettingsTab) {
        state.settingsTab = tab
        guard tab == .data else { return }
        // Easter-egg: 10 быстрых тапов подряд по «Данные» включают режим разработчика.
        // Welcome-баннер про unlock живёт в самой Diagnostics-вкладке, пока юзер
        // его не закроет — без auto-hide таймера.
        let now = Date()
        if now.timeIntervalSince(dataLastTap) > 2.0 {
            dataTapCount = 0
        }
        dataLastTap = now
        dataTapCount += 1
        if dataTapCount >= 10 && !state.developerMode {
            state.developerMode = true
            // Очищаем «уже видел welcome» — на новый unlock баннер появится снова.
            UserDefaults.standard.removeObject(forKey: "helloWorkDevModeWelcomeAck")
            state.settingsTab = .diagnostics
            dataTapCount = 0
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch state.settingsTab {
        case .schedule:    SettingsScheduleTab(state: state)
        case .focus:       SettingsFocusTab(state: state)
        case .tray:        SettingsTrayTab(state: state)
        case .app:         SettingsAppTab(state: state)
        case .data:        SettingsDataTab(state: state)
        case .diagnostics: SettingsDiagnosticsTab(state: state)
        }
    }
}
