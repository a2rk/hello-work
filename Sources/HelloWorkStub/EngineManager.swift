import AppKit
import Foundation

/// Скачивает и устанавливает engine из последнего GitHub Release.
@MainActor
final class EngineManager: ObservableObject {
    enum Status: Equatable {
        case idle
        case checking
        case downloading(Double)   // 0..1
        case mounting
        case copying
        case launching
        case ready
        case error(String)
    }

    @Published var status: Status = .idle

    /// `~/Library/Application Support/HelloWork/`
    static var supportDir: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return base.appendingPathComponent("HelloWork", isDirectory: true)
    }

    /// `~/Library/Application Support/HelloWork/HelloWork.app`
    static var engineAppURL: URL {
        supportDir.appendingPathComponent("HelloWork.app")
    }

    var engineInstalled: Bool {
        FileManager.default.fileExists(atPath: Self.engineAppURL.path)
    }

    private static let devLogURL = URL(string: "https://raw.githubusercontent.com/a2rk/hello-work/main/dev_log.json")!

    // MARK: - Bootstrap

    func bootstrap(force: Bool = false) async {
        do {
            if !force, engineInstalled {
                _ = await launchEngine()
                return
            }

            try FileManager.default.createDirectory(
                at: Self.supportDir,
                withIntermediateDirectories: true
            )

            status = .checking
            let dmgURL = try await fetchLatestDMGURL()

            let dmgFile = try await downloadDMG(from: dmgURL)
            defer { try? FileManager.default.removeItem(at: dmgFile) }

            status = .mounting
            let mountPoint = try mountDMG(at: dmgFile)
            defer { detachDMG(at: mountPoint) }

            status = .copying
            try copyEngine(fromMount: mountPoint)

            // Снимаем quarantine — мы скачали через URLSession без quarantine-флага,
            // но на всякий случай делаем явно.
            stripQuarantine()

            status = .launching
            let ok = await launchEngine()
            if ok {
                status = .ready
            } else {
                status = .error("Не удалось запустить engine.")
            }
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    // MARK: - Network

    private func fetchLatestDMGURL() async throws -> URL {
        var components = URLComponents(url: Self.devLogURL, resolvingAgainstBaseURL: false)!
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "_", value: "\(Int(Date().timeIntervalSince1970))"))
        components.queryItems = items
        let url = components.url ?? Self.devLogURL

        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: config)

        var req = URLRequest(url: url)
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (data, _) = try await session.data(for: req)

        struct Entry: Decodable {
            let version: String
            let dmgUrl: String
        }
        let entries = try JSONDecoder().decode([Entry].self, from: data)
        guard let first = entries.first, let parsed = URL(string: first.dmgUrl) else {
            throw NSError(domain: "Stub", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "dev_log.json пустой или битый."
            ])
        }
        return parsed
    }

    private func downloadDMG(from url: URL) async throws -> URL {
        status = .downloading(0)

        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config)

        let (asyncBytes, response) = try await session.bytes(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "Stub", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Не удалось скачать DMG (HTTP \(((response as? HTTPURLResponse)?.statusCode ?? -1))."
            ])
        }
        let total = response.expectedContentLength

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("hellowork-engine-\(UUID().uuidString).dmg")
        FileManager.default.createFile(atPath: tmp.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tmp)
        defer { try? handle.close() }

        var received: Int64 = 0
        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)

        for try await byte in asyncBytes {
            buffer.append(byte)
            received += 1
            if buffer.count >= 64 * 1024 {
                try handle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
                if total > 0 {
                    let progress = Double(received) / Double(total)
                    status = .downloading(progress)
                }
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
        }
        status = .downloading(1.0)
        return tmp
    }

    // MARK: - DMG operations

    private func mountDMG(at file: URL) throws -> URL {
        let mountPoint = FileManager.default.temporaryDirectory
            .appendingPathComponent("hw-mount-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)

        let task = Process()
        task.launchPath = "/usr/bin/hdiutil"
        task.arguments = [
            "attach",
            "-nobrowse",
            "-quiet",
            "-mountpoint", mountPoint.path,
            file.path
        ]
        let pipe = Pipe()
        task.standardError = pipe
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            let err = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw NSError(domain: "Stub", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "hdiutil attach failed: \(err)"
            ])
        }
        return mountPoint
    }

    private func detachDMG(at mountPoint: URL) {
        let task = Process()
        task.launchPath = "/usr/bin/hdiutil"
        task.arguments = ["detach", "-quiet", mountPoint.path]
        try? task.run()
        task.waitUntilExit()
    }

    private func copyEngine(fromMount mount: URL) throws {
        // Ищем .app внутри mount — обычно HelloWork.app или HelloWorkEngine.app.
        let candidates = ["HelloWork.app", "HelloWorkEngine.app"]
        var sourceURL: URL?
        for c in candidates {
            let u = mount.appendingPathComponent(c)
            if FileManager.default.fileExists(atPath: u.path) {
                sourceURL = u
                break
            }
        }
        guard let src = sourceURL else {
            throw NSError(domain: "Stub", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "В DMG нет HelloWork.app"
            ])
        }
        let dst = Self.engineAppURL
        if FileManager.default.fileExists(atPath: dst.path) {
            try FileManager.default.removeItem(at: dst)
        }
        try FileManager.default.copyItem(at: src, to: dst)
    }

    private func stripQuarantine() {
        let task = Process()
        task.launchPath = "/usr/bin/xattr"
        task.arguments = ["-dr", "com.apple.quarantine", Self.engineAppURL.path]
        try? task.run()
        task.waitUntilExit()
    }

    // MARK: - Launch

    func launchEngine() async -> Bool {
        let url = Self.engineAppURL
        guard FileManager.default.fileExists(atPath: url.path) else { return false }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.addsToRecentItems = false

        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: config
            ) { app, error in
                continuation.resume(returning: error == nil && app != nil)
            }
        }
    }
}
