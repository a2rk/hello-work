import SwiftUI

/// Корневой view модуля «Легенды». Внутри своя push-style навигация
/// (List ↔ Detail) через @State selectedLegend — без дополнительных
/// SidebarSelection-кейсов.
struct LegendsListView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState

    @State private var selectedLegend: Legend?

    // MARK: - Filters / search / sort / view-mode state

    /// Live raw text из text-field. На каждое изменение перезапускается debounce.
    @State private var searchInput: String = ""
    /// Debounced (200ms) копия — это то, по чему реально фильтруем.
    @State private var debouncedQuery: String = ""
    @State private var searchWorkItem: DispatchWorkItem?

    @State private var filterEra: String? = nil
    @State private var filterField: String? = nil
    @State private var filterTag: String? = nil
    @State private var filterIntensity: ClosedRange<Int>? = nil
    /// Persists across launches — TASK-L51.
    @AppStorage("helloWorkLegendsShowFavoritesOnly") private var filterFavoritesOnly: Bool = false

    /// Persists across launches — TASK-L53.
    @AppStorage("helloWorkLegendsSortChoice") private var sortChoiceRaw: String = SortChoice.order.rawValue
    private var sortChoice: SortChoice {
        SortChoice(rawValue: sortChoiceRaw) ?? .order
    }
    /// Persists across launches — UserDefaults key.
    @AppStorage("helloWorkLegendsViewMode") private var viewModeRaw: String = LegendsViewMode.grid.rawValue
    private var viewMode: LegendsViewMode {
        LegendsViewMode(rawValue: viewModeRaw) ?? .grid
    }

    /// Measured width — пишется через PreferenceKey из background'а results.
    /// GeometryReader внутри parent ScrollView коллапсирует width в 0,
    /// поэтому bottom-up measurement через preference-key.
    @State private var resultsWidth: CGFloat = 0

    /// Локальный enum для UI sort picker. Нельзя хранить LegendsLibrary.SortOrder
    /// напрямую как @State — у `.favoritesFirst(Set)` ассоциированное значение
    /// требует свежего set'а на каждый применение.
    enum SortChoice: String, CaseIterable, Identifiable {
        case order, name, favoritesFirst
        var id: String { rawValue }
    }

    enum LegendsViewMode: String { case grid, list }

    // MARK: - Body

    var body: some View {
        if let legend = selectedLegend {
            LegendDetailView(state: state, legend: legend, onBack: {
                selectedLegend = nil
            })
        } else {
            list
                .onAppear {
                    devlog("legends", "LegendsListView body — onAppear (selectedLegend=nil)")
                }
        }
    }

    // MARK: - List

    private var list: some View {
        VStack(alignment: .leading, spacing: 14) {
            LegendAppliedBanner(state: state)
            corruptBanner
            header
            controlsBar
            filtersBar
            results
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var corruptBanner: some View {
        let corruptCount = LegendsLibrary.shared.corruptIds.count
        if corruptCount > 0 {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.danger)
                Text(t.legendsCorruptHidden(corruptCount))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.danger.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.danger.opacity(0.35), lineWidth: 1)
            )
        }
    }

    // MARK: - Filters bar

    private var availableEras: [String] {
        Array(Set(LegendsLibrary.shared.all.map { $0.era })).sorted()
    }

    private var availableFields: [String] {
        Array(Set(LegendsLibrary.shared.all.map { $0.field })).sorted()
    }

    private var hasAnyFilter: Bool {
        filterEra != nil || filterField != nil || filterTag != nil
            || filterIntensity != nil || filterFavoritesOnly
    }

    private var filtersBar: some View {
        HStack(spacing: 8) {
            // Favorites pill вынесен из горизонтального scroll'а — самый
            // персональный фильтр должен быть всегда виден и кликабелен,
            // независимо от того, насколько далеко проскроллен список eras.
            favoritesFilterPill
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(availableEras, id: \.self) { era in
                        filterPill(
                            label: era.replacingOccurrences(of: "_", with: " "),
                            active: filterEra == era
                        ) {
                            filterEra = (filterEra == era) ? nil : era
                        }
                    }
                    Divider().frame(height: 14).background(Theme.surfaceStroke)
                    ForEach(availableFields, id: \.self) { field in
                        filterPill(
                            label: field.replacingOccurrences(of: "_", with: " "),
                            active: filterField == field
                        ) {
                            filterField = (filterField == field) ? nil : field
                        }
                    }
                    Divider().frame(height: 14).background(Theme.surfaceStroke)
                    ForEach(1...5, id: \.self) { i in
                        filterPill(
                            label: String(repeating: "•", count: i),
                            active: filterIntensity == (i...i)
                        ) {
                            filterIntensity = (filterIntensity == (i...i)) ? nil : (i...i)
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            if hasAnyFilter || !debouncedQuery.isEmpty {
                Button {
                    clearAllFilters()
                } label: {
                    Text(t.legendsFilterClear)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.danger.opacity(0.15)))
                        .overlay(Capsule().stroke(Theme.danger.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var favoritesFilterPill: some View {
        Button {
            filterFavoritesOnly.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: filterFavoritesOnly ? "star.fill" : "star")
                    .font(.system(size: 9, weight: .semibold))
                Text(t.legendsFilterFavorites)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(filterFavoritesOnly ? .white : Theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(filterFavoritesOnly ? Theme.accent.opacity(0.18) : Color.white.opacity(0.03))
            )
            .overlay(
                Capsule().stroke(filterFavoritesOnly ? Theme.accent : Theme.surfaceStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func filterPill(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(active ? .white : Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(active ? Theme.accent.opacity(0.18) : Color.white.opacity(0.03))
                )
                .overlay(
                    Capsule().stroke(active ? Theme.accent : Theme.surfaceStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t.legendsTitle)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
            Text(t.legendsSubtitle(LegendsLibrary.shared.all.count))
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private var controlsBar: some View {
        HStack(spacing: 10) {
            searchField
                .frame(maxWidth: 280)
            sortPicker
            Spacer()
            viewModeToggle
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
            TextField(t.legendsSearchPlaceholder, text: $searchInput)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .onChange(of: searchInput) { newValue in
                    scheduleSearchDebounce(newValue)
                }
            if !searchInput.isEmpty {
                Button {
                    searchInput = ""
                    debouncedQuery = ""
                    searchWorkItem?.cancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.white.opacity(0.04))
        )
        .overlay(
            Capsule().stroke(Theme.surfaceStroke, lineWidth: 1)
        )
    }

    private var sortPicker: some View {
        Menu {
            ForEach(SortChoice.allCases) { choice in
                Button {
                    sortChoiceRaw = choice.rawValue
                } label: {
                    HStack {
                        Text(sortChoiceTitle(choice))
                        if sortChoice == choice {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 10, weight: .semibold))
                Text(sortChoiceTitle(sortChoice))
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.04)))
            .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func sortChoiceTitle(_ c: SortChoice) -> String {
        switch c {
        case .order:          return t.legendsSortOrder
        case .name:           return t.legendsSortName
        case .favoritesFirst: return t.legendsSortFavorites
        }
    }

    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            modeButton(.grid, system: "square.grid.2x2", title: t.legendsViewGrid)
            modeButton(.list, system: "list.bullet", title: t.legendsViewList)
        }
        .padding(2)
        .background(Capsule().fill(Color.white.opacity(0.03)))
        .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
    }

    private func modeButton(_ mode: LegendsViewMode, system: String, title: String) -> some View {
        Button {
            viewModeRaw = mode.rawValue
        } label: {
            Image(systemName: system)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(viewMode == mode ? .white : Theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(viewMode == mode ? Color.white.opacity(0.10) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(title)
    }

    // MARK: - Results

    @ViewBuilder
    private var results: some View {
        if filteredItems.isEmpty {
            emptyResultsView
        } else {
            // Outer PrefsView.detail уже оборачивает в ScrollView — не вкладываем
            // второй (nested ScrollView ломает hit-testing и bounce). Width
            // измеряем через PreferenceKey: invisible Color.clear в .background
            // регистрирует actual width у этого VStack'а.
            VStack(alignment: .leading, spacing: 10) {
                Text(t.legendsResultsCount(filteredItems.count))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(Theme.textTertiary)
                    .padding(.bottom, 4)

                if viewMode == .grid {
                    if resultsWidth > 0 {
                        gridResults(width: resultsWidth)
                    } else {
                        // Первый кадр: width ещё не измерен. Минимальная
                        // подставка чтобы layout не дёргался — рендерим
                        // через типичную ширину Preferences detail panel.
                        gridResults(width: 720)
                    }
                } else {
                    listResults
                }
            }
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ResultsWidthKey.self,
                        value: geo.size.width
                    )
                }
            )
            .onPreferenceChange(ResultsWidthKey.self) { newValue in
                resultsWidth = newValue
            }
        }
    }

    private var emptyResultsView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(Theme.textTertiary)
            Text(t.legendsEmptyResults)
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
                .multilineTextAlignment(.center)
            if hasAnyFilter || !debouncedQuery.isEmpty {
                Button {
                    clearAllFilters()
                } label: {
                    Text(t.legendsFilterClear)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.accent.opacity(0.18)))
                        .overlay(Capsule().stroke(Theme.accent.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func clearAllFilters() {
        searchInput = ""
        debouncedQuery = ""
        searchWorkItem?.cancel()
        filterEra = nil
        filterField = nil
        filterTag = nil
        filterIntensity = nil
        filterFavoritesOnly = false
    }

    /// Masonry layout: 3-column grid с периодической featured карточкой 2×2,
    /// alternating сторона (left → right → left → ...). Каждый super-cycle:
    /// 1 featured (5 items: 1 large + 4 small) + 2 regular rows (6 items) = 11 items.
    private func gridResults(width totalWidth: CGFloat) -> some View {
        let spacing: CGFloat = 12
        // 3 columns. Минимальная ширина 180pt чтобы не схлопывалось на узком окне.
        let smallW = max(180, (totalWidth - 2 * spacing) / 3)
        let smallH: CGFloat = 170
        let bigW = 2 * smallW + spacing
        let bigH = 2 * smallH + spacing

        let blocks = computeBlocks(items: filteredItems)

        return LazyVStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(
                    block,
                    smallW: smallW, smallH: smallH,
                    bigW: bigW, bigH: bigH,
                    spacing: spacing
                )
            }
        }
    }

    @ViewBuilder
    private func blockView(
        _ block: LayoutBlock,
        smallW: CGFloat, smallH: CGFloat,
        bigW: CGFloat, bigH: CGFloat,
        spacing: CGFloat
    ) -> some View {
        switch block {
        case .featured(let big, let smalls, let bigOnLeft, let baseIndex):
            featuredRow(
                big: big, smalls: smalls,
                bigOnLeft: bigOnLeft, baseIndex: baseIndex,
                smallW: smallW, smallH: smallH,
                bigW: bigW, bigH: bigH,
                spacing: spacing
            )
        case .regular(let trio, let baseIndex):
            regularRow(
                trio: trio, baseIndex: baseIndex,
                smallW: smallW, smallH: smallH,
                spacing: spacing
            )
        }
    }

    /// Featured row занимает ровно те же 3 columns что regular: big = 2 columns,
    /// рядом 1 column со stack из 2 small cards (один над другим).
    private func featuredRow(
        big: Legend, smalls: [Legend],
        bigOnLeft: Bool, baseIndex: Int,
        smallW: CGFloat, smallH: CGFloat,
        bigW: CGFloat, bigH: CGFloat,
        spacing: CGFloat
    ) -> some View {
        HStack(alignment: .top, spacing: spacing) {
            if bigOnLeft {
                LegendCard(state: state, legend: big, index: baseIndex, size: .large) {
                    selectedLegend = big
                }
                .frame(width: bigW, height: bigH)
                smallColumn(smalls: smalls, baseIndex: baseIndex + 1, smallW: smallW, smallH: smallH, spacing: spacing)
            } else {
                smallColumn(smalls: smalls, baseIndex: baseIndex, smallW: smallW, smallH: smallH, spacing: spacing)
                LegendCard(state: state, legend: big, index: baseIndex + 2, size: .large) {
                    selectedLegend = big
                }
                .frame(width: bigW, height: bigH)
            }
        }
    }

    /// Колонка из 2 small cards (один над другим) — занимает 1 grid-column,
    /// высотой совпадает с big card (2 * smallH + spacing).
    private func smallColumn(
        smalls: [Legend], baseIndex: Int,
        smallW: CGFloat, smallH: CGFloat, spacing: CGFloat
    ) -> some View {
        VStack(spacing: spacing) {
            ForEach(Array(smalls.prefix(2).enumerated()), id: \.element.id) { offset, legend in
                LegendCard(state: state, legend: legend, index: baseIndex + offset) {
                    selectedLegend = legend
                }
                .frame(width: smallW, height: smallH)
            }
        }
    }

    private func regularRow(
        trio: [Legend], baseIndex: Int,
        smallW: CGFloat, smallH: CGFloat, spacing: CGFloat
    ) -> some View {
        HStack(spacing: spacing) {
            ForEach(Array(trio.enumerated()), id: \.element.id) { offset, legend in
                LegendCard(state: state, legend: legend, index: baseIndex + offset) {
                    selectedLegend = legend
                }
                .frame(width: smallW, height: smallH)
            }
            // Если trio неполный (последняя строка) — пустые placeholder'ы для align.
            if trio.count < 3 {
                ForEach(0..<(3 - trio.count), id: \.self) { _ in
                    Color.clear.frame(width: smallW, height: smallH)
                }
            }
        }
    }

    /// Layout block — featured (1 large + 4 small) или regular (1-3 small).
    /// `baseIndex` — для stagger animation (idx в общей последовательности).
    private enum LayoutBlock {
        case featured(big: Legend, smalls: [Legend], bigOnLeft: Bool, baseIndex: Int)
        case regular(trio: [Legend], baseIndex: Int)
    }

    /// Раз в 3 блока — featured (1 big + 2 smalls = 3 items, занимает
    /// 3 columns × 2 rows). Остальные — regular row (3 items, 1 row).
    /// Каждый featured block alternates сторону: left → right → left → ...
    /// Если items не хватает на featured (<3) — graceful downgrade на regular.
    private func computeBlocks(items: [Legend]) -> [LayoutBlock] {
        var blocks: [LayoutBlock] = []
        var idx = 0
        var blockCounter = 0
        var featuredCounter = 0
        while idx < items.count {
            let isFeaturedSlot = (blockCounter % 3 == 0)
            if isFeaturedSlot, idx + 3 <= items.count {
                let big = items[idx]
                let smalls = Array(items[(idx + 1)..<(idx + 3)])
                let bigOnLeft = (featuredCounter % 2 == 0)
                blocks.append(.featured(big: big, smalls: smalls, bigOnLeft: bigOnLeft, baseIndex: idx))
                idx += 3
                featuredCounter += 1
            } else {
                let end = min(idx + 3, items.count)
                let trio = Array(items[idx..<end])
                blocks.append(.regular(trio: trio, baseIndex: idx))
                idx = end
            }
            blockCounter += 1
        }
        return blocks
    }

    private var listResults: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(filteredItems) { legend in
                LegendListRow(state: state, legend: legend) {
                    selectedLegend = legend
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.20), value: filteredItems.map(\.id))
    }

    // MARK: - Computed filter result

    private var filteredItems: [Legend] {
        var items = LegendsLibrary.shared.search(debouncedQuery)
        items = items.filter { legend in
            if let era = filterEra, legend.era != era { return false }
            if let field = filterField, legend.field != field { return false }
            if let tag = filterTag, !legend.tags.contains(tag) { return false }
            if let r = filterIntensity, !r.contains(legend.intensity) { return false }
            if filterFavoritesOnly, !state.isFavoriteLegend(legend.id) { return false }
            return true
        }
        return LegendsLibrary.shared.sort(items, by: sortOrderForChoice(sortChoice))
    }

    private func sortOrderForChoice(_ c: SortChoice) -> LegendsLibrary.SortOrder {
        switch c {
        case .order:          return .order
        case .name:           return .alphabetical(state.language == .ru ? .ru : .en)
        case .favoritesFirst: return .favoritesFirst(state.favoriteLegendIds)
        }
    }

    // MARK: - Search debounce

    private func scheduleSearchDebounce(_ value: String) {
        searchWorkItem?.cancel()
        let work = DispatchWorkItem { [value] in
            self.debouncedQuery = value
        }
        searchWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }
}

// LegendDetailView вынесен в Sources/HelloWork/Preferences/Legends/LegendDetailView.swift

/// PreferenceKey для bottom-up measurement ширины results-блока.
/// Используется чтобы masonry layout знал actual container width
/// без GeometryReader (тот коллапсирует внутри parent ScrollView).
private struct ResultsWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
