import Foundation

/// Все строки приложения. Никаких хардкодов в вьюхах — только через t.
struct Translation {
    // MARK: - StatusBar menu
    let menuOpenPrefs: String
    let menuToggleEnabled: (Bool) -> String
    let menuGraceLabel: (_ seconds: Int) -> String
    let menuQuit: String

    // MARK: - Sidebar
    let addApp: String
    let sectionStats: String
    let sectionMenubar: String
    let sectionUpdates: String
    let sectionSettings: String
    let sectionContacts: String
    let sectionAbout: String

    // MARK: - File picker
    let pickerMessage: String
    let pickerPrompt: String

    // MARK: - Onboarding
    let onboardingTitle: String
    let onboardingSubtitle: String
    let onboardingStep1Title: String
    let onboardingStep1Desc: String
    let onboardingStep2Title: String
    let onboardingStep2Desc: String
    let onboardingStep3Title: String
    let onboardingStep3Desc: String
    let onboardingButton: String

    // MARK: - Schedule
    let scheduleHint: String
    let allowed: String
    let blocked: String
    let archivedBadge: String
    let restore: String
    let deleteForever: String
    let archiveTooltip: String
    let slots: String
    let clearAll: String
    let noSlots: String
    let inDay: String
    let unitH: String
    let unitMin: String
    let unitSec: String

    let archiveAlertTitle: (String) -> String
    let archiveAlertMessage: String
    let archiveAlertConfirm: String
    let deleteAlertTitle: (String) -> String
    let deleteAlertMessage: String
    let deleteAlertConfirm: String
    let clearAlertTitle: String
    let clearAlertMessage: String
    let clearAlertConfirm: String
    let cancel: String

    let slotShrink: String
    let slotExtend: String
    let slotDelete: String

    // MARK: - Settings
    let settingsTitle: String
    let settingsSubtitle: String
    let settingEnableTitle: String
    let settingEnableDesc: String
    let settingsUpdatesTitle: String
    let settingsUpdateAvailable: (_ remote: String, _ current: String) -> String
    let settingsCurrentVersion: (_ current: String, _ time: String) -> String
    let settingsCurrentVersionShort: (_ current: String) -> String
    let checkButton: String
    let checkingButton: String
    let settingLanguageTitle: String
    let settingLanguageDesc: String

    let settingAutoUpdateTitle: String
    let settingAutoUpdateDesc: String

    let settingLaunchAtLoginTitle: String
    let settingLaunchAtLoginDesc: String

    let settingSnapStepTitle: String
    let settingSnapStepDesc: String

    let settingGraceTitle: String
    let settingGraceDesc: String
    let settingGraceCustomPlaceholder: String
    let settingGraceCustomAdd: String
    let graceTooBigTitle: String
    let graceTooBigMessage: String
    let graceTooBigOk: String

    // MARK: - Updates
    let updatesTitle: String
    let updatesSubtitleAvailable: (_ remote: String, _ current: String) -> String
    let updatesSubtitleCurrent: (_ current: String) -> String
    let installButton: (_ version: String) -> String
    let badgeInstalled: String
    let badgeAvailable: String
    let updatesEmptyOk: String
    let updatesEmptyError: String

    let updateDownloading: String
    let updateInstalling: String
    let updateRelaunching: String
    let updateFailed: String
    let updateOpenInBrowser: String
    let updateCannotSelfInstall: String

    let settingsSectionBehavior: String
    let settingsSectionSchedule: String
    let settingsSectionUpdates: String
    let settingsSectionInterface: String

    let settingPatternOverlayTitle: String
    let settingPatternOverlayDesc: String

    let niceTryFooter: String

    let updatesShowOlder: (_ count: Int) -> String
    let updatesHideOlder: String
    let updatesOpenPage: String

    // MARK: - Contacts
    let contactsTitle: String
    let contactsSubtitle: String
    let contactEmail: String
    let contactTelegram: String
    let contactWebsite: String
    let contactIssues: String

