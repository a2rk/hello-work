import AppKit
import Combine

/// Оркестратор фичи Менюбар: создаёт hider status item, держит состояние,
/// подписан на focus mode и расписание для авто-скрытия.
@MainActor
final class MenubarHiderController: ObservableObject {
    @Published private(set) var isCollapsed: Bool = true
    @Published private(set) var enabled: Bool = false

    private var hider: HiderStatusItem?
    private var lastAutoState: Bool? = nil      // запоминаем что мы сами форсили — чтобы не воевать с юзером

    /// Внешний вид — синхронизируется из AppState.
    var showChevron: Bool = true
    var chevronStyle: HiderChevronStyle = .chevron

    /// Peek state: временный expand на N секунд при наведении на верх экрана.
    private var peekTimer: Timer?

    init() {}

    // MARK: - Public

    /// Включает/выключает фичу. Создаёт или сносит status item.
    func setEnabled(_ enabled: Bool, initialCollapsed: Bool) {
        if enabled {
            guard hider == nil else { return }
            let h = HiderStatusItem()
            h.showChevron = self.showChevron
            h.chevronStyle = self.chevronStyle
            h.onClick = { [weak self] in
                Task { @MainActor [weak self] in self?.toggle() }
            }
            self.hider = h
            self.enabled = true
            // Применяем сохранённое состояние.
            self.isCollapsed = initialCollapsed
            h.setCollapsed(initialCollapsed, animated: false)
        } else {
            hider?.tearDown()
            hider = nil
            self.enabled = false
            self.isCollapsed = true
            lastAutoState = nil
            cancelPeek()
        }
    }

    /// Применить стиль (вызывается из AppDelegate при изменении state).
    func applyAppearance(showChevron: Bool, style: HiderChevronStyle) {
        self.showChevron = showChevron
        self.chevronStyle = style
        hider?.showChevron = showChevron
        hider?.chevronStyle = style
    }

    // MARK: - Peek

    /// Временно раскрыть menubar на N секунд (при наведении на верх экрана).
    /// Если уже expanded — игнор. Если активен авто — игнор.
    func peek(seconds: Int) {
        guard seconds > 0, let h = hider else { return }
        guard h.isCollapsed else { return }     // уже раскрыт — пиковать нечего

        h.setCollapsed(false)
        isCollapsed = false

        peekTimer?.invalidate()
        let t = Timer(timeInterval: TimeInterval(seconds), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let h = self.hider else { return }
                h.setCollapsed(true)
                self.isCollapsed = true
            }
        }
        RunLoop.main.add(t, forMode: .common)
        peekTimer = t
    }

    private func cancelPeek() {
        peekTimer?.invalidate()
        peekTimer = nil
    }

    func collapseAll() {
        guard let h = hider else { return }
        h.setCollapsed(true)
        isCollapsed = true
    }

    func expandAll() {
        guard let h = hider else { return }
        h.setCollapsed(false)
        isCollapsed = false
    }

    func toggle() {
        guard let h = hider else { return }
        h.toggle()
        isCollapsed = h.isCollapsed
        // Юзер вручную трогнул — сбрасываем "автоматическое" последнее состояние.
        lastAutoState = nil
    }

    /// Применяет авто-скрытие. Если desired совпадает с текущим — ничего не делаем.
    /// `lastAutoState` нужен чтобы не дёргать туда-сюда если юзер сам поменял.
    func applyAuto(collapsed: Bool) {
        guard let h = hider else { return }
        // Если юзер сам что-то менял после нашего последнего авто-применения — не вмешиваемся
        // пока следующее авто-событие не произойдёт с другим значением.
        if let last = lastAutoState, last == h.isCollapsed {
            // мы сами это поставили, можно менять
        } else if lastAutoState != nil {
            // юзер поменял после нашего auto — оставляем как есть, ждём смены желаемого.
            // Перепишем lastAutoState чтобы при следующей смене сравнить корректно.
            lastAutoState = collapsed
            return
        }

        if h.isCollapsed != collapsed {
            h.setCollapsed(collapsed)
            isCollapsed = collapsed
        }
        lastAutoState = collapsed
    }
}
