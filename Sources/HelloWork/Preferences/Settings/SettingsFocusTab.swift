import SwiftUI

struct SettingsFocusTab: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState

    var body: some View {
        SettingsCard.section(title: t.settingsSectionFocus) {
            SettingsCard.card {
                FocusSettingsView(state: state)
            }
        }
    }
}
