import Foundation
import AppKit

/// Спавнит детач-bash-процесс, который ждёт смерти текущего PID,
/// потом запускает /Applications/HelloWork.app снова.
/// Используется когда мы знаем что macOS сейчас убьёт нас (после grant TCC).
enum AutoRelauncher {
    static func armRelaunchAfterDeath() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appPath = Bundle.main.bundlePath

        // bash скрипт: kill -0 проверяет жив ли PID. После смерти — open app.
        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.4; done
        sleep 0.6
        /usr/bin/open "\(appPath)"
        """

        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", script]

        // Детач — отключаем стандартные потоки и не ждём.
        let null = FileHandle(forWritingAtPath: "/dev/null")
        if let null {
            task.standardOutput = null
            task.standardError = null
        }

        do {
            try task.run()
        } catch {
            // Best-effort — если не получилось, юзер запустит сам.
        }
    }
}
