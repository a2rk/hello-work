import Foundation
import Carbon.HIToolbox
import AppKit

/// Тонкая обёртка над Carbon RegisterEventHotKey.
/// Один менеджер держит один зарегистрированный хоткей за раз.
@MainActor
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onTrigger: (() -> Void)?

    /// Уникальный signature/id для этого менеджера. У каждого инстанса
    /// должен быть свой `id` — иначе Carbon при двух регистрациях с одинаковым
    /// EventHotKeyID не различит их и события могут перепутаться.
    private let hotKeyID: EventHotKeyID

    init(id: UInt32 = 1) {
        self.hotKeyID = EventHotKeyID(
            signature: OSType(0x484B4559), // 'HKEY'
            id: id
        )
        installHandler()
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let h = eventHandler { RemoveEventHandler(h) }
    }

    // MARK: - Public

    /// Зарегистрировать хоткей. Перезаписывает предыдущий.
    /// Возвращает true если получилось.
    @discardableResult
    func register(_ hotkey: FocusHotkey, onTrigger: @escaping () -> Void) -> Bool {
        unregister()
        self.onTrigger = onTrigger

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            self.onTrigger = nil
            return false
        }
        self.hotKeyRef = ref
        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    // MARK: - Conflict detection

    /// Проверка через системные symbolic hotkeys: вернёт текстовое описание конфликта или nil.
    static func systemConflict(for hotkey: FocusHotkey) -> String? {
        var arrayRef: Unmanaged<CFArray>?
        let status = CopySymbolicHotKeys(&arrayRef)
        guard status == noErr, let unmanaged = arrayRef else { return nil }
        let array = unmanaged.takeRetainedValue() as? [[String: Any]] ?? []

        for entry in array {
            guard let enabled = entry[kHISymbolicHotKeyEnabled as String] as? Bool, enabled,
                  let kc = entry[kHISymbolicHotKeyCode as String] as? Int,
                  let mods = entry[kHISymbolicHotKeyModifiers as String] as? Int
            else { continue }

            if UInt32(kc) == hotkey.keyCode && UInt32(mods) == hotkey.modifiers {
                return "macOS already uses this combination"
            }
        }
        return nil
    }

    // MARK: - Internal handler

    private func installHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, eventRef, userData -> OSStatus in
                guard let eventRef, let userData else { return noErr }
                var hkID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard status == noErr else { return status }

                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    manager.onTrigger?()
                }
                return noErr
            },
            1,
            &spec,
            selfPtr,
            &eventHandler
        )
    }
}
