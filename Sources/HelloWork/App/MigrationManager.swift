import AppKit
import Foundation
import ServiceManagement

/// Одноразовая миграция со старого stub+engine layout на single-app в /Applications.
/// Запускается при старте AppDelegate, идемпотентна через UserDefaults flag.
///
/// Старый layout (≤ v0.11.5):
///   /Applications/HWInstaller.app                          — stub-installer
///   ~/Library/Application Support/HelloWork/HelloWork.app  — engine, который stub скачивал
/// Новый layout (≥ v0.12):
///   /Applications/HelloWork.app                            — единственная аппа
///
/// Bundle ID `dev.helloworkapp.macos.engine` НЕ меняется, поэтому
/// TCC permissions и UserDefaults у существующих юзеров переживают миграцию.
@MainActor
enum MigrationManager {
    /// Флаг в UserDefaults: миграция отработала, повторно не запускать.
    static let migrationFlagKey = "helloWorkDistributionMigratedTo_0_12"

    /// Результат вызова: знает ли вызывающий, что миграция произошла.
    /// `.migrated` → AppDelegate должен будет дёрнуть UI-toast (TASK-A05+A07).
    enum Result {
        case migrated
        case alreadyDone
        case skippedNotInApplications
    }

    /// Запускается из AppDelegate.applicationDidFinishLaunching.
    /// Идемпотентна: повторный вызов после успеха — no-op.
    @discardableResult
    static func runIfNeeded(state: AppState) -> Result {
        let defaults = UserDefaults.standard

        if defaults.bool(forKey: migrationFlagKey) {
            devlog("migration", "already done, skip")
            return .alreadyDone
        }

        // Мигрируем только если запущены из /Applications. Из dev-сборки
        // (.build/release) или AppTranslocation — не наш кейс.
        let bundlePath = Bundle.main.bundleURL.path
        guard bundlePath.hasPrefix("/Applications/") else {
            devlog("migration", "skip: bundle is at \(bundlePath), not in /Applications")
            return .skippedNotInApplications
        }

        devlog("migration", "starting from bundle \(bundlePath)")

        let oldEngineURL = oldEnginePath
        let oldStubURL = oldStubPath

        // Step 1: удалить старую engine-копию из Application Support.
        if FileManager.default.fileExists(atPath: oldEngineURL.path) {
            do {
                try FileManager.default.removeItem(at: oldEngineURL)
                devlog("migration", "removed old engine at \(oldEngineURL.path)")
            } catch {
                devlog("migration", "failed to remove old engine: \(error.localizedDescription)")
            }
        } else {
            devlog("migration", "no old engine at \(oldEngineURL.path)")
        }

        // Step 2: переместить старый stub-installer в Trash (recycle, не permanent).
        if FileManager.default.fileExists(atPath: oldStubURL.path) {
            NSWorkspace.shared.recycle([oldStubURL]) { _, error in
                if let error = error {
                    devlog("migration", "failed to recycle HWInstaller: \(error.localizedDescription)")
                } else {
                    devlog("migration", "moved HWInstaller to Trash")
                }
            }
        } else {
            devlog("migration", "no HWInstaller at \(oldStubURL.path)")
        }

        // Step 3: SMAppService — была регистрация на путь старого engine; снимаем её.
        // После миграции юзер сам пере-включит «Launch at Login» из новых настроек,
        // которые покажут актуальный path.
        if SMAppService.mainApp.status == .enabled {
            state.setLaunchAtLogin(false)
            devlog("migration", "SMAppService unregistered (was bound to old engine path)")
        }

        // Step 4: фиксируем флаг + queueим toast.
        defaults.set(true, forKey: migrationFlagKey)
        state.queueMigrationToast = true
        devlog("migration", "completed, toast queued")
        return .migrated
    }

    // MARK: - Paths

    private static var oldEnginePath: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("HelloWork/HelloWork.app", isDirectory: true)
    }

    private static var oldStubPath: URL {
        URL(fileURLWithPath: "/Applications/HWInstaller.app", isDirectory: true)
    }
}
