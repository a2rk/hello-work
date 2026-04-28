import Foundation
import AppKit

/// Скачивает свежий DMG → монтирует → запускает детач-скрипт, который дождётся
/// нашего exit, заменит .app в /Applications и перезапустит приложение.
@MainActor
final class UpdateInstaller: ObservableObject {
    enum Status: Equatable {
        case idle
        case downloading
        case installing
        case relaunching
        case failed(String)
    }

    @Published var status: Status = .idle

    /// Можем ли мы заменять собственный .app? Нет, если запущены через AppTranslocation,
    /// из dev-сборки, или вообще не из .app-бандла.
    nonisolated static var canSelfInstall: Bool {
        let path = Bundle.main.bundleURL.path
        if path.contains("/AppTranslocation/") { return false }
        if path.contains("/.build/") { return false }
        guard path.hasSuffix(".app") else { return false }
        let parent = Bundle.main.bundleURL.deletingLastPathComponent().path
        return FileManager.default.isWritableFile(atPath: parent)
    }

    func install(dmgUrl: URL) async {
        status = .downloading
        do {
            let dmg = try await downloadDMG(dmgUrl)
            status = .installing
            let mount = try mountDMG(at: dmg)
            guard let newApp = findApp(in: mount) else {
                throw UpdateError.appNotFoundInDMG
            }
            try spawnHelperAndExit(
                newApp: newApp,
                target: Bundle.main.bundleURL,
                mount: mount,
                dmgFile: dmg
            )
            status = .relaunching
            // App завершит работу через NSApp.terminate в spawnHelperAndExit.
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func reset() {
        status = .idle
    }

    /// Проверяется при старте — был ли провал предыдущего apply-update'а?
    /// Helper-скрипт пишет статус в `/tmp/hellowork-update-status`. Если там
    /// что-то отличное от "ok" — поднимаем .failed чтобы UI показал.
    /// Файл удаляется после чтения.
    func consumePreviousUpdateStatus() {
        let path = "/tmp/hellowork-update-status"
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != "ok" && !trimmed.isEmpty {
            let msg: String
            switch trimmed {
            case "rm-failed":     msg = "Не удалось снести старый .app для замены"
            case "cp-failed":     msg = "Не удалось скопировать новый .app — старый удалён, fallback в /Applications/HelloWork-fallback.app"
            case "parent-stuck":  msg = "Предыдущий процесс не закрылся за 30с — обновление отменено"
            default:              msg = "Update failed: \(trimmed)"
            }
            status = .failed(msg)
        }
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - Steps

    private func downloadDMG(_ url: URL) async throws -> URL {
        let (tmp, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.downloadFailed
        }
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("hellowork-update-\(UUID().uuidString).dmg")
        try FileManager.default.moveItem(at: tmp, to: dest)
        return dest
    }

    private func mountDMG(at dmgURL: URL) throws -> URL {
        let task = Process()
        task.launchPath = "/usr/bin/hdiutil"
        task.arguments = ["attach", "-nobrowse", "-noverify", "-mountrandom", "/tmp", dmgURL.path]

        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = Pipe()

        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw UpdateError.mountFailed
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw UpdateError.mountFailed
        }

        // Каждая строка: поля через TAB. Последняя — точка монтирования (если есть).
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            if let last = parts.last, last.hasPrefix("/"), last != dmgURL.path {
                return URL(fileURLWithPath: last)
            }
        }
        throw UpdateError.mountFailed
    }

    private func findApp(in mountPoint: URL) -> URL? {
        let contents = try? FileManager.default.contentsOfDirectory(
            at: mountPoint,
            includingPropertiesForKeys: nil
        )
        return contents?.first { $0.pathExtension == "app" }
    }

    private func spawnHelperAndExit(newApp: URL, target: URL, mount: URL, dmgFile: URL) throws {
        let pid = ProcessInfo.processInfo.processIdentifier

        let scriptPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("hellowork-update-\(UUID().uuidString).sh")

        let script = #"""
        #!/bin/bash
        set -u
        PARENT_PID="$1"
        SOURCE="$2"
        TARGET="$3"
        MOUNT="$4"
        DMG="$5"

        LOGFILE="/tmp/hellowork-update.log"
        STATUSFILE="/tmp/hellowork-update-status"

        log() { echo "$(date +%H:%M:%S) $*" >> "$LOGFILE"; }

        log "spawned for parent $PARENT_PID"

        # Ждём, пока родитель не умрёт (с deadline 30с — Sequoia может отказать в exit
        # если что-то держит. Не висим вечно).
        DEADLINE=$((SECONDS + 30))
        while kill -0 "$PARENT_PID" 2>/dev/null; do
            if [ $SECONDS -ge $DEADLINE ]; then
                log "parent didn't exit within 30s — abort"
                echo "parent-stuck" > "$STATUSFILE"
                exit 0
            fi
            sleep 0.2
        done
        sleep 0.5

        # Заменяем .app
        if ! rm -rf "$TARGET"; then
            log "rm -rf '$TARGET' failed (rc=$?)"
            echo "rm-failed" > "$STATUSFILE"
            open "$TARGET" 2>/dev/null
            exit 1
        fi
        if ! cp -R "$SOURCE" "$TARGET"; then
            log "cp -R '$SOURCE' '$TARGET' failed (rc=$?)"
            echo "cp-failed" > "$STATUSFILE"
            # Старый .app уже удалён — пытаемся хотя бы DMG-app оставить как fallback.
            cp -R "$SOURCE" "/Applications/HelloWork-fallback.app" 2>/dev/null
            exit 1
        fi

        # Снимаем quarantine + перепрописываем подпись (используем ту же
        # self-signed identity если есть, иначе ad-hoc).
        xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true
        SIGN_HASH=$(security find-identity -p codesigning ~/Library/Keychains/login.keychain-db 2>/dev/null \
            | awk -v name="HelloWork Self-Signed" '$0 ~ name {print $2; exit}')
        if [ -n "$SIGN_HASH" ]; then
            codesign --force --deep --sign "$SIGN_HASH" "$TARGET" 2>>"$LOGFILE" || true
        else
            codesign --force --deep --sign - "$TARGET" 2>>"$LOGFILE" || true
        fi

        log "replaced OK, launching"
        echo "ok" > "$STATUSFILE"
        open "$TARGET"

        # Cleanup
        hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
        rm -f "$DMG"
        rm -- "$0"
        """#

        try script.write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptPath.path
        )

        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = [
            scriptPath.path,
            "\(pid)",
            newApp.path,
            target.path,
            mount.path,
            dmgFile.path
        ]
        task.standardOutput = nil
        task.standardError = nil
        try task.run()

        // Даём пару миллисекунд скрипту встать в работу — и завершаемся.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.terminate(nil)
        }
    }
}

enum UpdateError: LocalizedError {
    case downloadFailed
    case mountFailed
    case appNotFoundInDMG

    var errorDescription: String? {
        switch self {
        case .downloadFailed:    return "Не удалось скачать обновление"
        case .mountFailed:       return "Не удалось смонтировать DMG"
        case .appNotFoundInDMG:  return ".app не найден внутри DMG"
        }
    }
}
