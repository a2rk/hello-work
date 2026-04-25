import SwiftUI
import AppKit

struct UpdatesView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    @StateObject private var installer = UpdateInstaller()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text(t.updatesTitle)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text(headerSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            controls

            if state.devLogEntries.isEmpty {
                emptyState
            } else {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(state.devLogEntries) { entry in
                        UpdateEntryCard(
                            entry: entry,
                            isLatest: entry.id == state.devLogEntries.first?.id,
                            isInstalled: AppVersion.compare(entry.version, AppVersion.marketing) != .orderedDescending
                        )
                    }
                }
                .frame(maxWidth: 620, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .task {
            if state.devLogEntries.isEmpty {
                await state.checkForUpdates()
            }
        }
    }

    private var headerSubtitle: String {
        if state.updateAvailable, let v = state.latestRemoteVersion {
            return t.updatesSubtitleAvailable(v, AppVersion.marketing)
        }
        return t.updatesSubtitleCurrent(AppVersion.marketing)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            checkButton
            installSection
            Spacer()
        }
    }

    private var checkButton: some View {
        Button {
            Task { await state.checkForUpdates() }
        } label: {
            HStack(spacing: 6) {
                if state.isCheckingUpdates {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold))
                }
                Text(state.isCheckingUpdates ? t.checkingButton : t.checkButton)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(state.isCheckingUpdates)
    }

    @ViewBuilder
    private var installSection: some View {
        if state.updateAvailable,
           let dmg = state.devLogEntries.first?.dmgUrl,
           let url = URL(string: dmg) {
            switch installer.status {
            case .idle:
                installButton(url: url)
                if !UpdateInstaller.canSelfInstall {
                    Text(t.updateCannotSelfInstall)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                        .lineLimit(2)
                        .frame(maxWidth: 240, alignment: .leading)
                }
            case .downloading:
                progressPill(text: t.updateDownloading)
            case .installing:
                progressPill(text: t.updateInstalling)
            case .relaunching:
                progressPill(text: t.updateRelaunching)
            case .failed(let err):
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(t.updateFailed): \(err)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.danger.opacity(0.85))
                    HStack(spacing: 8) {
                        Button {
                            installer.reset()
                        } label: {
                            Text(t.checkButton)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.06)))
                                .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Text(t.updateOpenInBrowser)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func installButton(url: URL) -> some View {
        Button {
            if UpdateInstaller.canSelfInstall {
                Task { await installer.install(dmgUrl: url) }
            } else {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(t.installButton(state.latestRemoteVersion ?? ""))
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.accent))
        }
        .buttonStyle(.plain)
    }

    private func progressPill(text: String) -> some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.small).scaleEffect(0.7)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(state.lastUpdateCheckError == nil ? t.updatesEmptyOk : t.updatesEmptyError)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
            if let err = state.lastUpdateCheckError {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.danger.opacity(0.8))
            }
        }
        .padding(.vertical, 8)
    }
}

private struct UpdateEntryCard: View {
    @Environment(\.t) var t
    let entry: UpdateInfo
    let isLatest: Bool
    let isInstalled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("v\(entry.version)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                if isInstalled {
                    badge(t.badgeInstalled, color: Theme.textTertiary, fill: Color.white.opacity(0.04))
                } else if isLatest {
                    badge(t.badgeAvailable, color: Theme.accent, fill: Theme.accent.opacity(0.10))
                }

                Spacer()

                if let date = entry.date {
                    Text(date)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
            }

            if let msg = entry.customMessage, !msg.isEmpty {
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(entry.main)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if !entry.points.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(0..<entry.points.count, id: \.self) { i in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle()
                                .fill(Theme.textTertiary)
                                .frame(width: 3, height: 3)
                                .padding(.top, 5)
                            Text(entry.points[i])
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.78))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(isLatest && !isInstalled ? 0.05 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    (isLatest && !isInstalled) ? Theme.accent.opacity(0.35) : Theme.surfaceStroke,
                    lineWidth: 1
                )
        )
    }

    private func badge(_ text: String, color: Color, fill: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(1)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(fill))
    }
}
