import SwiftUI

struct PermissionsOnboardingView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    @ObservedObject var perms: PermissionsManager
    let onDismiss: () -> Void

    init(state: AppState, onDismiss: @escaping () -> Void) {
        self.state = state
        self.perms = state.permissions
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            LocalizedAsset(
                baseName: "onboarding_permissions",
                language: state.language,
                aspectRatio: 16.0 / 10,
                placeholderText: t.permsScreenshotPlaceholder
            )
            .frame(maxWidth: 720)

            VStack(spacing: 10) {
                permRow(
                    title: t.permsAccessibilityTitle,
                    description: t.permsAccessibilityDesc,
                    state: perms.accessibility,
                    onAction: { handleAction(.accessibility) }
                )
            }

            HStack {
                Button(t.permsRefresh) {
                    perms.refresh()
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.textSecondary)
                .font(.system(size: 11))

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text(perms.allRequiredGranted ? t.permsDoneAll : t.permsDoneLater)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(perms.allRequiredGranted ? .black : .white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(perms.allRequiredGranted
                                ? Theme.accent
                                : Color.white.opacity(0.06))
                        )
                        .overlay(
                            Capsule().stroke(perms.allRequiredGranted
                                ? Color.clear
                                : Theme.surfaceStroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

            Text(t.permsFooter)
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t.permsTitle)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
            Text(t.permsSubtitle)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Row

    private func permRow(
        title: String,
        description: String,
        state ps: PermissionState,
        onAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            statusBadge(state: ps)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            actionButton(state: ps, onTap: onAction)
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

    @ViewBuilder
    private func statusBadge(state ps: PermissionState) -> some View {
        switch ps {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(Theme.accent)
        case .denied:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 17))
                .foregroundColor(Theme.danger.opacity(0.85))
        case .notDetermined:
            Image(systemName: "circle")
                .font(.system(size: 17))
                .foregroundColor(Theme.textTertiary)
        }
    }

    @ViewBuilder
    private func actionButton(state ps: PermissionState, onTap: @escaping () -> Void) -> some View {
        switch ps {
        case .granted:
            Text(t.permsGranted)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
        case .denied:
            Button {
                onTap()
            } label: {
                Text(t.permsOpenSettings)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.danger.opacity(0.20)))
                    .overlay(Capsule().stroke(Theme.danger.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)
        case .notDetermined:
            Button {
                onTap()
            } label: {
                Text(t.permsGrant)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.accent.opacity(0.18)))
                    .overlay(Capsule().stroke(Theme.accent.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func handleAction(_ kind: PermissionKind) {
        let current: PermissionState
        switch kind {
        case .screenRecording: current = perms.screenRecording
        case .accessibility:   current = perms.accessibility
        }

        if current == .notDetermined {
            // Первый запрос — показываем системный prompt.
            switch kind {
            case .screenRecording: perms.requestScreenRecording()
            case .accessibility:   perms.requestAccessibility()
            }
        } else {
            // Уже отказано — открываем System Settings, prompt больше не покажется.
            perms.openSystemSettings(for: kind)
        }
    }
}
