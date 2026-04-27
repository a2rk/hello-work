import SwiftUI
import AppKit

struct CombinedScheduleView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState

    private var activeApps: [ManagedApp] {
        state.managedApps.filter { !$0.isArchived }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            VStack(alignment: .leading, spacing: 18) {
                ringSection
                legend
                timelineSection
                infoSection
            }
            .frame(maxWidth: Layout.settingsCardMaxWidth, alignment: .leading)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t.combinedScheduleTitle)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
            Text(t.combinedScheduleSubtitle(activeApps.count))
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Ring

    private var ringSection: some View {
        HStack {
            Spacer(minLength: 0)
            // TimelineView оборачивает только тикающую часть — раз в 30с
            // обновляется now, но parent body НЕ перерисовывается.
            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                CombinedRingChart(
                    apps: activeApps,
                    now: ctx.date,
                    onAppTap: { bid in
                        state.prefsSelection = .app(bid)
                    }
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Legend

    private var legend: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 110), spacing: 6, alignment: .leading)],
            alignment: .leading,
            spacing: 6
        ) {
            ForEach(activeApps) { app in
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppPalette.color(for: app.bundleID))
                        .frame(width: 10, height: 10)
                    Text(app.name)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.white.opacity(0.04))
                )
                .overlay(
                    Capsule().stroke(Theme.surfaceStroke, lineWidth: 1)
                )
                .onTapGesture { state.prefsSelection = .app(app.bundleID) }
            }
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t.combinedTimelineTitle.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Theme.textTertiary)
            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                CombinedTimeline(
                    apps: activeApps,
                    now: ctx.date,
                    onAppTap: { bid in
                        state.prefsSelection = .app(bid)
                    }
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t.combinedInfoTitle.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Theme.textTertiary)
            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                CombinedInfoPanel(apps: activeApps, now: ctx.date)
            }
        }
    }
}
