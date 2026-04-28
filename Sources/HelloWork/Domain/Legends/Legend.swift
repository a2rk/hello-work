import Foundation

/// Локализованная пара ru/en — основная пара в JSON исходных файлов.
/// zh-фолбэк решается на UI-уровне (см. legendLocalized helper в Phase H).
struct LocalizedRuEn: Codable, Hashable {
    let ru: String
    let en: String
}

/// Один временной блок в 24-часовом расписании легенды (`HH:mm` — `HH:mm`).
/// Все блоки — non-wrap (24:00 = конец суток, не следующий день).
struct LegendBlock: Codable, Hashable {
    let start: String      // "HH:mm"
    let end: String        // "HH:mm"
    let type: LegendBlockType
    let label: LocalizedRuEn
}

/// Источник биографии — книга/статья/интервью с публичным URL.
struct LegendSource: Codable, Hashable, Identifiable {
    let type: String       // "book" / "article" / "interview" / "letter" / ...
    let title: String
    let author: String
    let url: String

    var id: String { url + title }
}

/// Окно когда мессенджеры (work/personal) разрешены — мапится в Slot[]
/// при apply легенды к managed app.
struct LegendAllowedSlot: Codable, Hashable, Identifiable {
    let start: String              // "HH:mm"
    let end: String                // "HH:mm"
    let appliesTo: [String]        // "work_messengers" | "personal_messengers"
    let rationale: LocalizedRuEn

    var id: String { start + "-" + end + appliesTo.joined() }
}

/// Расписание для коммуникаций в формате легенды.
struct LegendBlockSchedule: Codable, Hashable {
    let description: LocalizedRuEn
    let allowedSlots: [LegendAllowedSlot]
    let totalAllowedMinutes: Int
}

/// Полное 24-часовое расписание дня легенды.
struct LegendLifeSchedule: Codable, Hashable {
    let morningQuestion: LocalizedRuEn?
    let eveningQuestion: LocalizedRuEn?
    let blocks: [LegendBlock]
}

/// Цитата легенды.
struct LegendQuote: Codable, Hashable, Identifiable {
    let ru: String
    let en: String

    var id: String { en + ru }
}

/// Корневой объект легенды — соответствует одному JSON-файлу в Resources/Legends/.
struct Legend: Codable, Hashable, Identifiable {
    let id: String
    let order: Int
    let name: LocalizedRuEn
    let fullName: LocalizedRuEn
    let yearsOfLife: String
    let era: String
    let field: String
    let tags: [String]
    let nationality: String
    let avatarUrl: String?
    let intensity: Int               // 1...5
    let bio: LocalizedRuEn
    let sources: [LegendSource]
    let lifeSchedule: LegendLifeSchedule
    let blockSchedule: LegendBlockSchedule
    let quotes: [LegendQuote]
}
