import AppKit
import Combine
import Foundation
import SwiftUI

/// Главный controller meditation-сессии. Lifecycle:
///   start():  создаёт MeditationWindow на каждом NSScreen (точка только на
///             primary), fade-in alpha 0→1, запускает 60Hz Timer для tick'ов
///             animator'а + accumulate elapsed.
///   tick:     animator.tick(at: now) → новая позиция точки → @Published.
///             elapsed >= duration → stop(naturally: true).
///   ESC:      MeditationWindow.onEscapePressed → stop(naturally: false).
///   stop():   timer invalidate, fade-out alpha 1→0, после fade — orderOut +
///             release windows + recordMeditation на stateRef.
@MainActor
final class MeditationController: ObservableObject {
    @Published private(set) var isActive: Bool = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var dotPosition: CGPoint = .zero
    @Published private(set) var dotOpacity: Double = 0

    static let defaultDuration: TimeInterval = 60.0

    weak var stateRef: AppState?

    // MARK: - Private state

    private var windows: [MeditationWindow] = []
    private var primaryWindow: MeditationWindow?
    private var hostingControllers: [NSHostingController<MeditationCanvasView>] = []
    private var primaryHostingController: NSHostingController<MeditationCanvasView>?

    private var session: MeditationSession?
    private var sessionStart: Date?
    private var timer: Timer?
    private var animator: MeditationDotAnimator?
    private var rng = SystemRandomNumberGenerator()

    init() {}

    // MARK: - Public API

    /// Запускает сессию. Идемпотентен: повторный вызов при isActive — no-op.
    func start() {
        guard !isActive else {
            devlog("meditation", "start() ignored — already active")
            return
        }
        guard let primaryScreen = NSScreen.main else {
            devlog("meditation", "start() failed — no NSScreen.main")
            return
        }

        let now = Date()
        let newSession = MeditationSession(
            startedAt: now,
            plannedDuration: Self.defaultDuration,
            completedDuration: 0,
            completedNaturally: false
        )
        session = newSession
        sessionStart = now
        elapsed = 0

        // Animator только для primary screen.
        animator = MeditationDotAnimator(
            bounds: primaryScreen.frame,
            startDate: now,
            rng: &rng
        )
        // Initial position: tick(at: now) выдаст currentTarget (статичен пока progress=0).
        if var a = animator {
            dotPosition = a.tick(at: now, rng: &rng)
            animator = a
        }
        dotOpacity = 0

        // Создаём windows на КАЖДОМ screen. Точка — только primary.
        let screens = NSScreen.screens
        var createdWindows: [MeditationWindow] = []
        var createdHostings: [NSHostingController<MeditationCanvasView>] = []
        for screen in screens {
            let isPrimary = (screen == primaryScreen)
            let win = MeditationWindow(screen: screen)
            win.onEscapePressed = { [weak self] in
                self?.stop(naturally: false)
            }
            let canvas = MeditationCanvasView(
                dotPosition: isPrimary ? dotPosition : nil,
                progress: 0,
                showProgressLine: stateRef?.meditationShowProgress ?? true,
                dotOpacity: dotOpacity
            )
            let host = NSHostingController(rootView: canvas)
            host.view.frame = NSRect(origin: .zero, size: screen.frame.size)
            win.contentView = host.view
            win.makeKeyAndOrderFront(nil)
            createdWindows.append(win)
            createdHostings.append(host)
            if isPrimary {
                primaryWindow = win
                primaryHostingController = host
            }
        }
        windows = createdWindows
        hostingControllers = createdHostings

        // Fade-in window alpha + dotOpacity.
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.5
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for w in createdWindows {
                w.animator().alphaValue = 1.0
            }
        }, completionHandler: nil)
        // Точка появляется чуть позже, плавно.
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            dotOpacity = 1.0
        }

        // 60Hz timer.
        let t = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        isActive = true
        devlog("meditation", "start() — sessionId=\(newSession.id) screens=\(screens.count) primaryFrame=\(primaryScreen.frame)")
    }

    /// Останавливает активную сессию. naturally=true → completion (запись count++).
    /// naturally=false → ESC abort (count не инкрементится, но totalSeconds учитывается).
    func stop(naturally: Bool) {
        guard isActive else { return }
        guard let s = session, let start = sessionStart else { return }

        timer?.invalidate()
        timer = nil

        let endDate = Date()
        let actualDuration = endDate.timeIntervalSince(start)
        let finalSession = MeditationSession(
            id: s.id,
            startedAt: s.startedAt,
            plannedDuration: s.plannedDuration,
            completedDuration: actualDuration,
            completedNaturally: naturally
        )

        // Fade-out точки сразу, окон — параллельно.
        withAnimation(.easeIn(duration: 0.4)) {
            dotOpacity = 0
        }
        let toClose = windows
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for w in toClose {
                w.animator().alphaValue = 0
            }
        }, completionHandler: { [weak self] in
            guard let self else { return }
            for w in toClose {
                w.orderOut(nil)
            }
            self.windows.removeAll()
            self.hostingControllers.removeAll()
            self.primaryWindow = nil
            self.primaryHostingController = nil
        })

        // Persist session.
        stateRef?.recordMeditation(finalSession)

        isActive = false
        session = nil
        sessionStart = nil
        animator = nil
        elapsed = 0
        devlog("meditation", "stop(naturally: \(naturally)) — duration=\(String(format: "%.1f", actualDuration))s")
    }

    // MARK: - Tick

    private func tick() {
        guard isActive, let start = sessionStart, var a = animator else { return }
        let now = Date()
        elapsed = now.timeIntervalSince(start)

        if elapsed >= Self.defaultDuration {
            // Completion sound (если включён) — играем ДО stop'а, чтобы звук
            // совпал с финальным fade-out, а не пропадал вместе с windows.
            if stateRef?.meditationCompletionSound ?? true {
                NSSound(named: NSSound.Name("Glass"))?.play()
            }
            stop(naturally: true)
            return
        }

        dotPosition = a.tick(at: now, rng: &rng)
        animator = a

        // Re-render canvas через rebuild rootView. NSHostingController
        // сам обновит view через SwiftUI diffing.
        let progress = elapsed / Self.defaultDuration
        let showProgress = stateRef?.meditationShowProgress ?? true
        for (idx, host) in hostingControllers.enumerated() {
            let isPrimary = (windows[idx] == primaryWindow)
            host.rootView = MeditationCanvasView(
                dotPosition: isPrimary ? dotPosition : nil,
                progress: progress,
                showProgressLine: showProgress,
                dotOpacity: dotOpacity
            )
        }
    }
}
