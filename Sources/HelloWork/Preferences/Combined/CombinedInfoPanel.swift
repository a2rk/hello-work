import SwiftUI
import AppKit

/// Live-инфо: что сейчас разрешено/заблокировано, когда следующее изменение, итого часов/день.
struct CombinedInfoPanel: View {
    @Environment(\.t) var t
    let apps: [ManagedApp]
    let now: Date

    private var allowedNow: [ManagedApp] {
        apps.filter { isAllowed($0, at: now) }
    }
    private var blockedNow: [ManagedApp] {
        apps.filter { !isAllowed($0, at: now) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            currentRow
            if let nextChange = nextChangeText() {
                divider
                Text(nextChange)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            divider
            Text(totalAllowedText)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.surfaceStroke, lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.surfaceStroke)
            .frame(height: 1)
    }

    // MARK: - Current

    private var currentRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t.combinedNowAllowed.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundColor(Theme.accent.opacity(0.85))
                    appPillsRow(apps: allowedNow, fallback: t.combinedNobody)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(t.combinedNowBlocked.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundColor(Theme.textTertiary)
                    appPillsRow(apps: blockedNow, fallback: t.combinedNobody)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func appPillsRow(apps: [ManagedApp], fallback: String) -> some View {
        Group {
            if apps.isEmpty {
                Text(fallback)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 100), spacing: 4, alignment: .leading)],
                    alignment: .leading,
                    spacing: 4
                ) {
                    ForEach(apps) { app in
                        appPill(app)
                    }
                }
            }
        }
    }

    private func appPill(_ app: ManagedApp) -> some View {
        HStack(spacing: 5) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 12, height: 12)
            Text(app.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(AppPalette.color(for: app.bundleID).opacity(0.20))
        )
        .overlay(
            Capsule().stroke(AppPalette.color(for: app.bundleID).opacity(0.45), lineWidth: 1)
        )
    }

    // MARK: - Next change

    private func nextChangeText() -> String? {
        let cal = Calendar.current
        let curMinute = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)

        var best: (minutes: Int, app: ManagedApp, willBlock: Bool)? = nil
        for app in apps {
            guard let next = nextChangeMinute(for: app, from: curMinute) else { continue }
            let delta = (next - curMinute + minutesInDay) % minutesInDay
            if delta == 0 { continue }
            if best == nil || delta < best!.minutes {
                let willBlock = isAllowed(app, atMinute: curMinute)   // меняется на противоположное
                best = (delta, app, willBlock)
            }
        }
        guard let b = best else { return nil }
        return t.combinedNextChange(b.app.name, b.minutes, b.willBlock)
    }

    /// Минута следующего "перехода" (вход или выход слота) для приложения, начиная с from.
    private func nextChangeMinute(for app: ManagedApp, from: Int) -> Int? {
        var transitions = Set<Int>()
        for slot in app.slots {
            transitions.insert(slot.startMinutes % minutesInDay)
            transitions.insert(slot.endMinutes % minutesInDay)
        }
        if transitions.isEmpty { return nil }

        let sorted = transitions.sorted()
        // Найти первый > from. Если нет — берём первый (через полночь).
        if let next = sorted.first(where: { $0 > from }) {
            return next
        }
        return sorted.first
    }

    // MARK: - Total

    private var totalAllowedText: String {
        var totalMinutes = 0
        for app in apps {
            for slot in app.slots {
                totalMinutes += slot.lengthMinutes
            }
        }
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return t.combinedTotalAllowed(h, m, apps.count)
    }

    // MARK: - Helpers

    private func isAllowed(_ app: ManagedApp, at date: Date) -> Bool {
        let cal = Calendar.current
        let m = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
        return isAllowed(app, atMinute: m)
    }

    private func isAllowed(_ app: ManagedApp, atMinute m: Int) -> Bool {
        app.slots.contains { $0.contains(minute: m) }
    }
}

