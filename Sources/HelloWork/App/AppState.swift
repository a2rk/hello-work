import Foundation
import Combine
import ServiceManagement

@MainActor
final class AppState: ObservableObject {
    let installer = UpdateInstaller()
    let stats = StatsCollector()
    let focus = FocusModeController()
    let menubarHider = MenubarHiderController()
    let permissions = PermissionsManager()
    @Published var prefsSelection: SidebarSelection?
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
    @Published var patternOverlay: Bool {
        didSet { UserDefaults.standard.set(patternOverlay, forKey: Self.patternOverlayKey) }
    }
    @Published var focusModeEnabled: Bool {
        didSet { UserDefaults.standard.set(focusModeEnabled, forKey: Self.focusModeEnabledKey) }
    }
    @Published var focusHotkey: FocusHotkey {
        didSet { UserDefaults.standard.set(focusHotkey.serialized, forKey: Self.focusHotkeyKey) }
    }
    @Published var focusDimOpacity: Double {
        didSet {
            // Визуальный апдейт сразу — пользователь видит overlay в реалтайме.
            focus.updateDimOpacity(focusDimOpacity)
            // Persist debounced — drag слайдера не должен дёргать cfprefsd
            // на каждый шаг.
            scheduleFocusDimOpacityPersist()
        }
    }
    @Published var focusUseAccessibility: Bool {
        didSet {
            UserDefaults.standard.set(focusUseAccessibility, forKey: Self.focusAXKey)
            focus.useAccessibility = focusUseAccessibility
        }
    }
    @Published var settingsTab: SettingsTab {
        didSet { UserDefaults.standard.set(settingsTab.rawValue, forKey: Self.settingsTabKey) }
    }
    @Published var menubarHiderEnabled: Bool {
        didSet { UserDefaults.standard.set(menubarHiderEnabled, forKey: Self.menubarHiderEnabledKey) }
    }
    @Published var menubarHotkey: MenubarHotkey {
        didSet { UserDefaults.standard.set(menubarHotkey.serialized, forKey: Self.menubarHotkeyKey) }
    }
    @Published var menubarHideOnFocus: Bool {
        didSet { UserDefaults.standard.set(menubarHideOnFocus, forKey: Self.menubarHideOnFocusKey) }
    }
    @Published var menubarHideOnSchedule: Bool {
        didSet { UserDefaults.standard.set(menubarHideOnSchedule, forKey: Self.menubarHideOnScheduleKey) }
    }
    @Published var menubarPersistCollapsed: Bool {
        didSet { UserDefaults.standard.set(menubarPersistCollapsed, forKey: Self.menubarPersistKey) }
    }
    @Published var showStatusBarIcon: Bool {
        didSet { UserDefaults.standard.set(showStatusBarIcon, forKey: Self.showStatusBarIconKey) }
    }
    @Published var showGraceCountdownInBar: Bool {
        didSet { UserDefaults.standard.set(showGraceCountdownInBar, forKey: Self.graceCountdownKey) }
    }
    @Published var statusIconStyle: StatusIconStyle {
        didSet { UserDefaults.standard.set(statusIconStyle.rawValue, forKey: Self.statusIconStyleKey) }
    }
    @Published var menubarPeekSeconds: Int {
        didSet { UserDefaults.standard.set(menubarPeekSeconds, forKey: Self.menubarPeekKey) }
    }
    @Published var developerMode: Bool {
        didSet {
            UserDefaults.standard.set(developerMode, forKey: Self.developerModeKey)
            DevLogger.shared.enabled = developerMode
        }
    }
    @Published private(set) var launchAtLogin: Bool

    // MARK: - Legends module persisted state

    /// Избранные легенды — `legend.id` set'ом. Persists через did-Set.
    @Published var favoriteLegendIds: Set<String> = [] {
        didSet { saveLegendsState() }
    }

    /// ID легенды чьё расписание сейчас «применено» к managed apps.
    /// nil = ничего не применено. Меняется только через LegendApplyEngine.
    @Published private(set) var appliedLegendId: String? {
        didSet { saveLegendsState() }
    }

    /// Snapshot `managedApps[i].slots` перед apply, по bundleID.
    /// nil = backup ещё не делали (значит revert невозможен — нечего откатывать).
    /// Изменяется только через LegendApplyEngine.
    private(set) var slotsBackupForApply: [String: [Slot]]? {
        didSet { saveLegendsState() }
    }

    /// User-visible warnings о восстановлении после повреждения данных
    /// (managedApps JSON / stats.json). Каждая запись = одна категория, путь
    /// к резервной копии. UI показывает их баннером в Prefs до dismiss.
    @Published var corruptionWarnings: [CorruptionWarning] = []

