import SwiftUI
import AppKit
import UniformTypeIdentifiers

private let minutesInDay = 1440
private let snapMinutes = 5

private enum Layout {
    static let prefsWindow = NSSize(width: 1100, height: 700)
    static let sidebarWidth: CGFloat = 240
    static let detailPaddingH: CGFloat = 48
    static let detailPaddingV: CGFloat = 44
    static let chartSize: CGFloat = 400
    static let statsMinWidth: CGFloat = 240
}

private enum Theme {
    static let accent = Color(red: 0.62, green: 1.0, blue: 0.58)
    static let accentMid = Color(red: 0.40, green: 0.95, blue: 0.45)
    static let accentDeep = Color(red: 0.10, green: 0.65, blue: 0.20)
    static let danger = Color(red: 1.0, green: 0.40, blue: 0.40)
    static let dangerDim = Color(red: 1.0, green: 0.38, blue: 0.38).opacity(0.30)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.40)
    static let surface = Color.white.opacity(0.045)
    static let surfaceStroke = Color.white.opacity(0.08)
    static let glow = Color(red: 0.55, green: 1.0, blue: 0.50).opacity(0.16)
}

struct Slot: Identifiable, Equatable {
    let id: UUID
    var startMinutes: Int   // [0, minutesInDay)
    var endMinutes: Int     // (startMinutes, startMinutes + minutesInDay]

    var wraps: Bool { endMinutes > minutesInDay }
    var lengthMinutes: Int { endMinutes - startMinutes }

    func contains(minute: Int) -> Bool {
        if minute >= startMinutes && minute < endMinutes { return true }
        if wraps && minute + minutesInDay >= startMinutes && minute + minutesInDay < endMinutes {
            return true
        }
        return false
    }
}

struct ManagedApp: Identifiable, Equatable {
    let bundleID: String
    let name: String
    let appURL: URL
    var slots: [Slot]
    var isArchived: Bool = false

    var id: String { bundleID }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: appURL.path)
    }
}

enum SlotEdge { case start, end }

enum DragMode: Equatable {
    case create(start: Int, current: Int)
    case resize(slotID: UUID, edge: SlotEdge, originalStart: Int, originalEnd: Int)
}

@main
struct HelloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppState: ObservableObject {
    @Published var enabled: Bool = true
    @Published var managedApps: [ManagedApp] = []
    private(set) var graceUntil: Date?

    var graceRemaining: TimeInterval? {
        guard let g = graceUntil else { return nil }
        let r = g.timeIntervalSinceNow
        return r > 0 ? r : nil
    }

    func grantGrace(seconds: TimeInterval) {
        graceUntil = Date().addingTimeInterval(seconds)
    }

    func recompute(now: Date = Date()) {
        if let g = graceUntil, now >= g {
            graceUntil = nil
        }
    }

    func isAllowed(app: ManagedApp, now: Date = Date()) -> Bool {
        if let g = graceUntil, now < g { return true }
        let cal = Calendar.current
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        let cur = h * 60 + m
        return app.slots.contains { $0.contains(minute: cur) }
    }

    func addManagedApp(_ app: ManagedApp) {
        if let idx = managedApps.firstIndex(where: { $0.bundleID == app.bundleID }) {
            managedApps[idx].isArchived = false
            return
        }
        managedApps.append(app)
    }

    func removeManagedApp(bundleID: String) {
        managedApps.removeAll { $0.bundleID == bundleID }
    }

    func archiveApp(bundleID: String) {
        if let idx = managedApps.firstIndex(where: { $0.bundleID == bundleID }) {
            managedApps[idx].isArchived = true
        }
    }

    func unarchiveApp(bundleID: String) {
        if let idx = managedApps.firstIndex(where: { $0.bundleID == bundleID }) {
            managedApps[idx].isArchived = false
        }
    }

    func addSlot(toApp bundleID: String, start: Int, end: Int) {
        guard let idx = managedApps.firstIndex(where: { $0.bundleID == bundleID }) else { return }

        let lo = min(start, end)
        let hi = max(start, end)
        let length = ((hi - lo) / snapMinutes) * snapMinutes
        guard length >= snapMinutes else { return }

        if length >= minutesInDay {
            managedApps[idx].slots = [Slot(id: UUID(), startMinutes: 0, endMinutes: minutesInDay)]
            return
        }

        var s = lo
        while s < 0 { s += minutesInDay }
        while s >= minutesInDay { s -= minutesInDay }
        s = (s / snapMinutes) * snapMinutes
        let e = s + length

        let candidate = Slot(id: UUID(), startMinutes: s, endMinutes: e)

        var unionSet = Self.minuteSet(of: candidate)
        var keep: [Slot] = []
        for slot in managedApps[idx].slots {
            let sset = Self.minuteSet(of: slot)
            if !sset.isDisjoint(with: unionSet) {
                unionSet.formUnion(sset)
            } else {
                keep.append(slot)
            }
        }
        let merged = Self.slotsFromMinuteSet(unionSet)
        managedApps[idx].slots = (keep + merged).sorted { $0.startMinutes < $1.startMinutes }
    }

