import SwiftUI
import AppKit

struct StatsView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    @ObservedObject var stats: StatsCollector

    @State private var range: StatsRange = .today

    init(state: AppState) {
        self.state = state
        self.stats = state.stats
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header

            if isEmpty {
                emptyView
            } else {
                StatsHeroView(
                    attempts: snapshot.totalAttempts,
                    blockedSeconds: snapshot.aggregate.blockedSeconds,
                    comparisonText: snapshot.comparisonText
                )

                section(title: t.statsSectionWhen) {
                    StatsHourlyChart(
                        hours: snapshot.aggregate.hourlyAttempts,
                        currentHour: range == .today ? Calendar.current.component(.hour, from: Date()) : nil
                    )
                }

                if !snapshot.appRows.isEmpty {
                    section(title: t.statsSectionWhere) {
                        StatsAppBreakdown(rows: snapshot.appRows)
                    }
                }

                section(title: t.statsSectionHow) {
                    StatsMethodGrid(stat: snapshot.aggregate)
                }

                section(title: t.statsSectionGrace) {
                    StatsGraceCard(
                        count: snapshot.aggregate.graceUsedCount,
                        totalSeconds: snapshot.aggregate.graceUsedSeconds
                    )
                }

                section(title: t.statsSectionYear) {
                    StatsHeatmap(
                        cells: heatmapCells,
                        maxValue: heatmapMaxValue
                    )
                }
            }

            Text(t.statsPrivacyNote)
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(t.statsTitle)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text(t.statsSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            rangePicker
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 4) {
            ForEach(StatsRange.allCases) { r in
                Button {
                    range = r
                } label: {
                    Text(r.title(t))
                        .font(.system(size: 11, weight: range == r ? .semibold : .regular))
                        .foregroundColor(range == r ? .white : Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(range == r ? Color.white.opacity(0.10) : Color.clear)
                        )
                        .overlay(
                            Capsule().stroke(
                                range == r ? Theme.surfaceStroke : Color.clear,
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.03)))
        .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t.statsEmptyTitle)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
            Text(t.statsEmptyHint)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 60)
    }

    // MARK: - Section helper

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Theme.textTertiary)
            content()
        }
        .frame(maxWidth: Layout.settingsCardMaxWidth, alignment: .leading)
    }

    // MARK: - Snapshot

    private struct Snapshot {
        let aggregate: DailyStat
        let totalAttempts: Int
        let appRows: [StatsAppBreakdownRow]
        let comparisonText: String?
    }

    private var snapshot: Snapshot {
        let interval = range.interval()
        let perBundle = stats.store.aggregate(from: interval.start, to: interval.end)

        // Сумма по всему периоду + apps breakdown (без grace bundleID).
        var total = DailyStat()
        var appsAggregate: [(bundleID: String, stat: DailyStat)] = []
        for (bid, stat) in perBundle {
            total = total + stat
            if bid == StatsCollector.graceBundleID { continue }
            appsAggregate.append((bid, stat))
        }

        let totalAttempts = appsAggregate.map(\.stat.totalAttempts).reduce(0, +)
        let appRows: [StatsAppBreakdownRow] = appsAggregate
            .filter { $0.stat.totalAttempts > 0 }
            .sorted { $0.stat.totalAttempts > $1.stat.totalAttempts }
            .map { item in
                let percent = totalAttempts > 0
                    ? Int((Double(item.stat.totalAttempts) / Double(totalAttempts) * 100).rounded())
                    : 0
                let known = state.managedApps.first(where: { $0.bundleID == item.bundleID })
                return StatsAppBreakdownRow(
                    id: item.bundleID,
                    name: known?.name ?? item.bundleID,
                    icon: known?.icon,
                    attempts: item.stat.totalAttempts,
                    percent: percent,
                    isOwnApp: item.bundleID == Bundle.main.bundleIdentifier
                )
            }

        return Snapshot(
            aggregate: total,
            totalAttempts: totalAttempts,
            appRows: appRows,
            comparisonText: comparisonText(currentTotal: totalAttempts)
        )
    }

    private var isEmpty: Bool {
        snapshot.totalAttempts == 0
            && snapshot.aggregate.peeks == 0
            && snapshot.aggregate.blockedSeconds == 0
            && snapshot.aggregate.graceUsedCount == 0
    }

    // MARK: - Comparison

    private func comparisonText(currentTotal: Int) -> String? {
        let cal = Calendar.current
        let now = Date()
        let current = range.interval(now: now)

        // Длина периода в днях (включительно).
        guard let days = cal.dateComponents([.day], from: current.start, to: current.end).day else { return nil }
        let length = days + 1

        // Предыдущий период такой же длины.
        guard let prevEnd = cal.date(byAdding: .day, value: -length, to: current.end),
              let prevStart = cal.date(byAdding: .day, value: -(length * 2 - 1), to: current.end) else {
            return nil
        }
        let prev = stats.store.aggregate(from: prevStart, to: prevEnd)
        let prevTotal = prev
            .filter { $0.key != StatsCollector.graceBundleID }
            .values
            .map(\.totalAttempts)
            .reduce(0, +)

        if prevTotal == 0 && currentTotal == 0 { return nil }
        if prevTotal == 0 { return t.statsCompareNoData }

        let diff = currentTotal - prevTotal
        if diff == 0 { return t.statsCompareEqual }

        let percent = Int((Double(abs(diff)) / Double(prevTotal) * 100).rounded())
        return diff > 0 ? t.statsCompareUp(percent) : t.statsCompareDown(percent)
    }

    // MARK: - Heatmap

    private var heatmapCells: [[HeatmapCell]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Для heatmap всегда показываем последние 53 недели независимо от выбранного range.
        // Конец heatmap — конец текущей недели, начало — 53*7 дней назад от него.
        let weekday = cal.component(.weekday, from: today)
        // Сдвигаем конец недели на воскресенье (weekday=1 в Gregorian) или субботу — берём последний день недели.
        // Apple Health/Screen Time показывают календарную неделю до воскресенья.
        let firstWeekday = cal.firstWeekday          // 1=вс или 2=пн
        let lastWeekdayIndex = (firstWeekday + 5) % 7 + 1   // последний день недели
        let daysToEndOfWeek = (lastWeekdayIndex - weekday + 7) % 7

        guard let endOfWeek = cal.date(byAdding: .day, value: daysToEndOfWeek, to: today),
              let start = cal.date(byAdding: .day, value: -(53 * 7 - 1), to: endOfWeek) else {
            return []
        }

        var weeks: [[HeatmapCell]] = []
        for w in 0..<53 {
            var col: [HeatmapCell] = []
            for d in 0..<7 {
                let dayOffset = w * 7 + d
                guard let date = cal.date(byAdding: .day, value: dayOffset, to: start) else { continue }
                let dayKey = StatsStore.dayKey(date)
                let value = (stats.store.days[dayKey] ?? [:])
                    .filter { $0.key != StatsCollector.graceBundleID }
                    .values
                    .map(\.totalAttempts)
                    .reduce(0, +)
                let isFuture = date > today
                let label = StatsFormatters.date(date, language: state.language)
                col.append(HeatmapCell(date: date, dateLabel: label, value: value, isFuture: isFuture))
            }
            weeks.append(col)
        }
        return weeks
    }

    private var heatmapMaxValue: Int {
        var maxV = 0
        for week in heatmapCells {
            for cell in week where !cell.isFuture {
                if cell.value > maxV { maxV = cell.value }
            }
        }
        return maxV
    }
}
