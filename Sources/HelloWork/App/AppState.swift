import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var enabled: Bool = true
    @Published var managedApps: [ManagedApp] = []
    @Published var devLogEntries: [UpdateInfo] = []
    @Published var isCheckingUpdates: Bool = false
    @Published var lastUpdateCheck: Date?
    @Published var lastUpdateCheckError: String?
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey) }
    }
    private(set) var graceUntil: Date?

    private static let languageKey = "helloWorkLanguage"

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.languageKey),
           let parsed = AppLanguage(rawValue: raw) {
            self.language = parsed
        } else {
            self.language = .system
        }
    }

    /// Текущий резолвнутый словарь. Используется и в SwiftUI (через .environment(\.t)),
    /// и в AppDelegate напрямую для menubar-строк.
    var t: Translation { L10n.resolved(language) }

    var latestRemoteVersion: String? { devLogEntries.first?.version }

    var updateAvailable: Bool {
        guard let latest = latestRemoteVersion else { return false }
        return AppVersion.compare(latest, AppVersion.marketing) == .orderedDescending
    }

    @MainActor
    func checkForUpdates() async {
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }

        do {
            var req = URLRequest(url: DevLogConfig.url)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, _) = try await URLSession.shared.data(for: req)
            let entries = try JSONDecoder().decode([UpdateInfo].self, from: data)
            self.devLogEntries = entries.sorted {
                AppVersion.compare($0.version, $1.version) == .orderedDescending
            }
            self.lastUpdateCheck = Date()
            self.lastUpdateCheckError = nil
        } catch {
            self.lastUpdateCheck = Date()
            self.lastUpdateCheckError = error.localizedDescription
        }
    }

    var graceRemaining: TimeInterval? {
        guard let g = graceUntil else { return nil }
        let r = g.timeIntervalSinceNow
        return r > 0 ? r : nil
    }

    func grantGrace(seconds: TimeInterval) {
        graceUntil = Date().addingTimeInterval(seconds)
    }

    func recompute(now: Date = Date()) {
        if let g = graceUntil, now >= g {
            graceUntil = nil
        }
    }

    func isAllowed(app: ManagedApp, now: Date = Date()) -> Bool {
        if let g = graceUntil, now < g { return true }
        let cal = Calendar.current
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        let cur = h * 60 + m
        return app.slots.contains { $0.contains(minute: cur) }
    }

    // MARK: - Managed apps

    func addManagedApp(_ app: ManagedApp) {
        if let idx = managedApps.firstIndex(where: { $0.bundleID == app.bundleID }) {
            managedApps[idx].isArchived = false
            return
        }
        managedApps.append(app)
    }

    func removeManagedApp(bundleID: String) {
        managedApps.removeAll { $0.bundleID == bundleID }
    }

    func archiveApp(bundleID: String) {
        if let idx = managedApps.firstIndex(where: { $0.bundleID == bundleID }) {
            managedApps[idx].isArchived = true
        }
    }

    func unarchiveApp(bundleID: String) {
        if let idx = managedApps.firstIndex(where: { $0.bundleID == bundleID }) {
            managedApps[idx].isArchived = false
        }
    }

    // MARK: - Slots

    func addSlot(toApp bundleID: String, start: Int, end: Int) {
        guard let idx = managedApps.firstIndex(where: { $0.bundleID == bundleID }) else { return }

        let lo = min(start, end)
        let hi = max(start, end)
        let length = ((hi - lo) / snapMinutes) * snapMinutes
        guard length >= snapMinutes else { return }

        if length >= minutesInDay {
            managedApps[idx].slots = [Slot(id: UUID(), startMinutes: 0, endMinutes: minutesInDay)]
            return
        }

        var s = lo
        while s < 0 { s += minutesInDay }
        while s >= minutesInDay { s -= minutesInDay }
        s = (s / snapMinutes) * snapMinutes
        let e = s + length

        let candidate = Slot(id: UUID(), startMinutes: s, endMinutes: e)

        var unionSet = Self.minuteSet(of: candidate)
        var keep: [Slot] = []
        for slot in managedApps[idx].slots {
            let sset = Self.minuteSet(of: slot)
            if !sset.isDisjoint(with: unionSet) {
                unionSet.formUnion(sset)
            } else {
                keep.append(slot)
            }
        }
        let merged = Self.slotsFromMinuteSet(unionSet)
        managedApps[idx].slots = (keep + merged).sorted { $0.startMinutes < $1.startMinutes }
    }

    func removeSlot(fromApp bundleID: String, id: UUID) {
        guard let idx = managedApps.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        managedApps[idx].slots.removeAll { $0.id == id }
    }

    func clearSlots(forApp bundleID: String) {
        guard let idx = managedApps.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        managedApps[idx].slots = []
    }

    func finalizeResize(appBundleID: String, slotID: UUID) {
        guard let appIdx = managedApps.firstIndex(where: { $0.bundleID == appBundleID }),
              let slotIdx = managedApps[appIdx].slots.firstIndex(where: { $0.id == slotID })
        else { return }
        let s = managedApps[appIdx].slots[slotIdx]
        managedApps[appIdx].slots.remove(at: slotIdx)
        addSlot(toApp: appBundleID, start: s.startMinutes, end: s.endMinutes)
    }

    // MARK: - Helpers

    private static func minuteSet(of slot: Slot) -> Set<Int> {
        var set = Set<Int>()
        let segments: [(Int, Int)]
        if slot.endMinutes <= minutesInDay {
            segments = [(slot.startMinutes, slot.endMinutes)]
        } else {
            segments = [(slot.startMinutes, minutesInDay), (0, slot.endMinutes - minutesInDay)]
        }
        for (a, b) in segments {
            var m = a
            while m < b { set.insert(m); m += snapMinutes }
        }
        return set
    }

    private static func slotsFromMinuteSet(_ set: Set<Int>) -> [Slot] {
        if set.isEmpty { return [] }
        if set.count * snapMinutes >= minutesInDay {
            return [Slot(id: UUID(), startMinutes: 0, endMinutes: minutesInDay)]
        }
        let sorted = set.sorted()
        var runs: [(Int, Int)] = []
        var cs = sorted[0]
        var ce = sorted[0] + snapMinutes
        for i in 1..<sorted.count {
            if sorted[i] == ce {
                ce = sorted[i] + snapMinutes
            } else {
                runs.append((cs, ce))
                cs = sorted[i]
                ce = sorted[i] + snapMinutes
            }
        }
        runs.append((cs, ce))

        if runs.count >= 2,
           runs.first!.0 == 0,
           runs.last!.1 == minutesInDay {
            let first = runs.removeFirst()
            let last = runs.removeLast()
            runs.append((last.0, first.1 + minutesInDay))
        }

        return runs.map { Slot(id: UUID(), startMinutes: $0.0, endMinutes: $0.1) }
    }
}
