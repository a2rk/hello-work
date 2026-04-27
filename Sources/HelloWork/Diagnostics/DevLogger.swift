import Foundation

/// Файловый логгер для разработческого режима.
/// Когда `enabled == false` — `log(...)` no-op, файл на диск не растёт.
/// Файл живёт в ~/Library/Application Support/HelloWork/devlog.txt
final class DevLogger: @unchecked Sendable {
    static let shared = DevLogger()

    let logURL: URL

    private let queue = DispatchQueue(label: "dev.helloworkapp.devlogger", qos: .utility)
    private let lock = NSLock()
    private var _enabled: Bool = false

    var enabled: Bool {
        get { lock.withLock { _enabled } }
        set {
            let was: Bool = lock.withLock { let p = _enabled; _enabled = newValue; return p }
            if newValue && !was {
                writeRaw("\n=== devlog enabled \(Self.timestamp()) ===\n")
            }
        }
    }

    private init() {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("HelloWork", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.logURL = dir.appendingPathComponent("devlog.txt")
    }

    func log(_ category: String, _ message: String) {
        guard enabled else { return }
        let line = "\(Self.timestamp()) [\(category)] \(message)\n"
        queue.async { [logURL] in
            Self.append(line, to: logURL)
        }
    }

    func clear() {
        queue.async { [logURL] in
            try? "".write(to: logURL, atomically: true, encoding: .utf8)
        }
    }

    /// Возвращает текущее содержимое файла. Тяжёлое чтение — не дёргать на каждый кадр.
    func readContents() -> String {
        queue.sync { [logURL] in
            (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        }
    }

    private func writeRaw(_ s: String) {
        queue.async { [logURL] in
            Self.append(s, to: logURL)
        }
    }

    /// Максимальный размер активного devlog.txt. При превышении делаем rotate:
    /// devlog.txt → devlog.txt.1 (старый .1 удаляется), новый append начинается
    /// с пустого файла. Один retained backup — не плодим бесконечно.
    private static let maxFileSize: Int = 10 * 1024 * 1024

    private static func append(_ s: String, to url: URL) {
        guard let data = s.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            // Проверяем размер — если перевалили порог, ротейтим перед записью.
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int,
               size + data.count > maxFileSize {
                rotate(at: url)
            }
            if let h = try? FileHandle(forWritingTo: url) {
                defer { try? h.close() }
                _ = try? h.seekToEnd()
                try? h.write(contentsOf: data)
            } else {
                // Файл могли удалить ротацией — пишем заново.
                try? data.write(to: url)
            }
        } else {
            try? data.write(to: url)
        }
    }

    private static func rotate(at url: URL) {
        let backup = url.appendingPathExtension("1")
        let fm = FileManager.default
        try? fm.removeItem(at: backup)        // старый .1 — выкидываем
        try? fm.moveItem(at: url, to: backup) // текущий → .1
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func timestamp() -> String {
        formatter.string(from: Date())
    }
}

/// Удобная функция-шорткат. autoclosure — чтобы строки не строились,
/// когда логгер выключен.
@inline(__always)
func devlog(_ category: String, _ message: @autoclosure () -> String) {
    guard DevLogger.shared.enabled else { return }
    DevLogger.shared.log(category, message())
}
