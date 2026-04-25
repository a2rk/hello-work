import Foundation
import Combine
import ServiceManagement

final class AppState: ObservableObject {
    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: Self.enabledKey) }
    }
    @Published var managedApps: [ManagedApp] {
        didSet { saveManagedApps() }
    }
    @Published var devLogEntries: [UpdateInfo] = []
    @Published var isCheckingUpdates: Bool = false
    @Published var lastUpdateCheck: Date?
    @Published var lastUpdateCheckError: String?

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey) }
    }
    @Published var autoUpdate: Bool {
        didSet { UserDefaults.standard.set(autoUpdate, forKey: Self.autoUpdateKey) }
    }
    @Published var snapStep: Int {
        didSet { UserDefaults.standard.set(snapStep, forKey: Self.snapStepKey) }
    }
    @Published var enabledGracePresets: Set<Int> {
        didSet { UserDefaults.standard.set(Array(enabledGracePresets), forKey: Self.gracePresetsKey) }
    }
    @Published var customGraceMinutes: [Int] {
        didSet { UserDefaults.standard.set(customGraceMinutes, forKey: Self.graceCustomsKey) }
    }
    @Published private(set) var launchAtLogin: Bool

    private(set) var graceUntil: Date?

    private static let languageKey = "helloWorkLanguage"
    private static let autoUpdateKey = "helloWorkAutoUpdate"
    private static let snapStepKey = "helloWorkSnapStep"
    private static let gracePresetsKey = "helloWorkGracePresets"
    private static let graceCustomsKey = "helloWorkGraceCustoms"
    private static let enabledKey = "helloWorkEnabled"
    private static let managedAppsKey = "helloWorkManagedApps"

    static let gracePresetSeconds: [Int] = [30, 60, 180, 300, 600]
    static let snapStepOptions: [Int] = [1, 5, 10, 15]

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.languageKey),
           let parsed = AppLanguage(rawValue: raw) {
            self.language = parsed
        } else {
            self.language = .system
        }

        self.autoUpdate = UserDefaults.standard.bool(forKey: Self.autoUpdateKey)

        let s = UserDefaults.standard.integer(forKey: Self.snapStepKey)
        self.snapStep = (s == 0 ? 5 : s)

        if let raw = UserDefaults.standard.array(forKey: Self.gracePresetsKey) as? [Int] {
            self.enabledGracePresets = Set(raw)
        } else {
            self.enabledGracePresets = [60]
        }

        self.customGraceMinutes = (UserDefaults.standard.array(forKey: Self.graceCustomsKey) as? [Int]) ?? []
        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)

        // enabled: дефолт true, если ключа нет
        self.enabled = (UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool) ?? true

        // managedApps: десериализуем JSON из UserDefaults; пустой массив, если ничего нет / битое
        if let data = UserDefaults.standard.data(forKey: Self.managedAppsKey),
           let apps = try? JSONDecoder().decode([ManagedApp].self, from: data) {
            self.managedApps = apps
        } else {
            self.managedApps = []
        }
    }

    private func saveManagedApps() {
        guard let data = try? JSONEncoder().encode(managedApps) else { return }
        UserDefaults.standard.set(data, forKey: Self.managedAppsKey)
    }

    var t: Translation { L10n.resolved(language) }

    var latestRemoteVersion: String? { devLogEntries.first?.version }

    var updateAvailable: Bool {
        guard let latest = latestRemoteVersion else { return false }
        return AppVersion.compare(latest, AppVersion.marketing) == .orderedDescending
    }

    /// Объединённый список длительностей грейса в секундах (пресеты + кастомные), отсортированный.
    var allGraceSeconds: [Int] {
        let customSecs = customGraceMinutes.map { $0 * 60 }
        return Array(enabledGracePresets.union(customSecs)).sorted()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Ничего не делаем — состояние перечитаем ниже из системы.
        }
        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
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
        let step = snapStep
        let length = ((hi - lo) / step) * step
        guard length >= step else { return }

        if length >= minutesInDay {
            managedApps[idx].slots = [Slot(id: UUID(), startMinutes: 0, endMinutes: minutesInDay)]
            return
        }

        var s = lo
        while s < 0 { s += minutesInDay }
        while s >= minutesInDay { s -= minutesInDay }
        s = (s / step) * step
        let e = s + length

        let candidate = Slot(id: UUID(), startMinutes: s, endMinutes: e)

        var unionSet = minuteSet(of: candidate)
        var keep: [Slot] = []
        for slot in managedApps[idx].slots {
            let sset = minuteSet(of: slot)
            if !sset.isDisjoint(with: unionSet) {
                unionSet.formUnion(sset)
            } else {
                keep.append(slot)
            }
        }
        let merged = slotsFromMinuteSet(unionSet)
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

    private func minuteSet(of slot: Slot) -> Set<Int> {
        var set = Set<Int>()
        let step = snapStep
        let segments: [(Int, Int)]
        if slot.endMinutes <= minutesInDay {
            segments = [(slot.startMinutes, slot.endMinutes)]
        } else {
            segments = [(slot.startMinutes, minutesInDay), (0, slot.endMinutes - minutesInDay)]
        }
        for (a, b) in segments {
            var m = a
            while m < b { set.insert(m); m += step }
        }
        return set
    }

    private func slotsFromMinuteSet(_ set: Set<Int>) -> [Slot] {
        if set.isEmpty { return [] }
        let step = snapStep
        if set.count * step >= minutesInDay {
            return [Slot(id: UUID(), startMinutes: 0, endMinutes: minutesInDay)]
        }
        let sorted = set.sorted()
        var runs: [(Int, Int)] = []
        var cs = sorted[0]
        var ce = sorted[0] + step
        for i in 1..<sorted.count {
            if sorted[i] == ce {
                ce = sorted[i] + step
            } else {
                runs.append((cs, ce))
                cs = sorted[i]
                ce = sorted[i] + step
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
