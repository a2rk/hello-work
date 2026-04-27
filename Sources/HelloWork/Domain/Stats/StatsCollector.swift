import Foundation
import Combine

/// Owns StatsStore: принимает события из overlay'а, ведёт state machine peek-сессий,
/// флашит на диск раз в N секунд. Файл `stats.json` в Application Support.
@MainActor
final class StatsCollector: ObservableObject {
    @Published private(set) var store: StatsStore = StatsStore()

    /// Если при `load()` файл оказался битым — сюда кладётся путь к резервной
    /// копии. AppState читает это после init и поднимает баннер в UI.
    private(set) var lastCorruptionBackupPath: String?

    private var dirty = false
    private var flushTimer: Timer?
    private var sessions: [String: SessionState] = [:]   // bundleID → state

    private struct SessionState {
        var lastTouchedAt: Date
        var registered: Bool   // peek уже зафиксирован в этот заход?
    }

    /// Сессия закрывается через 30с без событий или при смене frontmost.
    private static let sessionIdleTimeout: TimeInterval = 30

    /// Скролл-жест склеивается из wheel-events с gap ≤ 0.5с.
    private static let scrollDebounce: TimeInterval = 0.5

    /// Раз в сколько секунд флашим изменения на диск.
    private static let flushInterval: TimeInterval = 5

    init() {
        load()
        startFlushTimer()
    }

    deinit {
        flushTimer?.invalidate()
    }

    // MARK: - Recording

    /// Ловим event из FixedWindow.sendEvent.
    func record(event: StatEvent, bundleID: String, at date: Date = Date()) {
        let key = StatsStore.dayKey(date)
        var day = store.days[key] ?? [:]
        var stat = day[bundleID] ?? DailyStat()

        switch event {
        case .tap:
            stat.taps += 1
        case .secondaryTap:
            stat.secondaryTaps += 1
        case .scrollSwipe:
            stat.scrollSwipes += 1
        case .keystroke:
            stat.keystrokes += 1
        }

        let hour = Calendar.current.component(.hour, from: date)
        if (0..<24).contains(hour) {
            stat.hourlyAttempts[hour] += 1
        }

        // Peek: если ещё не зарегистрирован — открываем сессию.
        var session = sessions[bundleID] ?? SessionState(lastTouchedAt: date, registered: false)
        session.lastTouchedAt = date
        if !session.registered {
            stat.peeks += 1
            session.registered = true
        }
        sessions[bundleID] = session

        day[bundleID] = stat
        store.days[key] = day
        dirty = true
    }

    /// +tickSeconds к blockedSeconds для bundleID. Вызывается из refresh().
    func tickBlocked(bundleID: String, seconds: Double, at date: Date = Date()) {
        let key = StatsStore.dayKey(date)
        var day = store.days[key] ?? [:]
        var stat = day[bundleID] ?? DailyStat()
        stat.blockedSeconds += seconds
        day[bundleID] = stat
        store.days[key] = day
        dirty = true

        // Sweep: закрываем idle-сессии (любого bundleID — не только текущего).
        sweepSessions(now: date)
    }

    /// Принудительно закрыть все сессии (например при отключении глобального тумблера).
    func closeAllSessions() {
        sessions.removeAll()
    }

    /// Регистрация использования "ещё минутку".
    /// Guard на положительное значение — иначе можно засрать stats отрицательными
    /// или нулевыми grace'ами при программной ошибке у caller'а.
    func recordGrace(seconds: Int, at date: Date = Date()) {
        guard seconds > 0 else { return }
        let key = StatsStore.dayKey(date)
        var day = store.days[key] ?? [:]
        // Записываем в специальный псевдо-bundleID, не привязано к конкретному app.
        var stat = day[Self.graceBundleID] ?? DailyStat()
        stat.graceUsedCount += 1
        stat.graceUsedSeconds += seconds
        day[Self.graceBundleID] = stat
        store.days[key] = day
        dirty = true
    }

    static let graceBundleID = "__grace__"
    static let focusTotalBundleID = "__focus_total__"

    // MARK: - Focus mode

    /// +seconds к focusSeconds на бандл (если задан) и к total + hourly бакету.
    /// Вызывается из FocusModeController.tick раз в 250мс.
    func tickFocus(bundleID: String?, seconds: Double, at date: Date = Date()) {
        let key = StatsStore.dayKey(date)
        var day = store.days[key] ?? [:]

        // Per-app focus seconds.
        if let bid = bundleID, !bid.isEmpty, bid != Self.focusTotalBundleID {
            var stat = day[bid] ?? DailyStat()
            stat.focusSeconds += seconds
            day[bid] = stat
        }

        // Total + hourly.
        var total = day[Self.focusTotalBundleID] ?? DailyStat()
        total.focusSeconds += seconds
        let hour = Calendar.current.component(.hour, from: date)
        if (0..<24).contains(hour) {
            total.focusHourly[hour] += seconds
        }
        day[Self.focusTotalBundleID] = total

        store.days[key] = day
        dirty = true
    }