    private static func minuteSet(of slot: Slot) -> Set<Int> {
        var set = Set<Int>()
        let segments: [(Int, Int)]
        if slot.endMinutes <= minutesInDay {
            segments = [(slot.startMinutes, slot.endMinutes)]
        } else {
            segments = [(slot.startMinutes, minutesInDay), (0, slot.endMinutes - minutesInDay)]
        }
        for (a, b) in segments {
            var m = a
            while m < b { set.insert(m); m += snapMinutes }
        }
        return set
    }

    private static func slotsFromMinuteSet(_ set: Set<Int>) -> [Slot] {
        if set.isEmpty { return [] }
        if set.count * snapMinutes >= minutesInDay {
            return [Slot(id: UUID(), startMinutes: 0, endMinutes: minutesInDay)]
        }
        let sorted = set.sorted()
        var runs: [(Int, Int)] = []
        var cs = sorted[0]
        var ce = sorted[0] + snapMinutes
        for i in 1..<sorted.count {
            if sorted[i] == ce {
                ce = sorted[i] + snapMinutes
            } else {
                runs.append((cs, ce))
                cs = sorted[i]
                ce = sorted[i] + snapMinutes
            }
        }
        runs.append((cs, ce))

        if runs.count >= 2,
           runs.first!.0 == 0,
           runs.last!.1 == minutesInDay {
            let first = runs.removeFirst()
            let last = runs.removeLast()
            runs.append((last.0, first.1 + minutesInDay))
        }

        return runs.map { Slot(id: UUID(), startMinutes: $0.0, endMinutes: $0.1) }
    }

    func removeSlot(fromApp bundleID: String, id: UUID) {
        guard let idx = managedApps.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        managedApps[idx].slots.removeAll { $0.id == id }
    }

    func clearSlots(forApp bundleID: String) {
        guard let idx = managedApps.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        managedApps[idx].slots = []
    }

