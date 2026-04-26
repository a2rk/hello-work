import SwiftUI
import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var statusItem: NSStatusItem?
    private var toggleMenuItem: NSMenuItem?
    private var countdownMenuItem: NSMenuItem?
    private var activityToken: NSObjectProtocol?
    private var prefsWindow: NSWindow?
    private var overlayWindows: [String: NSWindow] = [:]
    private let hotkeyManager = HotkeyManager()
    private var hotkeyCancellables: Set<AnyCancellable> = []

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
        startTimer()
        refresh()

        showPrefsIfFirstLaunch()
        Task { await state.checkForUpdates() }
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
        guard !defaults.bool(forKey: firstLaunchKey) else { return }
        defaults.set(true, forKey: firstLaunchKey)

        // Небольшая задержка, чтобы статус-бар и обсерверы успели разогреться.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.openPreferences()
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
        refreshMenuIfNeeded()
        runBackgroundUpdateCheckIfDue()
        state.focus.tick()

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

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = MenuBarIcon.make()
        statusItem = item
        rebuildStatusMenu()
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
