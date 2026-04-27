import AppKit
import SwiftUI

@MainActor
final class StubAppDelegate: NSObject, NSApplicationDelegate {
    private let manager = EngineManager()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Если engine уже установлен — silent launch + exit, без UI.
        if manager.engineInstalled {
            Task {
                let ok = await manager.launchEngine()
                if ok {
                    NSApp.terminate(nil)
                } else {
                    // Если не запустился — показываем UI с диагностикой.
                    showUI()
                    await manager.bootstrap(force: true)
                }
            }
            return
        }

        showUI()
        Task {
            await manager.bootstrap()
            if case .ready = manager.status {
                // Чуть подождём, чтобы юзер увидел "Запускаю…"
                try? await Task.sleep(nanoseconds: 600_000_000)
                NSApp.terminate(nil)
            }
        }
    }

    private func showUI() {
        let hosting = NSHostingController(rootView: StubView(model: manager))
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "HWInstaller"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isReleasedWhenClosed = false
        win.contentViewController = hosting
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win
    }
}