    func finalizeResize(appBundleID: String, slotID: UUID) {
        guard let appIdx = managedApps.firstIndex(where: { $0.bundleID == appBundleID }),
              let slotIdx = managedApps[appIdx].slots.firstIndex(where: { $0.id == slotID })
        else { return }
        let s = managedApps[appIdx].slots[slotIdx]
        managedApps[appIdx].slots.remove(at: slotIdx)
        addSlot(toApp: appBundleID, start: s.startMinutes, end: s.endMinutes)
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.blendingMode = .behindWindow
        v.state = .active
        v.appearance = NSAppearance(named: .vibrantDark)
        v.alphaValue = 0.55
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct ContentView: View {
    var body: some View {
        ZStack {
            VisualEffectView()
            Color.black.opacity(0.15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Preferences UI

enum PrefSection: String, CaseIterable, Identifiable {
    case settings, contacts, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .settings: return "Настройки"
        case .contacts: return "Контакты"
        case .about:    return "О программе"
        }
    }
    var icon: String {
        switch self {
        case .settings: return "gearshape.fill"
        case .contacts: return "person.crop.circle.fill"
        case .about:    return "info.circle.fill"
        }
    }
}

enum SidebarSelection: Hashable {
    case app(String)
    case section(PrefSection)
    case onboarding
}

struct PrefsView: View {
    @ObservedObject var state: AppState
    @State private var selection: SidebarSelection? = nil

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: Layout.sidebarWidth)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: Layout.prefsWindow.width, height: Layout.prefsWindow.height)
        .background(BackgroundView())
        .preferredColorScheme(.dark)
        .onAppear {
            if selection == nil {
                selection = state.managedApps.first.map { .app($0.bundleID) } ?? .onboarding
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            BrandMark()
                .padding(.horizontal, 12)
                .padding(.top, 24)
                .padding(.bottom, 22)

            createButton

            ForEach(state.managedApps) { app in
                AppSidebarRow(
                    app: app,
                    isSelected: selection == .app(app.bundleID),
                    isAllowedNow: state.isAllowed(app: app)
                ) {
                    selection = .app(app.bundleID)
                }
            }

            sidebarDivider

            ForEach(PrefSection.allCases) { section in
                SidebarItem(section: section, isSelected: selection == .section(section)) {
                    selection = .section(section)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
    }

    private var sidebarDivider: some View {
        Rectangle()
            .fill(Theme.surfaceStroke)
            .frame(height: 1)
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
    }

    private var createButton: some View {
        Button {
            selection = .onboarding
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 16)
                Text("Добавить")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .foregroundColor(selection == .onboarding ? .white : Color.white.opacity(0.78))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selection == .onboarding ? Color.white.opacity(0.06) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Theme.surfaceStroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, Layout.detailPaddingH)
            .padding(.vertical, Layout.detailPaddingV)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .app(let bid):
            if state.managedApps.contains(where: { $0.bundleID == bid }) {
                ScheduleView(state: state, bundleID: bid)
                    .id(bid)
            } else {
                OnboardingView(action: openAppPicker)
            }
        case .section(.settings):
            SettingsView(state: state)
        case .section(.contacts):
            ContactsView()
        case .section(.about):
            AboutView()
        case .onboarding, nil:
            OnboardingView(action: openAppPicker)
        }
    }

    private func openAppPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Выбери приложение для расписания"
        panel.prompt = "Добавить"

        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else { return }

        let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent

        let app = ManagedApp(bundleID: bundleID, name: name, appURL: url, slots: [])
        state.addManagedApp(app)
        selection = .app(bundleID)
    }
}

struct AppSidebarRow: View {
    let app: ManagedApp
    let isSelected: Bool
    let isAllowedNow: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 18, height: 18)
                    .opacity(app.isArchived ? 0.45 : 1)
                Text(app.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(textColor)
                    .strikethrough(app.isArchived, color: Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if !app.isArchived {
                    Circle()
                        .fill(isAllowedNow ? Theme.accent : Theme.danger)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        if app.isArchived { return Theme.textTertiary }
        return isSelected ? .white : Color.white.opacity(0.78)
    }
}

struct OnboardingView: View {
    let action: () -> Void

    private let steps: [(num: Int, title: String, desc: String)] = [
        (1, "Выбери приложение", "Из /Applications. То, что отвлекает."),
        (2, "Установи график", "Кругом обозначь окна доступа. Шаг 5 минут."),
        (3, "Работай спокойно", "Вне расписания — блюр и блок ввода.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Добавить приложение")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
                Text("Три шага. Выбери приложение, нарисуй график, работай спокойно.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: 460, alignment: .leading)
            }

            stepsRow
                .frame(maxWidth: 620, alignment: .leading)

            Button(action: action) {
                HStack(spacing: 8) {
                    Text("Выбрать приложение")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }

    private var stepsRow: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(0..<steps.count, id: \.self) { i in
                stepColumn(steps[i])
                    .frame(maxWidth: .infinity, alignment: .leading)
                if i < steps.count - 1 {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Theme.textTertiary)
                        .padding(.top, 11)
                }
            }
        }
    }

    private func stepColumn(_ step: (num: Int, title: String, desc: String)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
                Text("\(step.num)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(step.desc)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SidebarItem: View {
    let section: PrefSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: section.icon)
                    .font(.system(size: 12, weight: .regular))
                    .frame(width: 16)
                    .foregroundColor(isSelected ? .white : Theme.textTertiary)
                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

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

    private func edgeDot(at minute: Int, center: CGPoint, radius: CGFloat) -> some View {
        let p = positionForMinute(minute, center: center, radius: radius)
        return Circle()
            .fill(Color.white)
            .frame(width: 6, height: 6)
            .position(p)
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

    private func formatTime(_ minute: Int) -> String {
        let m = ((minute % minutesInDay) + minutesInDay) % minutesInDay
        if m == 0 && minute != 0 { return "24:00" }
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

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

    private func snapToGrid(_ minute: Int) -> Int {
        let q = (Double(minute) / Double(snapMinutes)).rounded()
        return Int(q) * snapMinutes
    }

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
        let m = ((raw % minutesInDay) + minutesInDay) % minutesInDay
        return m
    }

    private func pointToAngle(_ p: CGPoint, center: CGPoint) -> Double {
        atan2(p.y - center.y, p.x - center.x)
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

    private func arc(start: Int, end: Int, thickness: CGFloat, size: CGFloat, color: Color) -> some View {
        Circle()
            .trim(from: CGFloat(start) / CGFloat(minutesInDay),
                  to: CGFloat(end) / CGFloat(minutesInDay))
            .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-90))
    }

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

    private func hourLabelPos(hour: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = Double(hour) / 24.0 * 2 * .pi - .pi / 2
        return CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}

struct SlotCard: View {
    let slot: Slot
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(format(slot.startMinutes))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                Text(format(slot.endMinutes))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textTertiary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Text(lengthText)
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.surfaceStroke, lineWidth: 1)
        )
    }

    private var lengthText: String {
        let length = slot.lengthMinutes
        let h = length / 60
        let m = length % 60
        if h == 0 { return "\(m) мин" }
        if m == 0 { return "\(h) ч" }
        return "\(h) ч \(m) мин"
    }

    private func format(_ minute: Int) -> String {
        let m = ((minute % minutesInDay) + minutesInDay) % minutesInDay
        if m == 0 && minute != 0 { return "24:00" }
        return String(format: "%02d:%02d", m / 60, m % 60)
    }
}

struct SettingsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Настройки")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text("Глобальные параметры FocusNap.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Включить")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Глобальный режим. Если выключено — все оверлеи скрываются и приложения работают без ограничений.")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("", isOn: $state.enabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(Theme.accent)
                        .labelsHidden()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .frame(maxWidth: 460, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )

            Spacer(minLength: 0)
        }
    }
}