    // MARK: - About
    let aboutDescription: String
    let aboutHowToUseTitle: String
    let aboutHowToUseDesc: String

    // MARK: - Languages
    let languageSystem: String

    // MARK: - Stats
    let statsTitle: String
    let statsSubtitle: String
    let statsRangeToday: String
    let statsRangeWeek: String
    let statsRangeMonth: String
    let statsRangeYear: String
    let statsRangeAll: String

    let statsAttempts: (_ n: Int) -> String        // "127 попыток"
    let statsLostFocus: (_ formatted: String) -> String  // "9 мин 24 с потерянного фокуса"
    let statsCompareUp: (_ percent: Int) -> String       // "на 23% больше чем вчера"
    let statsCompareDown: (_ percent: Int) -> String     // "на 23% меньше чем вчера"
    let statsCompareEqual: String                        // "столько же, сколько вчера"
    let statsCompareNoData: String                       // "впервые за этот период"

    let statsSectionWhen: String      // "Когда"
    let statsSectionWhere: String     // "Куда лез"
    let statsSectionHow: String       // "Как"
    let statsSectionGrace: String     // "Бонусы"
    let statsSectionYear: String      // "Год"

    let statsClicks: String
    let statsScrolls: String
    let statsKeys: String
    let statsPeeks: String

    let statsGraceLine: (_ count: Int, _ minutes: Int) -> String  // "Использовано «Ещё минутку» 4 раза. 7 минут."
    let statsGraceNone: String

    let statsHeatmapLegendLess: String
    let statsHeatmapLegendMore: String
    let statsHeatmapDay: (_ date: String, _ count: Int) -> String

    let statsEmptyTitle: String
    let statsEmptyHint: String

    let statsResetTitle: String
    let statsResetDescription: String
    let statsResetButton: String
    let statsResetAlertTitle: String
    let statsResetAlertMessage: String
    let statsResetAlertConfirm: String
    let statsPrivacyNote: String

    let settingsSectionStats: String

    // MARK: - Focus mode
    let settingsSectionFocus: String
    let focusMenuItem: String
    let focusEnableTitle: String
    let focusEnableDesc: String
    let focusHotkeyTitle: String
    let focusHotkeyDesc: String
    let focusHotkeyCustom: String
    let focusHotkeyConflict: String
    let focusOpacityTitle: String
    let focusOpacityDesc: String
    let focusUseAXTitle: String
    let focusUseAXDesc: String
    let focusRecorderTitle: String
    let focusRecorderHint: String
    let focusRecorderPlaceholder: String
    let focusRecorderConfirm: String

    // MARK: - Stats: focus part
    let statsHeroAttemptsLabel: String
    let statsHeroFocusLabel: String
    let statsHeroFocusMinutes: String
    let statsHeroFocusHours: String
    let statsHeroFocusSessions: (_ n: Int) -> String
    let statsSectionFocus: String
    let statsFocusSessions: String
    let statsFocusTotal: String
    let statsFocusLongest: String
    let statsFocusAverage: String
    let statsFocusTopApps: String
    let statsLegendFocus: String
    let statsLegendAttempts: String

    // MARK: - Settings tabs
    let settingsTabSchedule: String
    let settingsTabFocus: String
    let settingsTabApp: String
    let settingsTabData: String

    // MARK: - Menubar page
    let menubarSubtitle: String
    let menubarHideAll: String
    let menubarShowAll: String
    let menubarEnableLabel: String
    let menubarStateCollapsed: String
    let menubarStateExpanded: String
    let menubarPreviewNow: String
    let menubarPreviewAfter: String
    let menubarItemCount: (_ n: Int) -> String
    let menubarHiddenHint: String
    let menubarHotkeyTitle: String
    let menubarAutoTitle: String
    let menubarAutoFocus: String
    let menubarAutoSchedule: String
    let menubarPersist: String
    let menubarDisclaimer: String
}
