import AppKit
import ApplicationServices
import CoreGraphics

enum PermissionState: Equatable {
    case granted
    case denied            // юзер явно отказал
    case notDetermined     // ещё не спрашивали
}

enum PermissionKind {
    case screenRecording
    case accessibility
}

/// Слежение за системными разрешениями. Refresh вручную (на старт + при возврате в приложение).
@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var screenRecording: PermissionState = .notDetermined
    @Published private(set) var accessibility: PermissionState = .notDetermined

    /// Полностью ли всё дано — для решения «показать onboarding или нет».
    var allRequiredGranted: Bool {
        screenRecording == .granted && accessibility == .granted
    }

    /// Хотя бы что-то требует внимания.
    var anyMissing: Bool {
        screenRecording != .granted || accessibility != .granted
    }

    init() {
        refresh()
    }

    // MARK: - Refresh

    /// Перепроверка статусов. Вызывается на старт и при NSApplication.didBecomeActive.
    func refresh() {
        screenRecording = checkScreenRecording()
        accessibility = checkAccessibility()
    }

    // MARK: - Screen Recording

    private func checkScreenRecording() -> PermissionState {
        // На macOS 13+ используем CGPreflightScreenCaptureAccess.
        // Возвращает true только если разрешение granted.
        if CGPreflightScreenCaptureAccess() {
            return .granted
        }
        // Не можем отличить notDetermined от denied без trial-prompt.
        // Heuristic: если у нас не было предыдущего prompt в сессии — notDetermined,
        // иначе denied. Простая стратегия — всегда возвращаем denied (юзер увидит prompt).
        return UserDefaults.standard.bool(forKey: "helloWorkPermissionsRequestedSR")
            ? .denied
            : .notDetermined
    }

    func requestScreenRecording() {
        UserDefaults.standard.set(true, forKey: "helloWorkPermissionsRequestedSR")
        // macOS убивает процесс после изменения TCC — взводим auto-relaunch.
        AutoRelauncher.armRelaunchAfterDeath()
        // CGRequestScreenCaptureAccess — синхронный, показывает системный prompt.
        // Если уже отказали — prompt не покажется, надо в System Settings руками.
        _ = CGRequestScreenCaptureAccess()
        refresh()
    }

    // MARK: - Accessibility

    private func checkAccessibility() -> PermissionState {
        if AXIsProcessTrusted() {
            return .granted
        }
        return UserDefaults.standard.bool(forKey: "helloWorkPermissionsRequestedAX")
            ? .denied
            : .notDetermined
    }

    func requestAccessibility() {
        UserDefaults.standard.set(true, forKey: "helloWorkPermissionsRequestedAX")
        // На случай kill после grant — взводим auto-relaunch.
        AutoRelauncher.armRelaunchAfterDeath()
        // Prompt показывается только при первом вызове. Дальше — System Settings.
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        refresh()
    }

    // MARK: - System Settings deep-links

    /// Открывает соответствующий раздел System Settings (deep link).
    func openSystemSettings(for kind: PermissionKind) {
        // macOS убьёт нас после grant — взводим auto-relaunch.
        AutoRelauncher.armRelaunchAfterDeath()
        let urlString: String
        switch kind {
        case .screenRecording:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
