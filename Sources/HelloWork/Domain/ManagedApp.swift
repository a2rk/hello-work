import Foundation
import AppKit

struct ManagedApp: Identifiable, Equatable, Codable {
    let bundleID: String
    let name: String
    let appURL: URL
    var slots: [Slot]
    var isArchived: Bool

    var id: String { bundleID }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: appURL.path)
    }

    init(bundleID: String, name: String, appURL: URL, slots: [Slot], isArchived: Bool = false) {
        self.bundleID = bundleID
        self.name = name
        self.appURL = appURL
        self.slots = slots
        self.isArchived = isArchived
    }

    /// Backward-совместимый decoder: если в старом JSON нет поля `isArchived` — кладём false.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try c.decode(String.self, forKey: .bundleID)
        name = try c.decode(String.self, forKey: .name)
        appURL = try c.decode(URL.self, forKey: .appURL)
        slots = try c.decode([Slot].self, forKey: .slots)
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
}