    /// Финал focus-сессии: ++count, обновляем longest.
    func recordFocusSessionEnd(seconds: Double, at date: Date = Date()) {
        guard seconds > 0 else { return }
        let key = StatsStore.dayKey(date)
        var day = store.days[key] ?? [:]
        var total = day[Self.focusTotalBundleID] ?? DailyStat()
        total.focusSessions += 1
        if seconds > total.focusLongestSeconds {
            total.focusLongestSeconds = seconds
        }
        day[Self.focusTotalBundleID] = total
        store.days[key] = day
        dirty = true
    }

    /// Сбросить всю статистику. Вызывается из Settings.
    func resetAll() {
        store = StatsStore()
        sessions.removeAll()
        dirty = true
        flushNow()
    }

    // MARK: - Scroll debounce (вызывается из FixedWindow)

    private var lastScrollAt: [String: Date] = [:]

    /// Возвращает true если этот scroll-event начинает новый swipe (нужно записать),
    /// false если это продолжение текущего жеста.
    func shouldRecordScroll(bundleID: String, at date: Date = Date()) -> Bool {
        if let last = lastScrollAt[bundleID],
           date.timeIntervalSince(last) <= Self.scrollDebounce {
            lastScrollAt[bundleID] = date
            return false
        }
        lastScrollAt[bundleID] = date
        return true
    }

    // MARK: - Sessions

    private func sweepSessions(now: Date) {
        let timeout = Self.sessionIdleTimeout
        sessions = sessions.filter { _, s in
            now.timeIntervalSince(s.lastTouchedAt) <= timeout
        }
    }

    // MARK: - Persistence

    private static var fileURL: URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let dir = base.appendingPathComponent("HelloWork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("stats.json")
    }

    /// Текущая версия on-disk схемы. При изменении — увеличить и добавить
    /// миграцию ниже.
    private static let schemaVersion = 1

    private struct VersionedStatsStore: Codable {
        let version: Int
        let store: StatsStore
    }

    private func load() {
        guard let url = Self.fileURL else { return }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        guard let data = try? Data(contentsOf: url) else { return }

        // Сначала пробуем versioned wrapper.
        if let v = try? JSONDecoder().decode(VersionedStatsStore.self, from: data) {
            if v.version <= Self.schemaVersion {
                var s = v.store
                s.prune()
                store = s
                return
            }
            // Будущая версия (даунгрейд приложения) — backup + пустой state.
            backupCorruptFile(at: url)
            return
        }
        // Fallback на старый плоский формат (без обёртки).
        if let legacy = try? JSONDecoder().decode(StatsStore.self, from: data) {
            var s = legacy
            s.prune()
            store = s
            return
        }
        // Ни новая, ни старая схема не съелись — corrupt. Переносим в backup.
        backupCorruptFile(at: url)
    }

    private func backupCorruptFile(at url: URL) {
        let backup = url.deletingLastPathComponent()
            .appendingPathComponent("stats.corrupt-\(Int(Date().timeIntervalSince1970)).json")
        if (try? FileManager.default.moveItem(at: url, to: backup)) != nil {
            lastCorruptionBackupPath = backup.path
            return
        }
        // Не смогли переименовать — хотя бы попробуем скопировать.
        if let data = try? Data(contentsOf: url) {
            try? data.write(to: backup)
            lastCorruptionBackupPath = backup.path
        }
    }

    private func startFlushTimer() {
        let t = Timer(timeInterval: Self.flushInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.flushIfDirty()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        flushTimer = t
    }

    private func flushIfDirty() {
        guard dirty else { return }
        flushNow()
    }

    /// Синхронно пишет на диск. Вызывается на terminate и при reset.
    func flushNow() {
        guard let url = Self.fileURL else { return }
        var s = store
        s.prune()
        let wrapped = VersionedStatsStore(version: Self.schemaVersion, store: s)
        guard let data = try? JSONEncoder().encode(wrapped) else { return }
        let tmp = url.appendingPathExtension("tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
            dirty = false
        } catch {
            // best-effort
            try? FileManager.default.removeItem(at: tmp)
        }
    }
}
