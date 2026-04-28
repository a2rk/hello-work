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
    @State private var filterFavoritesOnly: Bool = false

    @State private var sortChoice: SortChoice = .order
    @State private var viewMode: LegendsViewMode = .grid

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
        }
    }

    // MARK: - List

    private var list: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            controlsBar
            filtersBar
            results
            Spacer(minLength: 0)
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
            if hasAnyFilter {
                Button {
                    filterEra = nil
                    filterField = nil
                    filterTag = nil
                    filterIntensity = nil
                    filterFavoritesOnly = false
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
                    sortChoice = choice
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
            viewMode = mode
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
            Text(t.legendsEmptyResults)
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
                .padding(.top, 20)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(t.legendsResultsCount(filteredItems.count))
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(Theme.textTertiary)
                        .padding(.bottom, 4)

                    if viewMode == .grid {
                        gridResults
                    } else {
                        listResults
                    }
                }
            }
        }
    }

    private var gridResults: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 200, maximum: 240), spacing: 12, alignment: .top)],
            alignment: .leading,
            spacing: 12
        ) {
            ForEach(filteredItems) { legend in
                LegendCard(state: state, legend: legend) {
                    selectedLegend = legend
                }
            }
        }
    }

    private var listResults: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(filteredItems) { legend in
                LegendListRow(state: state, legend: legend) {
                    selectedLegend = legend
                }
            }
        }
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

/// Skeleton detail view — наполнится в TASK-L37..L48.
struct LegendDetailView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    let legend: Legend
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                onBack()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text(t.sectionLegends)
                        .font(.system(size: 12))
                }
                .foregroundColor(Theme.textSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(legend.name.en)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text("\(legend.fullName.en) · \(legend.yearsOfLife)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer(minLength: 0)
        }
    }
}