struct ContactsView: View {
    private let rows: [(label: String, value: String)] = [
        ("Email",    "igor@focusnap.app"),
        ("Telegram", "@igor_dev"),
        ("Сайт",     "focusnap.app"),
        ("Issues",   "github.com/igor/focusnap")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Контакты")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text("Связь с автором.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(0..<rows.count, id: \.self) { i in
                    ContactRow(label: rows[i].label, value: rows[i].value)
                    if i < rows.count - 1 {
                        Rectangle()
                            .fill(Theme.surfaceStroke)
                            .frame(height: 1)
                    }
                }
            }
            .frame(maxWidth: 460, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )

            Spacer(minLength: 0)
        }
    }
}

struct ContactRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 84, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                    Text("F")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.black)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("FocusNap")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    Text("v0.1 · macOS")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Text("FocusNap блокирует приложения по графику, который ты сам нарисуешь на круге. Вне расписания — блюр поверх окна и блок ввода. Сейчас, мгновенно.")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.78))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 460, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                Text("Как пользоваться")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)

                Text("Добавь приложение через «+ Добавить» в боковой панели. Открой его расписание и нарисуй на круге зелёные слоты — это окна доступа. Всё остальное время приложение заблокировано.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.78))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 460, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
    }
}

struct BackgroundView: View {
    var body: some View {
        ZStack {
            MaterialBackdrop()
            Color.black.opacity(0.22)
        }
        .ignoresSafeArea()
    }
}

struct MaterialBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.appearance = NSAppearance(named: .vibrantDark)
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct BrandMark: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 7, height: 7)
            Text("FocusNap")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

