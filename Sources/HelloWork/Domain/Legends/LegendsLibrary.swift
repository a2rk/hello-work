import Foundation

/// Eager-load 60 JSON-файлов из bundle при первом обращении к `shared`.
/// Один битый файл не валит модуль — он попадает в `corruptIds`,
/// остальные доступны через `all`.
final class LegendsLibrary {
    static let shared = LegendsLibrary()

    /// Все легенды, отсортированные по `order` (и доп. по `id` для стабильности).
    let all: [Legend]

    /// IDs (filename stem без `.json`) JSON-файлов которые не съелись JSONDecoder'ом.
    let corruptIds: Set<String>

    private init() {
        let (legends, corrupt) = Self.loadFromBundle()
        self.all = legends.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id < rhs.id
        }
        self.corruptIds = corrupt
        devlog("legends",
               "library loaded — \(legends.count) legends, \(corrupt.count) corrupt")
    }

    func byID(_ id: String) -> Legend? {
        all.first { $0.id == id }
    }

    private static func loadFromBundle() -> ([Legend], Set<String>) {
        guard let urls = Bundle.module.urls(
            forResourcesWithExtension: "json",
            subdirectory: "Legends"
        ) else {
            devlog("legends", "bundle has no Legends/ subdir or empty — 0 loaded")
            return ([], [])
        }
        var legends: [Legend] = []
        var corrupt: Set<String> = []
        let decoder = JSONDecoder()
        for url in urls {
            let stem = url.deletingPathExtension().lastPathComponent
            do {
                let data = try Data(contentsOf: url)
                let legend = try decoder.decode(Legend.self, from: data)
                legends.append(legend)
            } catch {
                corrupt.insert(stem)
                devlog("legends", "FAILED decode \(stem): \(error.localizedDescription)")
            }
        }
        return (legends, corrupt)
    }
}
