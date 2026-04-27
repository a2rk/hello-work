import AppKit

/// Список приложений, которые скорее всего видны в menubar.
/// Источник — NSWorkspace.runningApplications (публичный API, без permissions).
/// Фильтруем по accessory (LSUIElement = YES) и по наличию иконки.
enum MenubarItemsScanner {
    struct Item: Identifiable, Equatable {
        let id: String          // bundleID
        let pid: pid_t
        let name: String
        let icon: NSImage?

        static func == (lhs: Item, rhs: Item) -> Bool { lhs.id == rhs.id }
    }

    static func scan() -> [Item] {
        let ownBID = Bundle.main.bundleIdentifier
        let apps = NSWorkspace.shared.runningApplications

        var seenBundles = Set<String>()
        var items: [Item] = []

        for app in apps {
            // accessory = LSUIElement YES (типичные menubar apps вроде Slack notification helper).
            // Regular apps типа Discord/Spotify тоже могут иметь menubar items — включаем и их.
            guard app.activationPolicy == .accessory || app.activationPolicy == .regular else {
                continue
            }
            guard let bid = app.bundleIdentifier, bid != ownBID else { continue }
            guard !seenBundles.contains(bid) else { continue }
            guard let icon = app.icon else { continue }
            // Системные демоны без имени отбрасываем.
            guard let name = app.localizedName, !name.isEmpty else { continue }
            // Фильтруем «голые» helper-процессы по bundleID — обычно у них в имени есть Helper / Renderer / GPU.
            let lower = name.lowercased()
            if lower.contains("helper")
                || lower.contains("renderer")
                || lower.contains("gpu process")
                || lower.contains("crashpad") {
                continue
            }

            seenBundles.insert(bid)
            items.append(Item(
                id: bid,
                pid: app.processIdentifier,
                name: name,
                icon: icon
            ))
        }

        items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return items
    }
}
