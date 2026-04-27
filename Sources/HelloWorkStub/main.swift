import AppKit
import SwiftUI

@MainActor
func bootstrap() {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)

    let delegate = StubAppDelegate()
    app.delegate = delegate
    app.run()
}

MainActor.assumeIsolated {
    bootstrap()
}
