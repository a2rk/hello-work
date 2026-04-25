import SwiftUI

private struct TranslationKey: EnvironmentKey {
    static let defaultValue: Translation = .en
}

extension EnvironmentValues {
    var t: Translation {
        get { self[TranslationKey.self] }
        set { self[TranslationKey.self] = newValue }
    }
}
