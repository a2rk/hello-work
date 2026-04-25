import SwiftUI

struct ScheduleView: View {
    @ObservedObject var state: AppState
    let bundleID: String
    @State private var dragMode: DragMode?
    @State private var lastDragAngle: Double = 0
    @State private var dragAccumulated: Double = 0
    @State private var showArchiveAlert = false
    @State private var showDeleteAlert = false
    @State private var showClearAlert = false

    private var managedApp: ManagedApp? {
        state.managedApps.first(where: { $0.bundleID == bundleID })
    }

    private var slots: [Slot] {
        managedApp?.slots ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            HStack(alignment: .top, spacing: 28) {
                chart
                    .frame(width: Layout.chartSize, height: Layout.chartSize)
                slotsColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .alert("Архивировать «\(managedApp?.name ?? "")»?", isPresented: $showArchiveAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Архивировать") {
                state.archiveApp(bundleID: bundleID)
            }
        } message: {
            Text("Расписание сохранится. Можно вернуть из бокового меню.")
        }
        .alert("Удалить «\(managedApp?.name ?? "")» навсегда?", isPresented: $showDeleteAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                state.removeManagedApp(bundleID: bundleID)
            }
        } message: {
            Text("Расписание исчезнет без следа.")
        }
        .alert("Очистить все слоты?", isPresented: $showClearAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Очистить", role: .destructive) {
                state.clearSlots(forApp: bundleID)
            }
        } message: {
            Text("Все временные окна будут удалены.")
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        if let app = managedApp {
            HStack(alignment: .center, spacing: 12) {
                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 44, height: 44)
                    .opacity(app.isArchived ? 0.45 : 1)
                    .help(app.bundleID)

                Text(app.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(app.isArchived ? Theme.textSecondary : .white)
                    .strikethrough(app.isArchived, color: Theme.textTertiary)

                Spacer()

                if app.isArchived {
                    archivedBadge
                    Button("Вернуть") {
                        state.unarchiveApp(bundleID: bundleID)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
                    .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))

                    Button {
                        showDeleteAlert = true
                    } label: {
                        Text("Удалить навсегда")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.danger)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.danger.opacity(0.10)))
                            .overlay(Capsule().stroke(Theme.danger.opacity(0.30), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                } else {
                    statusPill
                    Button {
                        showArchiveAlert = true
                    } label: {
                        Image(systemName: "archivebox")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.05)))
                            .overlay(Circle().stroke(Theme.surfaceStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Архивировать")
                }
            }
        }
    }

    private var archivedBadge: some View {
        Text("В АРХИВЕ")
            .font(.system(size: 9, weight: .semibold))
            .tracking(1.2)
            .foregroundColor(Theme.textTertiary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.05)))
            .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
    }

    private var statusPill: some View {
        let isAllowed = managedApp.map { state.isAllowed(app: $0) } ?? false
        let color = isAllowed ? Theme.accent : Theme.danger
        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(isAllowed ? "Разрешено" : "Заблокировано")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.04))
                .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
        )
    }

    // MARK: - Chart

    private var chart: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let centerlineRadius = size * 0.40
            let ringThickness = size * 0.20
            let centerlineSize = centerlineRadius * 2

            ZStack {
                Circle()
                    .stroke(Theme.danger.opacity(0.22),
                            style: StrokeStyle(lineWidth: ringThickness, lineCap: .butt))
                    .frame(width: centerlineSize, height: centerlineSize)

                ForEach(slots) { slot in
                    let segs = arcSegments(rawStart: slot.startMinutes, rawEnd: slot.endMinutes)
                    ForEach(Array(segs.enumerated()), id: \.offset) { _, seg in
                        arc(start: seg.0, end: seg.1,
                            thickness: ringThickness, size: centerlineSize,
                            color: Theme.accent.opacity(0.70))
                            .contextMenu {
                                Button("Уменьшить на 10 мин") { adjustSlot(slot, by: -10) }
                                Button("Увеличить на 10 мин") { adjustSlot(slot, by: 10) }
                                Divider()
                                Button("Удалить", role: .destructive) {
                                    state.removeSlot(fromApp: bundleID, id: slot.id)
                                }
                            }
                    }
                }

                if case let .create(s, e) = dragMode, abs(e - s) >= snapMinutes {
                    let segs = arcSegments(rawStart: s, rawEnd: e)
                    ForEach(Array(segs.enumerated()), id: \.offset) { _, seg in
                        arc(start: seg.0, end: seg.1,
                            thickness: ringThickness, size: centerlineSize,
                            color: Theme.accent.opacity(0.45))
                    }
                }

                let labelRadius = centerlineRadius + ringThickness / 2 + 14

                ForEach(slots) { slot in
                    edgeDot(at: slot.startMinutes, center: center, radius: centerlineRadius)
                    edgeDot(at: slot.endMinutes, center: center, radius: centerlineRadius)
                    edgeLabel(at: slot.startMinutes, center: center, radius: labelRadius)
                    edgeLabel(at: slot.endMinutes, center: center, radius: labelRadius)
                }

                if case let .create(s, e) = dragMode, abs(e - s) >= snapMinutes {
                    edgeLabel(at: displayMinute(s), center: center, radius: labelRadius)
                    edgeLabel(at: displayMinute(e), center: center, radius: labelRadius)
                }

                ForEach(0..<24, id: \.self) { hour in
                    Rectangle()
                        .fill(Color.white.opacity(hour % 6 == 0 ? 0.65 : 0.18))
                        .frame(width: 1, height: hour % 6 == 0 ? 10 : 5)
                        .offset(y: -(centerlineRadius + ringThickness / 2 + 5))
                        .rotationEffect(.degrees(Double(hour) / 24.0 * 360.0))
                }

                ForEach([0, 6, 12, 18], id: \.self) { hour in
                    Text(String(format: "%02d", hour))
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))
                        .position(hourLabelPos(hour: hour, center: center,
                                               radius: centerlineRadius + ringThickness / 2 + 22))
                }

                nowMarker(center: center,
                          radius: centerlineRadius + ringThickness / 2 + 6)

                VStack(spacing: 2) {
                    Text(formatMinutes(totalAllowedMinutes))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    Text("в день")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        handleDragChanged(at: v.location, center: center)
                    }
                    .onEnded { _ in
                        handleDragEnded()
                    }
            )
        }
    }

    private func arc(start: Int, end: Int, thickness: CGFloat, size: CGFloat, color: Color) -> some View {
        Circle()
            .trim(from: CGFloat(start) / CGFloat(minutesInDay),
                  to: CGFloat(end) / CGFloat(minutesInDay))
            .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-90))
    }

    private func edgeDot(at minute: Int, center: CGPoint, radius: CGFloat) -> some View {
        let p = positionForMinute(minute, center: center, radius: radius)
        return Circle()
            .fill(Color.white)
            .frame(width: 6, height: 6)
            .position(p)
    }

    private func edgeLabel(at minute: Int, center: CGPoint, radius: CGFloat) -> some View {
        let p = positionForMinute(minute, center: center, radius: radius)
        return Text(formatTime(minute))
            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                Capsule().fill(Color.black.opacity(0.55))
            )
            .position(p)
            .allowsHitTesting(false)
    }

    private func nowMarker(center: CGPoint, radius: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let cal = Calendar.current
            let h = cal.component(.hour, from: context.date)
            let m = cal.component(.minute, from: context.date)
            let cur = h * 60 + m
            let p = positionForMinute(cur, center: center, radius: radius)
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 5, height: 5)
                Circle()
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    .frame(width: 12, height: 12)
                    .blur(radius: 2)
            }
            .position(p)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Slots column

    private var slotsColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Слоты")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                if !slots.isEmpty {
                    Button {
                        showClearAlert = true
                    } label: {
                        Text("Очистить всё")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if slots.isEmpty {
                Text("Слотов нет — приложение заблокировано весь день.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(slots) { slot in
                        SlotCard(slot: slot) {
                            state.removeSlot(fromApp: bundleID, id: slot.id)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Drag handlers

    private func handleDragChanged(at location: CGPoint, center: CGPoint) {
        let m = pointToMinutes(location, center: center)
        let angle = pointToAngle(location, center: center)

        switch dragMode {
        case nil:
            if let (id, edge) = findEdgeNear(m), let slot = slots.first(where: { $0.id == id }) {
                lastDragAngle = angle
                dragAccumulated = 0
                dragMode = .resize(slotID: id, edge: edge,
                                   originalStart: slot.startMinutes,
                                   originalEnd: slot.endMinutes)
            } else {
                lastDragAngle = angle
                dragAccumulated = 0
                dragMode = .create(start: m, current: m)
            }
        case .create(let startMin, _):
            var delta = angle - lastDragAngle
            while delta > .pi { delta -= 2 * .pi }
            while delta < -.pi { delta += 2 * .pi }
            lastDragAngle = angle
            dragAccumulated += delta * Double(minutesInDay) / (2 * .pi)
            dragAccumulated = max(-Double(minutesInDay), min(Double(minutesInDay), dragAccumulated))
            let rawEnd = startMin + Int(dragAccumulated.rounded())
            let snapped = snapToGrid(rawEnd)
            dragMode = .create(start: startMin, current: snapped)
        case .resize(let id, let edge, let os, let oe):
            var delta = angle - lastDragAngle
            while delta > .pi { delta -= 2 * .pi }
            while delta < -.pi { delta += 2 * .pi }
            lastDragAngle = angle
            dragAccumulated += delta * Double(minutesInDay) / (2 * .pi)
            let deltaMin = snapToGrid(Int(dragAccumulated.rounded()))

            guard let appIdx = state.managedApps.firstIndex(where: { $0.bundleID == bundleID }),
                  let slotIdx = state.managedApps[appIdx].slots.firstIndex(where: { $0.id == id })
            else { return }

            switch edge {
            case .start:
                var newStart = os + deltaMin
                let minStart = oe - minutesInDay
                let maxStart = oe - snapMinutes
                newStart = max(minStart, min(newStart, maxStart))

                var newEnd = oe
                while newStart >= minutesInDay {
                    newStart -= minutesInDay
                    newEnd -= minutesInDay
                }
                while newStart < 0 {
                    newStart += minutesInDay
                    newEnd += minutesInDay
                }
                state.managedApps[appIdx].slots[slotIdx].startMinutes = newStart
                state.managedApps[appIdx].slots[slotIdx].endMinutes = newEnd
            case .end:
                var newEnd = oe + deltaMin
                let minEnd = os + snapMinutes
                let maxEnd = os + minutesInDay
                newEnd = max(minEnd, min(newEnd, maxEnd))
                state.managedApps[appIdx].slots[slotIdx].endMinutes = newEnd
            }
        }
    }

    private func handleDragEnded() {
        defer { dragMode = nil }
        switch dragMode {
        case .create(let s, let e):
            if abs(e - s) >= snapMinutes {
                state.addSlot(toApp: bundleID, start: s, end: e)
            }
        case .resize(let id, _, _, _):
            state.finalizeResize(appBundleID: bundleID, slotID: id)
        case nil:
            break
        }
    }

    // MARK: - Helpers

    private func adjustSlot(_ slot: Slot, by deltaMinutes: Int) {
        guard let appIdx = state.managedApps.firstIndex(where: { $0.bundleID == bundleID }),
              let slotIdx = state.managedApps[appIdx].slots.firstIndex(where: { $0.id == slot.id })
        else { return }

        var newEnd = slot.endMinutes + deltaMinutes
        let minEnd = slot.startMinutes + snapMinutes
        let maxEnd = slot.startMinutes + minutesInDay

        if newEnd < minEnd {
            state.removeSlot(fromApp: bundleID, id: slot.id)
            return
        }
        newEnd = min(newEnd, maxEnd)

        state.managedApps[appIdx].slots[slotIdx].endMinutes = newEnd
        state.finalizeResize(appBundleID: bundleID, slotID: slot.id)
    }

    private func snapToGrid(_ minute: Int) -> Int {
        let q = (Double(minute) / Double(snapMinutes)).rounded()
        return Int(q) * snapMinutes
    }

    private func arcSegments(rawStart: Int, rawEnd: Int) -> [(Int, Int)] {
        let lo = min(rawStart, rawEnd)
        let hi = max(rawStart, rawEnd)
        if hi - lo >= minutesInDay {
            return [(0, minutesInDay)]
        }
        var s = lo
        var e = hi
        while s < 0 { s += minutesInDay; e += minutesInDay }
        while s >= minutesInDay { s -= minutesInDay; e -= minutesInDay }
        if e <= minutesInDay {
            return [(s, e)]
        }
        return [(s, minutesInDay), (0, e - minutesInDay)]
    }

    private func displayMinute(_ raw: Int) -> Int {
        ((raw % minutesInDay) + minutesInDay) % minutesInDay
    }

    private func findEdgeNear(_ m: Int) -> (UUID, SlotEdge)? {
        let threshold = 7
        var best: (UUID, SlotEdge, Int)?
        for slot in slots {
            let dStart = minuteDistance(m, slot.startMinutes)
            let dEnd = minuteDistance(m, slot.endMinutes)
            if dStart <= threshold && (best == nil || dStart < best!.2) {
                best = (slot.id, .start, dStart)
            }
            if dEnd <= threshold && (best == nil || dEnd < best!.2) {
                best = (slot.id, .end, dEnd)
            }
        }
        return best.map { ($0.0, $0.1) }
    }

    private func minuteDistance(_ a: Int, _ b: Int) -> Int {
        let d = abs(a - b)
        return min(d, minutesInDay - d)
    }

    private func positionForMinute(_ minute: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = Double(minute) / Double(minutesInDay) * 2 * .pi - .pi / 2
        return CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }

    private var totalAllowedMinutes: Int {
        slots.reduce(0) { $0 + ($1.endMinutes - $1.startMinutes) }
    }

    private func formatMinutes(_ m: Int) -> String {
        let h = m / 60
        let mm = m % 60
        if h == 0 { return "\(mm) мин" }
        if mm == 0 { return "\(h) ч" }
        return "\(h) ч \(mm) мин"
    }

    private func formatTime(_ minute: Int) -> String {
        let m = ((minute % minutesInDay) + minutesInDay) % minutesInDay
        if m == 0 && minute != 0 { return "24:00" }
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    private func pointToMinutes(_ p: CGPoint, center: CGPoint) -> Int {
        let dx = p.x - center.x
        let dy = p.y - center.y
        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 { angle += 2 * .pi }
        if angle >= 2 * .pi { angle -= 2 * .pi }
        let frac = angle / (2 * .pi)
        let mins = Int(round(frac * Double(minutesInDay)))
        return min(minutesInDay, max(0, (mins / snapMinutes) * snapMinutes))
    }

    private func pointToAngle(_ p: CGPoint, center: CGPoint) -> Double {
        atan2(p.y - center.y, p.x - center.x)
    }

    private func hourLabelPos(hour: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = Double(hour) / 24.0 * 2 * .pi - .pi / 2
        return CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}
