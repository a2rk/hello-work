import Foundation
import AppKit

struct ManagedApp: Identifiable, Equatable {
    let bundleID: String
    let name: String
    let appURL: URL
    var slots: [Slot]
    var isArchived: Bool = false

    var id: String { bundleID }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: appURL.path)
    }
}
