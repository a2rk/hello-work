import Foundation

/// Категория, в которую юзер кладёт managed-app при apply легенды.
/// Определяет какие из `legend.blockSchedule.allowedSlots` ему достанутся.
enum LegendApplyCategory: String, Codable {
    case skip       // не трогать app
    case work       // мессенджеры для работы (Slack, Linear, ...)
    case personal   // личные мессенджеры (Telegram, iMessage, ...)
}

/// Apply / revert расписания легенды на managed apps.
/// Чистая логика, не SwiftUI. Все мутации идут через AppState helpers
/// чтобы persist-цепочка была одинаковой с UI-вмешательством.
@MainActor
enum LegendApplyEngine {
    /// Применить расписание легенды. Для каждого app в `assignments` с
    /// category != .skip:
    ///   1. Сохраняет snapshot текущих slots в backup;
    ///   2. Заменяет slots на slots, выведенные из allowedSlots легенды.
    /// После — `state.appliedLegendId = legend.id`, `state.slotsBackupForApply = backup`.
    ///
    /// Chained-apply guard (TASK-L77 + L76 verify): если уже applied любая
    /// легенда (даже та же самая с другими assignments) — auto-revert текущую
    /// перед apply'ем, чтобы новый backup содержал ОРИГИНАЛЬНЫЕ slots, а не
    /// post-prev snapshot. Re-apply того же legend с новыми категориями тоже
    /// требует revert, иначе backup испортится.
    static func apply(
        _ legend: Legend,
        assignments: [String: LegendApplyCategory],
        state: AppState
    ) {
        if let prev = state.appliedLegendId {
            devlog("legends", "apply '\(legend.id)' — auto-revert previous '\(prev)' (same: \(prev == legend.id))")
            revert(state: state)
        }
        var backup: [String: [Slot]] = [:]
        for (bid, category) in assignments where category != .skip {
            guard let idx = state.managedApps.firstIndex(where: { $0.bundleID == bid }) else {
                continue
            }
            backup[bid] = state.managedApps[idx].slots
            let newSlots = slotsFor(legend: legend, category: category)
            state.managedApps[idx].slots = newSlots
        }
        guard !backup.isEmpty else {
            devlog("legends", "apply '\(legend.id)' — assignments пустые, skip")
            return
        }
        state._setLegendsApply(legendId: legend.id, backup: backup)
        devlog("legends",
               "apply '\(legend.id)' — \(backup.count) apps, slots overwritten")
    }

    /// Откат предыдущего apply. Восстанавливает slots из backup, очищает state.
    /// Если backup nil/пуст — slots не трогаем, но appliedLegendId всё равно
    /// чистим: иначе banner с Revert-кнопкой останется навсегда (corrupt state).
    static func revert(state: AppState) {
        if let backup = state.slotsBackupForApply, !backup.isEmpty {
            for (bid, slots) in backup {
                guard let idx = state.managedApps.firstIndex(where: { $0.bundleID == bid }) else {
                    continue
                }
                state.managedApps[idx].slots = slots
            }
            devlog("legends", "revert — restored \(backup.count) apps from backup")
        } else {
            devlog("legends", "revert — backup пустой, slots оставлены, appliedLegendId чистим")
        }
        state._setLegendsApply(legendId: nil, backup: nil)
    }

    /// Конструирует Slot[] из `legend.blockSchedule.allowedSlots`, отфильтрованных
    /// по нужной категории. "HH:mm" → minutes-of-day.
    static func slotsFor(legend: Legend, category: LegendApplyCategory) -> [Slot] {
        let appliesToKey: String
        switch category {
        case .work:     appliesToKey = "work_messengers"
        case .personal: appliesToKey = "personal_messengers"
        case .skip:     return []
        }
        return legend.blockSchedule.allowedSlots
            .filter { $0.appliesTo.contains(appliesToKey) }
            .compactMap { allowed in
                guard let s = parseHHmm(allowed.start),
                      let e = parseHHmm(allowed.end),
                      e > s else { return nil }
                return Slot(id: UUID(), startMinutes: s, endMinutes: e)
            }
    }

    /// "HH:mm" → minutes-of-day. nil при невалидном формате.
    private static func parseHHmm(_ s: String) -> Int? {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        return h * 60 + m
    }
}