final class FixedWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
             .otherMouseDown, .otherMouseUp,
             .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
             .scrollWheel, .keyDown, .keyUp, .flagsChanged:
            return
        default:
            super.sendEvent(event)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var statusItem: NSStatusItem?
    private var toggleMenuItem: NSMenuItem?
    private var countdownMenuItem: NSMenuItem?
    private var activityToken: NSObjectProtocol?
    private var prefsWindow: NSWindow?
    private var overlayWindows: [String: NSWindow] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Periodic app-focus / time check"
        )

        setupStatusItem()
        setupWorkspaceObservers()
        startTimer()
        refresh()
    }

    private func ensureOverlay(for bundleID: String) -> NSWindow {
        if let w = overlayWindows[bundleID] { return w }
        let hosting = NSHostingController(rootView: ContentView())
        let win = FixedWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.contentViewController = hosting
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.isMovable = false
        win.isMovableByWindowBackground = false
        win.ignoresMouseEvents = false
        win.level = .normal
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlayWindows[bundleID] = win
        return win
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = Self.makeMenuBarIcon()

        let menu = NSMenu()

        let openMenu = NSMenuItem(
            title: "Меню",
            action: #selector(openPreferences),
            keyEquivalent: ""
        )
        openMenu.target = self
        menu.addItem(openMenu)

        menu.addItem(NSMenuItem.separator())

        let toggle = NSMenuItem(
            title: toggleTitle(),
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)
        toggleMenuItem = toggle

        menu.addItem(NSMenuItem.separator())

        let grace = NSMenuItem(
            title: "Ещё минутку",
            action: #selector(grantOneMinute),
            keyEquivalent: ""
        )
        grace.target = self
        menu.addItem(grace)

        let countdown = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        countdown.isEnabled = false
        countdown.isHidden = true
        menu.addItem(countdown)
        countdownMenuItem = countdown

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(
            title: "Закрыть",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        )
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    private func setupWorkspaceObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        observers.append(nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.refresh() })
        observers.append(nc.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.refresh() })
    }

    private func startTimer() {
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func toggleEnabled() {
        state.enabled.toggle()
        toggleMenuItem?.title = toggleTitle()
        refresh()
    }

    @objc private func grantOneMinute() {
        state.grantGrace(seconds: 60)
        refresh()
    }

    @objc private func openPreferences() {
        if prefsWindow == nil {
            let size = Layout.prefsWindow
            let win = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.title = "FocusNap"
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.isReleasedWhenClosed = false

            let hosting = NSHostingController(rootView: PrefsView(state: state))
            win.contentViewController = hosting
            win.setContentSize(size)
            win.minSize = size
            win.maxSize = size
            win.center()
            prefsWindow = win
        }
        prefsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateCountdownItem() {
        guard let item = countdownMenuItem else { return }
        if let remaining = state.graceRemaining {
            let total = Int(ceil(remaining))
            let mm = total / 60
            let ss = total % 60
            item.title = String(format: "%02d:%02d", mm, ss)
            item.isHidden = false
        } else {
            item.isHidden = true
        }
    }

    private func toggleTitle() -> String {
        "Включено: \(state.enabled ? "Да" : "Нет")"
    }

    private func refresh() {
        state.recompute()
        updateCountdownItem()
        toggleMenuItem?.title = toggleTitle()

        if !state.enabled {
            for w in overlayWindows.values { w.orderOut(nil) }
            return
        }

        let frontmostBID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        var seenBIDs = Set<String>()

        for app in state.managedApps where !app.isArchived {
            seenBIDs.insert(app.bundleID)
            let win = ensureOverlay(for: app.bundleID)

            if state.isAllowed(app: app) {
                win.orderOut(nil)
                continue
            }

            guard let (frame, winNum) = findAppWindow(bundleID: app.bundleID) else {
                win.orderOut(nil)
                continue
            }

            if win.frame != frame {
                win.setFrame(frame, display: true)
            }
            win.order(.above, relativeTo: winNum)

            if frontmostBID == app.bundleID && !win.isKeyWindow {
                win.makeKey()
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        let staleBIDs = overlayWindows.keys.filter { !seenBIDs.contains($0) }
        for bid in staleBIDs {
            overlayWindows[bid]?.orderOut(nil)
            overlayWindows.removeValue(forKey: bid)
        }
    }

    private func findAppWindow(bundleID: String) -> (NSRect, Int)? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        var bestRect: NSRect?
        var bestWindowNumber: Int?
        var bestArea: CGFloat = 0

        for w in info {
            guard
                let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                let bounds = w[kCGWindowBounds as String] as? [String: CGFloat],
                let x = bounds["X"], let y = bounds["Y"],
                let width = bounds["Width"], let height = bounds["Height"],
                let winNum = w[kCGWindowNumber as String] as? Int,
                let pidNum = w[kCGWindowOwnerPID as String] as? Int,
                width > 100, height > 100
            else { continue }

            let pid = pid_t(pidNum)
            guard NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == bundleID
            else { continue }

            let area = width * height
            if area > bestArea {
                bestArea = area
                bestRect = cgFrameToScreenFrame(NSRect(x: x, y: y, width: width, height: height))
                bestWindowNumber = winNum
            }
        }
        if let r = bestRect, let n = bestWindowNumber {
            return (r, n)
        }
        return nil
    }

    private func cgFrameToScreenFrame(_ cg: NSRect) -> NSRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(
            x: cg.origin.x,
            y: primaryHeight - cg.origin.y - cg.size.height,
            width: cg.size.width,
            height: cg.size.height
        )
    }

    private static func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .heavy),
                .foregroundColor: NSColor.black
            ]
            let str = NSAttributedString(string: "F", attributes: attrs)
            let strSize = str.size()
            let point = NSPoint(
                x: (rect.width - strSize.width) / 2,
                y: (rect.height - strSize.height) / 2
            )
            str.draw(at: point)
            return true
        }
        image.isTemplate = true
        return image
    }
}
