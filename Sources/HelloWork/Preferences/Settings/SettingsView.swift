import SwiftUI

struct SettingsView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState

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
                Text(headerSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            tabPicker
        }
    }

    /// Подзаголовок — общее «параметры приложения» вместо подсказки про конкретную вкладку,
    /// чтобы переключение не дёргалось.
    private var headerSubtitle: String {
        t.settingsSubtitle
    }

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    state.settingsTab = tab
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

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch state.settingsTab {
        case .schedule: SettingsScheduleTab(state: state)
        case .focus:    SettingsFocusTab(state: state)
        case .app:      SettingsAppTab(state: state)
        case .data:     SettingsDataTab(state: state)
        }
    }
}
