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

    /// Case-insensitive substring search по name(ru/en) + fullName + tags + bio.
    /// Пустой query → возвращаем `all`.
    func search(_ query: String) -> [Legend] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { legend in
            if legend.name.ru.lowercased().contains(q) { return true }
            if legend.name.en.lowercased().contains(q) { return true }
            if legend.fullName.ru.lowercased().contains(q) { return true }
            if legend.fullName.en.lowercased().contains(q) { return true }
            if legend.tags.contains(where: { $0.lowercased().contains(q) }) { return true }
            if legend.bio.ru.lowercased().contains(q) { return true }
            if legend.bio.en.lowercased().contains(q) { return true }
            return false
        }
    }

    /// Композитный фильтр. nil-аргументы пропускаются.
    func filter(
        era: String? = nil,
        field: String? = nil,
        tag: String? = nil,
        intensity: ClosedRange<Int>? = nil
    ) -> [Legend] {
        all.filter { legend in
            if let e = era, legend.era != e { return false }
            if let f = field, legend.field != f { return false }
            if let t = tag, !legend.tags.contains(t) { return false }
            if let r = intensity, !r.contains(legend.intensity) { return false }
            return true
        }
    }

    /// Доступные сорт-варианты в Legends UI.
    enum SortOrder {
        case order                      // по полю `order` (default)
        case alphabetical(LocalizedRuEnLocale)
        case favoritesFirst(Set<String>)  // ID'ы избранных
    }

    enum LocalizedRuEnLocale {
        case ru, en
    }

    func sort(_ items: [Legend], by order: SortOrder) -> [Legend] {
        switch order {
        case .order:
            return items.sorted { $0.order < $1.order }
        case .alphabetical(.ru):
            return items.sorted { $0.name.ru.localizedCompare($1.name.ru) == .orderedAscending }
        case .alphabetical(.en):
            return items.sorted { $0.name.en.localizedCompare($1.name.en) == .orderedAscending }
        case .favoritesFirst(let favs):
            return items.sorted { lhs, rhs in
                let lf = favs.contains(lhs.id)
                let rf = favs.contains(rhs.id)
                if lf != rf { return lf }            // favorites first
                return lhs.order < rhs.order          // ties → by order
            }
        }
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
