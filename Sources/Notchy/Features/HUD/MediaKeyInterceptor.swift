import AppKit
import ApplicationServices

enum MediaKey: Int {
    case soundUp = 0
    case soundDown = 1
    case brightnessUp = 2
    case brightnessDown = 3
    case mute = 7
}

final class MediaKeyInterceptor {
    private weak var hudMonitor: HUDMonitor?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var checkTimer: Timer?

    init(hudMonitor: HUDMonitor) {
        self.hudMonitor = hudMonitor
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func handleAppDidBecomeActive() {
        if eventTap == nil {
            start()
        }
    }

    func start() {
        guard eventTap == nil else { return }
        guard AXIsProcessTrusted() else {
            promptAccessibilityIfNeeded()
            return
        }
        checkTimer?.invalidate()
        checkTimer = nil

        let mask = CGEventMask(1 << 14)
        let callback: CGEventTapCallBack = { proxy, type, cgEvent, userInfo in
            guard let userInfo else { return Unmanaged.passRetained(cgEvent) }
            let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
            return interceptor.handleEvent(proxy: proxy, type: type, event: cgEvent)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else { return }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        checkTimer?.invalidate()
        checkTimer = nil
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func promptAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if checkTimer == nil {
            checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                if AXIsProcessTrusted() {
                    self?.start()
                }
            }
        }
    }

    private func shouldIntercept(_ key: MediaKey) -> Bool {
        switch key {
        case .soundUp, .soundDown, .mute:
            return Pref.bool(Pref.volumeHUD)
        case .brightnessUp, .brightnessDown:
            return Pref.bool(Pref.brightnessHUD)
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type.rawValue == 0xFFFF_FFFF || type.rawValue == 0xFFFF_FFFE {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard event.type != .null,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.type == .systemDefined,
              nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passRetained(event)
        }

        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF_0000) >> 16
        let stateByte = ((data1 & 0xFF00) >> 8)

        guard let key = MediaKey(rawValue: keyCode), shouldIntercept(key) else {
            return Unmanaged.passRetained(event)
        }

        if stateByte == 0xB {
            return nil
        }

        guard stateByte == 0xA else {
            return Unmanaged.passRetained(event)
        }

        let flags = nsEvent.modifierFlags
        let option = flags.contains(.option)
        let shift = flags.contains(.shift)

        DispatchQueue.main.async { [weak self] in
            self?.handleKey(key, option: option, shift: shift)
        }
        return nil
    }

    @MainActor
    private func handleKey(_ key: MediaKey, option: Bool, shift: Bool) {
        if option && !shift {
            switch key {
            case .soundUp, .soundDown, .mute:
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") {
                    NSWorkspace.shared.open(url)
                }
            case .brightnessUp, .brightnessDown:
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.displays") {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }

        let fine = option && shift
        let shiftOnly = shift && !option
        switch key {
        case .soundUp:
            hudMonitor?.stepVolume(up: true, fine: fine, shiftOnly: shiftOnly)
        case .soundDown:
            hudMonitor?.stepVolume(up: false, fine: fine, shiftOnly: shiftOnly)
        case .mute:
            hudMonitor?.toggleMute()
        case .brightnessUp:
            hudMonitor?.stepBrightness(up: true, fine: fine)
        case .brightnessDown:
            hudMonitor?.stepBrightness(up: false, fine: fine)
        }
    }

    deinit {
        stop()
    }
}
