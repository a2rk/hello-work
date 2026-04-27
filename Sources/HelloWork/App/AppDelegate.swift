import SwiftUI
import AppKit
import ApplicationServices
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    /// Главный status item теперь живёт внутри menubarHider controller'a (mainItem).
    /// Здесь только weak ref для удобства.
    private var statusItem: NSStatusItem? { state.menubarHider.mainItem }
    private var toggleMenuItem: NSMenuItem?
    private var countdownMenuItem: NSMenuItem?
    private var activityToken: NSObjectProtocol?
    private var prefsWindow: NSWindow?
    private var overlayWindows: [String: NSWindow] = [:]
    private let hotkeyManager = HotkeyManager()
    private let menubarHotkeyManager = HotkeyManager()
    private var hotkeyCancellables: Set<AnyCancellable> = []
    private var menubarCancellables: Set<AnyCancellable> = []

    private let firstLaunchKey = "helloWorkHasLaunchedBefore"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Periodic app-focus / time check"
        )

        stripOwnQuarantine()

        setupStatusItem()
        setupWorkspaceObservers()
        setupFocusObservers()
        registerFocusHotkey()
        setupMenubarHider()
        setupTrayObservers()
        startTimer()
        refresh()

        showPrefsIfFirstLaunch()
        setupPermissionsRefresh()
        Task { await state.checkForUpdates() }
    }

    /// При возврате в приложение перепроверяем разрешения — юзер мог изменить их в System Settings.
    private func setupPermissionsRefresh() {
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.state.permissions.refresh()
            }
        })
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.stats.flushNow()
    }

    /// Снимаем `com.apple.quarantine` с собственного бандла, чтобы Gatekeeper не
    /// показывал «может содержать вредоносный код» на каждом запуске.
    /// Без подписи Apple Developer ID это самый чистый workaround для ad-hoc.
    private func stripOwnQuarantine() {
        let url = Bundle.main.bundleURL
        let task = Process()
        task.launchPath = "/usr/bin/xattr"
        task.arguments = ["-dr", "com.apple.quarantine", url.path]
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            // Best effort — если не получилось, игнорируем.
        }
    }

    /// Самый первый запуск — открываем prefs-окно, чтобы юзер не растерялся
    /// (приложение accessory, без видимого UI кроме статус-бара).
    private func showPrefsIfFirstLaunch() {
        let defaults = UserDefaults.standard
        let isFirstLaunch = !defaults.bool(forKey: firstLaunchKey)
        if isFirstLaunch {
            defaults.set(true, forKey: firstLaunchKey)
        }

        // Permissions onboarding показываем на КАЖДОМ запуске, пока хоть одно
        // разрешение не выдано — иначе юзер забывает и hider/focus тихо не работают.
        let needsPermsOnboarding = state.permissions.anyMissing

        guard isFirstLaunch || needsPermsOnboarding else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            if needsPermsOnboarding {
                self.state.prefsSelection = .permissions
            }
            self.openPreferences()
        }
    }

    // MARK: - Overlay management

    private func ensureOverlay(for bundleID: String) -> NSWindow {
        if let w = overlayWindows[bundleID] { return w }
        let hosting = NSHostingController(rootView: OverlayContentView(state: state))
        let win = FixedWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.contentViewController = hosting
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.isMovable = false
        win.isMovableByWindowBackground = false
        win.ignoresMouseEvents = false
        win.level = .normal
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.bundleID = bundleID
        win.collector = state.stats
        overlayWindows[bundleID] = win
        return win
    }

    private var lastAutoUpdateCheck: Date?

    private func refresh() {
        state.recompute()
        updateCountdownItem()
        updateStatusBarTitle()
        refreshMenuIfNeeded()
        runBackgroundUpdateCheckIfDue()
        state.focus.tick()
        updateMenubarAutoSchedule()

        if !state.enabled {
            for w in overlayWindows.values { w.orderOut(nil) }
            state.stats.closeAllSessions()
            return
        }

        let frontmostBID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let ownBID = Bundle.main.bundleIdentifier
        var seenBIDs = Set<String>()

        for app in state.managedApps where !app.isArchived && app.bundleID != ownBID {
            seenBIDs.insert(app.bundleID)
            let win = ensureOverlay(for: app.bundleID)

            if state.isAllowed(app: app) {
                win.orderOut(nil)
                continue
            }

            guard let (frame, winNum) = AppWindowFinder.find(bundleID: app.bundleID) else {
                win.orderOut(nil)
                continue
            }

            if win.frame != frame {
                win.setFrame(frame, display: true)
            }
            win.order(.above, relativeTo: winNum)

            // Считаем blocked-время только если жертва frontmost (а overlay поверх неё) —
            // тогда юзер реально смотрит на блок, а не он висит фоном на другом мониторе.
            if frontmostBID == app.bundleID {
                state.stats.tickBlocked(bundleID: app.bundleID, seconds: 0.25)
            }

            if frontmostBID == app.bundleID && !win.isKeyWindow {
                win.makeKey()
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        let staleBIDs = overlayWindows.keys.filter { !seenBIDs.contains($0) }
        for bid in staleBIDs {
            overlayWindows[bid]?.orderOut(nil)
            overlayWindows.removeValue(forKey: bid)
        }
    }

    // MARK: - Status bar

    private var lastMenuSignature: String = ""

    /// Создаёт status items через controller. Также вешает menu на main item.
    private func setupStatusItem() {
        applyStatusBarConfiguration()
    }

    /// Полностью убирает все status items.
    private func tearDownStatusItem() {
        state.menubarHider.tearDown()
    }

    private func applyStatusIconStyle() {
        state.menubarHider.updateMainIcon(style: state.statusIconStyle)
    }

    /// Конфигурирует controller под текущие настройки.
    private func applyStatusBarConfiguration() {
        devlog("appdelegate",
               "applyStatusBarConfiguration — showIcon=\(state.showStatusBarIcon) hiderEnabled=\(state.menubarHiderEnabled) iconStyle=\(state.statusIconStyle.rawValue)")
        guard state.showStatusBarIcon else {
            state.menubarHider.tearDown()
            return
        }
        state.menubarHider.configure(
            hiderEnabled: state.menubarHiderEnabled,
            initialCollapsed: state.menubarPersistCollapsed
                ? state.menubarRestoredCollapsed
                : false,
            iconStyle: state.statusIconStyle
        )
        rebuildStatusMenu()
    }

    /// Обновляет видимый title рядом с иконкой — countdown grace в формате `0:47`.
    private func updateStatusBarTitle() {
        guard let button = statusItem?.button else { return }
        if state.showGraceCountdownInBar, let remaining = state.graceRemaining {
            let total = Int(ceil(remaining))
            let mm = total / 60
            let ss = total % 60
            button.title = " \(mm):\(String(format: "%02d", ss))"
            button.imagePosition = .imageLeading
        } else if !button.title.isEmpty {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    private func rebuildStatusMenu() {
        guard let item = statusItem else { return }
        let menu = NSMenu()
        let t = state.t

        // 1. Update notice (если доступно обновление)
        if state.updateAvailable, let v = state.latestRemoteVersion {
            let updateItem = NSMenuItem(
                title: t.installButton(v),
                action: #selector(triggerUpdate),
                keyEquivalent: ""
            )
            updateItem.target = self
            if let icon = NSImage(
                systemSymbolName: "arrow.down.circle.fill",
                accessibilityDescription: nil
            ) {
                icon.isTemplate = true
                updateItem.image = icon
            }
            menu.addItem(updateItem)
            menu.addItem(NSMenuItem.separator())
        }

        // 2. Глобальный тумблер (наверху) — кастомная SwiftUI-вьюха с
        //    нативным Toggle вместо attributedTitle с точкой
        let toggleHosting = NSHostingView(rootView: ToggleMenuRow(state: state))
        toggleHosting.frame = NSRect(x: 0, y: 0, width: 240, height: 28)
        let toggleItem = NSMenuItem()
        toggleItem.view = toggleHosting
        menu.addItem(toggleItem)
        toggleMenuItem = toggleItem

        // 3. Линия + список приложений со статус-точкой справа
        let activeApps = state.managedApps.filter { !$0.isArchived }
        if !activeApps.isEmpty {
            menu.addItem(NSMenuItem.separator())
            for app in activeApps {
                let bid = app.bundleID
                let row = AppMenuRow(
                    app: app,
                    isAllowed: state.isAllowed(app: app)
                ) { [weak self] in
                    guard let self else { return }
                    self.statusItem?.menu?.cancelTracking()
                    self.state.prefsSelection = .app(bid)
                    self.openPreferences()
                }
                let hosting = NSHostingView(rootView: row)
                hosting.frame = NSRect(x: 0, y: 0, width: 240, height: 26)
                let appItem = NSMenuItem()
                appItem.view = hosting
                menu.addItem(appItem)
            }
        }

        // 4. Линия + грейс-кнопки (восходяще)
        let graceSeconds = state.allGraceSeconds
        if !graceSeconds.isEmpty {
            menu.addItem(NSMenuItem.separator())
            for secs in graceSeconds {
                let gi = NSMenuItem(
                    title: t.menuGraceLabel(secs),
                    action: #selector(grantGrace(_:)),
                    keyEquivalent: ""
                )
                gi.target = self
                gi.tag = secs
                menu.addItem(gi)
            }
        }

        // Countdown — невидимый по умолчанию, показывается во время grace
        let countdown = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        countdown.isEnabled = false
        countdown.isHidden = true
        menu.addItem(countdown)
        countdownMenuItem = countdown

        // 5. Линия + Focus mode + основные действия
        menu.addItem(NSMenuItem.separator())

        if state.focusModeEnabled {
            let focusItem = NSMenuItem(
                title: t.focusMenuItem,
                action: #selector(toggleFocusMode),
                keyEquivalent: ""
            )
            focusItem.target = self
            focusItem.state = state.focus.isActive ? .on : .off
            // Правая клавиатурная подсказка через обычный текст в title — простой путь.
            let hk = state.focusHotkey.displayString()
            focusItem.title = "\(t.focusMenuItem)   \(hk)"
            menu.addItem(focusItem)
            menu.addItem(NSMenuItem.separator())
        }

        if state.menubarHiderEnabled {
            let hiderItem = NSMenuItem(
                title: state.menubarHider.isCollapsed
                    ? t.menubarShowAll
                    : t.menubarHideAll,
                action: #selector(toggleMenubarHider),
                keyEquivalent: ""
            )
            hiderItem.target = self
            let hk = state.menubarHotkey.displayString()
            hiderItem.title = "\(hiderItem.title)   \(hk)"
            menu.addItem(hiderItem)
            menu.addItem(NSMenuItem.separator())
        }

        let openMenu = NSMenuItem(
            title: t.menuOpenPrefs,
            action: #selector(openPreferences),
            keyEquivalent: ""
        )
        openMenu.target = self
        menu.addItem(openMenu)

        let quit = NSMenuItem(
            title: t.menuQuit,
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        )
        menu.addItem(quit)

        item.menu = menu
    }

    private func refreshMenuIfNeeded() {
        let appsSig = state.managedApps
            .filter { !$0.isArchived }
            .map { "\($0.bundleID):\(state.isAllowed(app: $0))" }
            .joined(separator: ",")
        let signature = [
            state.language.rawValue,
            "\(state.enabled)",
            "\(state.allGraceSeconds)",
            "\(state.updateAvailable)",
            state.latestRemoteVersion ?? "",
            "\(state.focusModeEnabled)",
            "\(state.focus.isActive)",
            state.focusHotkey.serialized,
            "\(state.menubarHiderEnabled)",
            "\(state.menubarHider.isCollapsed)",
            state.menubarHotkey.serialized,
            appsSig
        ].joined(separator: "|")

        if signature != lastMenuSignature {
            rebuildStatusMenu()
            lastMenuSignature = signature
        }
    }

    // MARK: - Workspace + Timer

    private func setupWorkspaceObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        observers.append(nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.refresh() })
        observers.append(nc.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.refresh() })
    }

    // MARK: - Focus mode

    private func setupFocusObservers() {
        // Изменение конфигурации экранов.
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.state.focus.handleScreenParametersChanged()
            }
        })

        // Sleep / lock — гасим focus mode.
        let nc = NSWorkspace.shared.notificationCenter
        observers.append(nc.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.state.focus.handleSystemSleep()
            }
        })
        observers.append(nc.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.state.focus.handleSystemSleep()
            }
        })
    }

    // MARK: - Menubar hider

    private func setupMenubarHider() {
        // Без Accessibility CGEvent.postToPid игнорится — отправляем юзера
        // на экран «Доступы», там есть кнопка Grant и подсказки.
        state.menubarHider.onAccessibilityRequired = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.state.prefsSelection = .permissions
                self.openPreferences()
                // Если ещё не спрашивали — system prompt появится автоматически.
                if self.state.permissions.accessibility == .notDetermined {
                    self.state.permissions.requestAccessibility()
                }
            }
        }

        // Подписки: enable/disable, hotkey смена, авто-скрытие триггеры.
        state.$menubarHiderEnabled
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.applyStatusBarConfiguration()
                    self?.registerMenubarHotkey()
                }
            }
            .store(in: &menubarCancellables)

        state.$menubarHotkey
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.registerMenubarHotkey() }
            }
            .store(in: &menubarCancellables)

        // Auto-hide: focus mode.
        state.focus.$isActive
            .dropFirst()
            .sink { [weak self] active in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard self.state.menubarHiderEnabled, self.state.menubarHideOnFocus else { return }
                    self.state.menubarHider.applyAuto(collapsed: active)
                }
            }
            .store(in: &menubarCancellables)

        // Изменилось состояние hider — persist (визуал обновляет controller сам).
        state.menubarHider.$isCollapsed
            .dropFirst()
            .sink { [weak self] collapsed in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if self.state.menubarPersistCollapsed {
                        self.state.saveMenubarCollapsed(collapsed)
                    }
                }
            }
            .store(in: &menubarCancellables)

        registerMenubarHotkey()
    }

    private func registerMenubarHotkey() {
        menubarHotkeyManager.unregister()
        guard state.menubarHiderEnabled else {
            devlog("hotkey", "menubar hider disabled — hotkey not registered")
            return
        }
        let hk = state.menubarHotkey
        let ok = menubarHotkeyManager.register(hk.asFocusHotkey) { [weak self] in
            devlog("hotkey", "menubar hotkey FIRED — calling toggle()")
            self?.state.menubarHider.toggle()
        }
        devlog("hotkey", "registerMenubarHotkey \(hk.displayString()) success=\(ok)")
    }

    /// Авто-скрытие при изменении расписания. Вызывается из refresh().
    private func updateMenubarAutoSchedule() {
        guard state.menubarHiderEnabled, state.menubarHideOnSchedule else { return }
        // Если есть хоть одно managed app в blocked-режиме — скрываем.
        let anyBlocked = state.managedApps.contains {
            !$0.isArchived && !state.isAllowed(app: $0)
        }
        state.menubarHider.applyAuto(collapsed: anyBlocked)
    }

    // MARK: - Tray observers (status bar icon, chevron style, peek behavior)

    private var peekMouseMonitor: Any?
    private var lastPeekAt: Date?

    private func setupTrayObservers() {
        state.$showStatusBarIcon
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.applyStatusBarConfiguration()
                }
            }
            .store(in: &menubarCancellables)

        state.$statusIconStyle
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.applyStatusIconStyle() }
            }
            .store(in: &menubarCancellables)

        state.$showGraceCountdownInBar
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.updateStatusBarTitle() }
            }
            .store(in: &menubarCancellables)

        state.$menubarPeekSeconds
            .sink { [weak self] secs in
                Task { @MainActor [weak self] in
                    self?.updatePeekMonitor(seconds: secs)
                }
            }
            .store(in: &menubarCancellables)
    }

    /// Глобальный mouseMoved monitor — детектит наведение на самый верх экрана.
    private func updatePeekMonitor(seconds: Int) {
        if let m = peekMouseMonitor {
            NSEvent.removeMonitor(m)
            peekMouseMonitor = nil
        }
        guard seconds > 0, state.menubarHiderEnabled else { return }
        peekMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMouseMove(event: event)
            }
        }
    }

    private func handleMouseMove(event: NSEvent) {
        // event.locationInWindow для global monitor — это global screen coords (origin bottom-left).
        let p = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(p) }) else { return }
        let topY = screen.frame.maxY
        // На самой верхней 2px-полосе — peek-trigger.
        guard p.y >= topY - 2 else { return }
        // Debounce — не чаще одного peek в 2 секунды.
        if let last = lastPeekAt, Date().timeIntervalSince(last) < 2 { return }
        lastPeekAt = Date()
        state.menubarHider.peek(seconds: state.menubarPeekSeconds)
    }

    /// Регистрируем хоткей по AppState.focusHotkey. Перерегистрация при смене.
    func registerFocusHotkey() {
        hotkeyManager.unregister()
        guard state.focusModeEnabled else { return }
        _ = hotkeyManager.register(state.focusHotkey) { [weak self] in
            self?.state.focus.toggle()
        }

        // Подписываемся один раз — на изменения hotkey/enabled перерегистрируем.
        if hotkeyCancellables.isEmpty {
            state.$focusHotkey
                .dropFirst()
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in self?.registerFocusHotkey() }
                }
                .store(in: &hotkeyCancellables)
            state.$focusModeEnabled
                .dropFirst()
                .sink { [weak self] enabled in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if !enabled { self.state.focus.disable() }
                        self.registerFocusHotkey()
                    }
                }
                .store(in: &hotkeyCancellables)
        }
    }

    private func startTimer() {
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - Menu actions

    @objc private func toggleEnabled() {
        state.enabled.toggle()
        toggleMenuItem?.title = toggleTitle()
        refresh()
    }

    @objc private func grantGrace(_ sender: NSMenuItem) {
        state.grantGrace(seconds: TimeInterval(sender.tag))
        refresh()
    }

    @objc private func toggleFocusMode() {
        state.focus.toggle()
    }

    @objc private func toggleMenubarHider() {
        devlog("menu", "user clicked «Скрыть/Показать всё»")
        state.menubarHider.toggle()
    }

    @objc private func triggerUpdate() {
        guard state.installer.status == .idle else { return }
        guard let dmgStr = state.devLogEntries.first?.dmgUrl,
              let url = URL(string: dmgStr) else { return }
        if !UpdateInstaller.canSelfInstall {
            NSWorkspace.shared.open(url)
            return
        }
        Task { await state.installer.install(dmgUrl: url) }
    }

    private func runBackgroundUpdateCheckIfDue() {
        guard state.autoUpdate else { return }
        let interval: TimeInterval = 30 * 60
        let elapsed = Date().timeIntervalSince(lastAutoUpdateCheck ?? .distantPast)
        guard elapsed > interval else { return }
        lastAutoUpdateCheck = Date()
        Task { await state.checkForUpdates() }
    }

    @objc private func openPreferences() {
        if prefsWindow == nil {
            let size = Layout.prefsWindow
            let win = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.title = "Hello work"
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.isReleasedWhenClosed = false

            let hosting = NSHostingController(rootView: PrefsView(state: state))
            win.contentViewController = hosting
            win.setContentSize(size)
            win.minSize = size
            win.maxSize = size
            win.center()
            prefsWindow = win

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(prefsWindowDidResignKey(_:)),
                name: NSWindow.didResignKeyNotification,
                object: win
            )
        }
        prefsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Каждое открытие окна — свежий fetch dev_log, чтобы юзер видел актуальное.
        Task { await state.checkForUpdates() }
    }

    @objc private func prefsWindowDidResignKey(_ notification: Notification) {
        // Откладываем проверку на один runloop-тик: SwiftUI .alert и NSOpenPanel
        // презентуются как sheet, и attachedSheet выставляется чуть позже момента
        // потери key-статуса. Без этой задержки мы закрывали окно прямо во время
        // презентации алёрта, и юзер видел зависшее приложение.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Идёт app-модальный диалог
            if NSApp.modalWindow != nil { return }
            // К окну прикреплён sheet (alert / NSOpenPanel)
            if self.prefsWindow?.attachedSheet != nil { return }
            // Окно успело снова стать key
            if self.prefsWindow?.isKeyWindow == true { return }
            self.prefsWindow?.close()
        }
    }

    private func updateCountdownItem() {
        guard let item = countdownMenuItem else { return }
        if let remaining = state.graceRemaining {
            let total = Int(ceil(remaining))
            let mm = total / 60
            let ss = total % 60
            item.title = String(format: "%02d:%02d", mm, ss)
            item.isHidden = false
        } else {
            item.isHidden = true
        }
    }

    private func toggleTitle() -> String {
        state.t.menuToggleEnabled(state.enabled)
    }
}
