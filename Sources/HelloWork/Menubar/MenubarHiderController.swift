import AppKit
import Combine

/// Оркестратор menubar-hider'а. Только state — визуально hider теперь это
/// расширение основного NSStatusItem приложения (см. AppDelegate.applyMenubarHiderState).
@MainActor
final class MenubarHiderController: ObservableObject {
    @Published private(set) var isCollapsed: Bool = true
    @Published private(set) var enabled: Bool = false

    private var lastAutoState: Bool? = nil      // запоминаем что мы сами форсили — чтобы не воевать с юзером
    private var peekTimer: Timer?

    init() {}

    // MARK: - Public

    /// Включает/выключает фичу. State-only, физическое поведение — в AppDelegate через @Published bindings.
    func setEnabled(_ enabled: Bool, initialCollapsed: Bool) {
        if enabled {
            self.enabled = true
            self.isCollapsed = initialCollapsed
        } else {
            self.enabled = false
            self.isCollapsed = true
            lastAutoState = nil
            cancelPeek()
        }
    }

    func collapseAll() {
        guard enabled else { return }
        isCollapsed = true
    }

    func expandAll() {
        guard enabled else { return }
        isCollapsed = false
    }

    func toggle() {
        guard enabled else { return }
        isCollapsed.toggle()
        // Юзер вручную трогнул — сбрасываем "автоматическое" последнее состояние.
        lastAutoState = nil
    }

    /// Применяет авто-скрытие. Если desired совпадает с текущим — ничего не делаем.
    /// `lastAutoState` нужен чтобы не дёргать туда-сюда если юзер сам поменял.
    func applyAuto(collapsed: Bool) {
        guard enabled else { return }

        if let last = lastAutoState, last == isCollapsed {
            // мы сами это поставили, можно менять
        } else if lastAutoState != nil {
            // юзер поменял после нашего auto — оставляем как есть, ждём смены желаемого.
            lastAutoState = collapsed
            return
        }

        if isCollapsed != collapsed {
            isCollapsed = collapsed
        }
        lastAutoState = collapsed
    }

    // MARK: - Peek

    /// Временно раскрыть menubar на N секунд (при наведении на верх экрана).
    /// Если уже expanded — игнор.
    func peek(seconds: Int) {
        guard enabled, seconds > 0, isCollapsed else { return }

        isCollapsed = false

        peekTimer?.invalidate()
        let t = Timer(timeInterval: TimeInterval(seconds), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isCollapsed = true
            }
        }
        RunLoop.main.add(t, forMode: .common)
        peekTimer = t
    }

    private func cancelPeek() {
        peekTimer?.invalidate()
        peekTimer = nil
    }
}
