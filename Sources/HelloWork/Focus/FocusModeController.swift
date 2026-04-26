import AppKit
import Combine

/// Оркестратор focus mode: dim-windows + tracking hero-окна.
@MainActor
final class FocusModeController: ObservableObject {
    @Published private(set) var isActive: Bool = false

    private var dimWindows: [CGDirectDisplayID: FocusOverlayWindow] = [:]
    private var lastHero: FrontmostWindowFinder.Target?

    /// Опции, которые задаёт AppState.
    var dimOpacity: Double = 0.9
    var useAccessibility: Bool = false

    private static let fadeInDuration: TimeInterval = 0.25
    private static let fadeOutDuration: TimeInterval = 0.12

    // MARK: - Public

    /// Toggle активации. Не делает ничего, если фича выключена в настройках.
    func toggle() {
        if isActive { disable() } else { enable() }
    }

    func enable() {
        guard !isActive else { return }

        // Если frontmost = мы сами или нет hero — всё равно активируем,
        // но dim покажем только тогда когда хоть какое-то окно есть.
        rebuildDimWindowsIfNeeded()
        for win in dimWindows.values {
            win.alphaValue = 0
            win.orderFront(nil)
        }
        isActive = true

        // Сразу применяем z-order под текущий hero.
        applyHero(animated: false)
        fadeIn()
    }

    func disable() {
        guard isActive else { return }
        isActive = false
        lastHero = nil
        fadeOut { [weak self] in
            guard let self else { return }
            for win in self.dimWindows.values { win.orderOut(nil) }
        }
    }

    /// Вызывается из таймера AppDelegate.refresh раз в 250мс.
    func tick() {
        guard isActive else { return }

        // Пересоздаём окна если изменился набор экранов.
        rebuildDimWindowsIfNeeded()

        applyHero(animated: true)
    }

    /// На отключение монитора / смену пресета мониторов.
    func handleScreenParametersChanged() {
        guard isActive else { return }
        // Полностью пересоздаём dim-windows.
        for win in dimWindows.values { win.orderOut(nil) }
        dimWindows.removeAll()
        rebuildDimWindowsIfNeeded()
        for win in dimWindows.values {
            win.alphaValue = 1
            win.orderFront(nil)
        }
        applyHero(animated: false)
    }

    /// Sleep / Lock — мягко выключаем.
    func handleSystemSleep() {
        if isActive { disable() }
    }

    func updateDimOpacity(_ opacity: Double) {
        dimOpacity = opacity
        for win in dimWindows.values {
            win.setDimOpacity(opacity)
        }
    }

    // MARK: - Internal

    private func rebuildDimWindowsIfNeeded() {
        let currentScreens = NSScreen.screens
        let currentIDs = Set(currentScreens.compactMap { displayID(of: $0) })
        let knownIDs = Set(dimWindows.keys)

        // Удаляем dim для отключённых экранов.
        for id in knownIDs.subtracting(currentIDs) {
            dimWindows[id]?.orderOut(nil)
            dimWindows.removeValue(forKey: id)
        }

        // Добавляем для новых.
        for screen in currentScreens {
            guard let id = displayID(of: screen) else { continue }
            if dimWindows[id] == nil {
                let win = FocusOverlayWindow(screen: screen, opacity: dimOpacity)
                dimWindows[id] = win
                if isActive {
                    win.alphaValue = 1
                    win.orderFront(nil)
                }
            } else {
                // Существующее окно мог сместиться экран — обновим frame.
                dimWindows[id]?.setFrame(screen.frame, display: false)
            }
        }
    }

    private func applyHero(animated: Bool) {
        let target = FrontmostWindowFinder.find(useAccessibility: useAccessibility)

        // Если frontmost — мы сами, оставляем предыдущий hero.
        let ownBID = Bundle.main.bundleIdentifier
        let effectiveTarget: FrontmostWindowFinder.Target?
        if let t = target, t.bundleID == ownBID {
            effectiveTarget = lastHero
        } else {
            effectiveTarget = target
            if target != nil { lastHero = target }
        }

        // Fullscreen — гасим focus mode (нет смысла рисовать поверх).
        if let t = effectiveTarget, t.isFullScreen {
            if isActive { disable() }
            return
        }

        // Если hero не нашли — все dim сверху всех окон.
        guard let hero = effectiveTarget else {
            for win in dimWindows.values {
                win.orderFrontRegardless()
            }
            return
        }

        // На экране с hero — dim под hero.
        // На остальных экранах — dim поверх всех.
        let heroScreenID = hero.screen.flatMap { displayID(of: $0) }

        for (id, win) in dimWindows {
            if id == heroScreenID, hero.windowNumber > 0 {
                // order(.below, relativeTo: heroWindowNumber) ставит наше dim ровно под hero.
                win.order(.below, relativeTo: hero.windowNumber)
            } else {
                // На экранах без hero — dim поверх всего.
                win.orderFrontRegardless()
            }
        }

        _ = animated  // зарезервировано на смену hero (можно потом анимировать alpha-flick)
    }

    // MARK: - Fade

    private func fadeIn() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Self.fadeInDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for win in dimWindows.values {
                win.animator().alphaValue = 1
            }
        }
    }

    private func fadeOut(completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Self.fadeOutDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for win in self.dimWindows.values {
                win.animator().alphaValue = 0
            }
        }, completionHandler: completion)
    }

    // MARK: - Display ID

    private func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return screen.deviceDescription[key] as? CGDirectDisplayID
    }
}
