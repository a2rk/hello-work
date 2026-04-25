import SwiftUI
import AppKit

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

    private let firstLaunchKey = "helloWorkHasLaunchedBefore"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Periodic app-focus / time check"
        )

        setupStatusItem()
        setupWorkspaceObservers()
        startTimer()
        refresh()

        showPrefsIfFirstLaunch()
        Task { await state.checkForUpdates() }
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
        let hosting = NSHostingController(rootView: OverlayContentView())
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
        overlayWindows[bundleID] = win
        return win
    }

    private func refresh() {
        state.recompute()
        updateCountdownItem()
        toggleMenuItem?.title = toggleTitle()

        if !state.enabled {
            for w in overlayWindows.values { w.orderOut(nil) }
            return
        }

        let frontmostBID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        var seenBIDs = Set<String>()

        for app in state.managedApps where !app.isArchived {
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

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = MenuBarIcon.make()

        let menu = NSMenu()

        let openMenu = NSMenuItem(
            title: "Меню",
            action: #selector(openPreferences),
            keyEquivalent: ""
        )
        openMenu.target = self
        menu.addItem(openMenu)

        menu.addItem(NSMenuItem.separator())

        let toggle = NSMenuItem(
            title: toggleTitle(),
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)
        toggleMenuItem = toggle

        menu.addItem(NSMenuItem.separator())

        let grace = NSMenuItem(
            title: "Ещё минутку",
            action: #selector(grantOneMinute),
            keyEquivalent: ""
        )
        grace.target = self
        menu.addItem(grace)

        let countdown = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        countdown.isEnabled = false
        countdown.isHidden = true
        menu.addItem(countdown)
        countdownMenuItem = countdown

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(
            title: "Закрыть",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        )
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
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

    @objc private func grantOneMinute() {
        state.grantGrace(seconds: 60)
        refresh()
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
    }

    @objc private func prefsWindowDidResignKey(_ notification: Notification) {
        if NSApp.modalWindow != nil { return }
        prefsWindow?.close()
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
        "Включено: \(state.enabled ? "Да" : "Нет")"
    }
}
