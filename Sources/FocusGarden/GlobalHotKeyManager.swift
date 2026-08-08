import AppKit
import Carbon.HIToolbox

@MainActor
final class GlobalHotKeyManager {
    private var hotKeyReference: EventHotKeyRef?
    private var eventHandlerReference: EventHandlerRef?
    private var action: (() -> Void)?

    @discardableResult
    func register(action: @escaping () -> Void) -> Bool {
        unregister()
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            focusGardenHotKeyHandler,
            1,
            &eventType,
            userData,
            &eventHandlerReference
        )
        guard handlerStatus == noErr else { return false }

        let hotKeyID = EventHotKeyID(signature: 0x4647484B, id: 1) // FGHK
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_F),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyReference
        )
        return registerStatus == noErr
    }

    func unregister() {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
            self.hotKeyReference = nil
        }
        if let eventHandlerReference {
            RemoveEventHandler(eventHandlerReference)
            self.eventHandlerReference = nil
        }
        action = nil
    }

    fileprivate func invoke() {
        action?()
    }
}

private let focusGardenHotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr, hotKeyID.id == 1 else { return status }

    let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        manager.invoke()
    }
    return noErr
}

@MainActor
enum AppActivation {
    static func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