    /// True один раз после успешной миграции (TASK-A01/A03). UI показывает
    /// one-time toast «HelloWork moved to /Applications», после dismiss
    /// сбрасывается в false (в памяти; не возвращается).
    @Published var queueMigrationToast: Bool = false

    struct CorruptionWarning: Identifiable, Equatable {
        let id = UUID()
        /// `.schedules` / `.stats` — определяет message в UI.
        let kind: Kind
        let backupPath: String

        enum Kind: String { case schedules, stats, legends }
    }

    private(set) var graceUntil: Date?

    private static let languageKey = "helloWorkLanguage"
    private static let autoUpdateKey = "helloWorkAutoUpdate"
    private static let snapStepKey = "helloWorkSnapStep"
    private static let gracePresetsKey = "helloWorkGracePresets"
    private static let graceCustomsKey = "helloWorkGraceCustoms"
    private static let enabledKey = "helloWorkEnabled"
    private static let managedAppsKey = "helloWorkManagedApps"
    private static let patternOverlayKey = "helloWorkPatternOverlay"
    private static let focusModeEnabledKey = "helloWorkFocusModeEnabled"
    private static let focusHotkeyKey = "helloWorkFocusHotkey"
    private static let focusOpacityKey = "helloWorkFocusOpacity"
    private static let focusAXKey = "helloWorkFocusUseAX"
    private static let settingsTabKey = "helloWorkSettingsTab"
    private static let menubarHiderEnabledKey = "helloWorkMenubarHiderEnabled"
    private static let menubarHotkeyKey = "helloWorkMenubarHotkey"
    private static let menubarHideOnFocusKey = "helloWorkMenubarHideOnFocus"
    private static let menubarHideOnScheduleKey = "helloWorkMenubarHideOnSchedule"
    private static let menubarPersistKey = "helloWorkMenubarPersistCollapsed"
    private static let menubarLastCollapsedKey = "helloWorkMenubarLastCollapsed"
    private static let showStatusBarIconKey = "helloWorkShowStatusBarIcon"
    private static let graceCountdownKey = "helloWorkGraceCountdownInBar"
    private static let statusIconStyleKey = "helloWorkStatusIconStyle"
    private static let menubarPeekKey = "helloWorkMenubarPeekSeconds"
    private static let developerModeKey = "helloWorkDeveloperMode"

    /// Текущая версия persisted JSON для managedApps. При изменении схемы —
    /// инкрементировать и добавить миграцию в loadManagedApps().
    private static let managedAppsSchemaVersion = 1

    /// Wrapper для persistence: позволяет в будущем мигрировать схему
    /// без потери данных или confused-state'а.
    private struct VersionedManagedApps: Codable {
        let version: Int
        let apps: [ManagedApp]
    }

    private static let legendsStateKey = "helloWorkLegendsState"
    private static let legendsStateSchemaVersion = 1

    /// Persisted snapshot всех legends-related @Published полей.
    /// Один blob — один write, чтобы избежать пушей цепочкой при apply.
    private struct VersionedLegendsState: Codable {
        let version: Int
        let favoriteIds: [String]
        let appliedLegendId: String?
        let slotsBackup: [String: [Slot]]?
    }

    static let menubarPeekOptions: [Int] = [0, 1, 2, 3, 5]

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
        self.patternOverlay = (UserDefaults.standard.object(forKey: Self.patternOverlayKey) as? Bool) ?? true
        self.focusModeEnabled = (UserDefaults.standard.object(forKey: Self.focusModeEnabledKey) as? Bool) ?? true
        if let raw = UserDefaults.standard.string(forKey: Self.focusHotkeyKey),
           let parsed = FocusHotkey.deserialize(raw) {
            self.focusHotkey = parsed
        } else {
            self.focusHotkey = .default
        }
        self.focusDimOpacity = (UserDefaults.standard.object(forKey: Self.focusOpacityKey) as? Double) ?? 0.9
        self.focusUseAccessibility = UserDefaults.standard.bool(forKey: Self.focusAXKey)
        if let raw = UserDefaults.standard.string(forKey: Self.settingsTabKey),
           let parsed = SettingsTab(rawValue: raw) {
            self.settingsTab = parsed
        } else {
            self.settingsTab = .schedule
        }

        self.menubarHiderEnabled = (UserDefaults.standard.object(forKey: Self.menubarHiderEnabledKey) as? Bool) ?? false
        if let raw = UserDefaults.standard.string(forKey: Self.menubarHotkeyKey),
           let parsed = MenubarHotkey.deserialize(raw) {
            self.menubarHotkey = parsed
        } else {
            self.menubarHotkey = .default
        }
        self.menubarHideOnFocus = (UserDefaults.standard.object(forKey: Self.menubarHideOnFocusKey) as? Bool) ?? true
        self.menubarHideOnSchedule = UserDefaults.standard.bool(forKey: Self.menubarHideOnScheduleKey)
        self.menubarPersistCollapsed = (UserDefaults.standard.object(forKey: Self.menubarPersistKey) as? Bool) ?? true

        self.showStatusBarIcon = (UserDefaults.standard.object(forKey: Self.showStatusBarIconKey) as? Bool) ?? true
        self.showGraceCountdownInBar = (UserDefaults.standard.object(forKey: Self.graceCountdownKey) as? Bool) ?? true
        if let raw = UserDefaults.standard.string(forKey: Self.statusIconStyleKey),
           let parsed = StatusIconStyle(rawValue: raw) {
            self.statusIconStyle = parsed
        } else {
            self.statusIconStyle = .solid
        }
        self.menubarPeekSeconds = (UserDefaults.standard.object(forKey: Self.menubarPeekKey) as? Int) ?? 0

        let dev = UserDefaults.standard.bool(forKey: Self.developerModeKey)
        self.developerMode = dev
        DevLogger.shared.enabled = dev

        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)

        // enabled: дефолт true, если ключа нет
        self.enabled = (UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool) ?? true

        // managedApps: пробуем decode versioned-wrapper, затем fallback на старый
        // плоский формат [ManagedApp] (он перезапишется новым на следующем save).
        // Если ничего не съелось — backup + warning, чтобы юзер не «потерял» данные тихо.
        var initialWarnings: [CorruptionWarning] = []
        if let data = UserDefaults.standard.data(forKey: Self.managedAppsKey) {
            if let v = try? JSONDecoder().decode(VersionedManagedApps.self, from: data) {
                if v.version <= Self.managedAppsSchemaVersion {
                    self.managedApps = v.apps
                } else {
                    // Будущая версия — даунгрейд приложения. Не пытаемся понять,
                    // backup и пустой state.
                    self.managedApps = []
                    if let backupPath = Self.backupCorruptManagedApps(data) {
                        initialWarnings.append(CorruptionWarning(kind: .schedules, backupPath: backupPath))
                    }
                }
            } else if let legacyApps = try? JSONDecoder().decode([ManagedApp].self, from: data) {
                // Старый плоский формат — миграция при первом save.
                self.managedApps = legacyApps
            } else {
                self.managedApps = []
                if let backupPath = Self.backupCorruptManagedApps(data) {
                    initialWarnings.append(CorruptionWarning(kind: .schedules, backupPath: backupPath))
                }
            }
        } else {
            self.managedApps = []
        }
        if let statsBackup = stats.lastCorruptionBackupPath {
            initialWarnings.append(CorruptionWarning(kind: .stats, backupPath: statsBackup))
        }

        // Legends state — persisted blob. При decode failure пишем backup,
        // чтобы юзер не «потерял» избранное и applied-state молча.
        if let data = UserDefaults.standard.data(forKey: Self.legendsStateKey) {
            if let decoded = try? JSONDecoder().decode(VersionedLegendsState.self, from: data),
               decoded.version <= Self.legendsStateSchemaVersion {
                self.favoriteLegendIds = Set(decoded.favoriteIds)
                self.appliedLegendId = decoded.appliedLegendId
                self.slotsBackupForApply = decoded.slotsBackup
            } else {
                // Decode failed (битый blob или future-version). Backup + warning.
                if let backupPath = Self.backupCorruptLegendsState(data) {
                    initialWarnings.append(CorruptionWarning(kind: .legends, backupPath: backupPath))
                }
            }
        }

        self.corruptionWarnings = initialWarnings

        // Сразу прокидываем настройки в controller.
        focus.dimOpacity = focusDimOpacity
        focus.useAccessibility = focusUseAccessibility
        focus.stats = stats
    }

    /// Сохраняет битый JSON managedApps в `~/Library/Application Support/HelloWork/managedApps.corrupt-<ts>.json`
    /// и возвращает путь, чтобы UI мог его показать. nil если не удалось записать.
    private static func backupCorruptManagedApps(_ data: Data) -> String? {
        backupBlob(data, prefix: "managedApps")
    }

    /// Аналогично managedApps — для legends-state (favorites + applied + backup).
    private static func backupCorruptLegendsState(_ data: Data) -> String? {
        backupBlob(data, prefix: "legends-state")
    }

    private static func backupBlob(_ data: Data, prefix: String) -> String? {
        guard let base = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        let dir = base.appendingPathComponent("HelloWork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(prefix).corrupt-\(Int(Date().timeIntervalSince1970)).json")
        do {
            try data.write(to: url)
            return url.path
        } catch {
            return nil
        }
    }

    func dismissCorruption(_ id: UUID) {
        corruptionWarnings.removeAll { $0.id == id }
    }

    private var focusDimOpacityPersistWork: DispatchWorkItem?

    private func scheduleFocusDimOpacityPersist() {
        focusDimOpacityPersistWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            UserDefaults.standard.set(self.focusDimOpacity, forKey: Self.focusOpacityKey)
        }
        focusDimOpacityPersistWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func saveManagedApps() {
        let wrapped = VersionedManagedApps(
            version: Self.managedAppsSchemaVersion,
            apps: managedApps
        )
        guard let data = try? JSONEncoder().encode(wrapped) else { return }
        UserDefaults.standard.set(data, forKey: Self.managedAppsKey)
    }

    /// Single-blob persist всех legends-полей. Вызывается из didSet каждого
    /// из трёх @Published. Дёшево (≤ kB), но избегаем 3 disk writes на одно apply.
    private func saveLegendsState() {
        let wrapped = VersionedLegendsState(
            version: Self.legendsStateSchemaVersion,
            favoriteIds: Array(favoriteLegendIds).sorted(),
            appliedLegendId: appliedLegendId,
            slotsBackup: slotsBackupForApply
        )
        guard let data = try? JSONEncoder().encode(wrapped) else { return }
        UserDefaults.standard.set(data, forKey: Self.legendsStateKey)
    }

    /// Изменяет appliedLegendId + slotsBackup атомарно (один disk write).
    /// Используется LegendApplyEngine; обходит didSet'ы каждого поля.
    func _setLegendsApply(legendId: String?, backup: [String: [Slot]]?) {
        appliedLegendId = legendId
        slotsBackupForApply = backup
    }

    // MARK: - Legends helpers

    /// Идемпотентный toggle favorite. Если был — убираем, иначе — добавляем.
    func toggleFavoriteLegend(_ id: String) {
        if favoriteLegendIds.contains(id) {
            favoriteLegendIds.remove(id)
        } else {
            favoriteLegendIds.insert(id)
        }
    }

    func isFavoriteLegend(_ id: String) -> Bool {
        favoriteLegendIds.contains(id)
    }

    var t: Translation { L10n.resolved(language) }

    // MARK: - Menubar persistence helpers

    /// Сохранить текущее состояние menubar hider на диск (для restore при следующем запуске).
    func saveMenubarCollapsed(_ collapsed: Bool) {
        UserDefaults.standard.set(collapsed, forKey: Self.menubarLastCollapsedKey)
    }

    /// Прочитать сохранённое состояние menubar hider. Default — true (свёрнут).
    var menubarRestoredCollapsed: Bool {
        (UserDefaults.standard.object(forKey: Self.menubarLastCollapsedKey) as? Bool) ?? true
    }

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
    /// Минимальная пауза между fetch'ами dev_log.json (если successFul-fetch < 5 min ago,
    /// повторный вызов skip'нем). Защищает от cascade'ов при open-prefs / refresh-tick.
    private static let updateCheckThrottle: TimeInterval = 300

    func checkForUpdates(force: Bool = false) async {
        // Параллельный вызов уже идёт — не дёргаем второй раз.
        if isCheckingUpdates { return }
        // Свежий успешный fetch — пропускаем (если не force).
        if !force, let last = lastUpdateCheck, lastUpdateCheckError == nil,
           Date().timeIntervalSince(last) < Self.updateCheckThrottle {
            return
        }

        isCheckingUpdates = true
        defer { isCheckingUpdates = false }

        // Cache-busting: уникальный URL = CDN/proxy не может отдать старое.
        var components = URLComponents(url: DevLogConfig.url, resolvingAgainstBaseURL: false)
            ?? URLComponents()
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "_", value: "\(Int(Date().timeIntervalSince1970))"))
        components.queryItems = items
        let url = components.url ?? DevLogConfig.url

        // Ephemeral session — никакого URLCache, никаких cookies.
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: config)
        // После завершения — освобождаем connection pool / queues.
        defer { session.finishTasksAndInvalidate() }

        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        req.setValue("no-cache", forHTTPHeaderField: "Pragma")

        do {
            let (data, _) = try await session.data(for: req)
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
        stats.recordGrace(seconds: Int(seconds))
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
        // Защита от malformed slot'ов (например из corrupted JSON): clamp в
        // допустимый диапазон. Внутри валидного state'а это no-op.
        let s = max(0, min(minutesInDay - 1, slot.startMinutes))
        let e = max(s, min(2 * minutesInDay, slot.endMinutes))
        let segments: [(Int, Int)]
        if e <= minutesInDay {
            segments = [(s, e)]
        } else {
            segments = [(s, minutesInDay), (0, e - minutesInDay)]
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
