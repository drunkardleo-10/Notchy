import AppKit
import AudioToolbox
import CoreAudio
import IOBluetooth
import IOKit.ps

enum HUDKind: Equatable {
    case volume(Float, muted: Bool)
    case brightness(Float)
    case airpods(name: String, battery: String?)
    case battery(percent: Int, state: BatteryState)
    case lock(unlocked: Bool)
    case capsLock(on: Bool)
    case message(icon: String, title: String, subtitle: String)
}

enum BatteryState: Equatable { case charging, onBattery, low, full }

struct HUDEvent: Equatable {
    let id = UUID()
    let kind: HUDKind
}

@MainActor
final class HUDMonitor: NSObject {
    private weak var state: NotchState?
    private var hideWork: DispatchWorkItem?

    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var lastVolume: Float = -1
    private var lastMuted = false

    private var lastBrightness: Float = -1
    private var brightnessTimer: Timer?
    private typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private var getBrightness: GetBrightness?

    private var lastOnAC: Bool?
    private var lastPercent = 100
    private var lastCaps = false
    private var capsTimer: Timer?

    init(state: NotchState) {
        self.state = state
        super.init()
        setUpVolume()
        setUpBrightness()
        setUpPower()
        setUpLock()
        setUpCapsLock()
        IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
    }


    private func show(_ kind: HUDKind, duration: TimeInterval) {
        guard let state, !state.expanded else { return }
        state.hud = HUDEvent(kind: kind)
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.state?.hud = nil }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    func showMessage(icon: String, title: String, subtitle: String, duration: TimeInterval = 3) {
        show(.message(icon: icon, title: title, subtitle: subtitle), duration: duration)
    }


    private func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private func setUpVolume() {
        attachToDefaultDevice()
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.attachToDefaultDevice() }
        }
    }

    private func attachToDefaultDevice() {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown else { return }
        deviceID = id
        lastVolume = readVolume() ?? -1
        lastMuted = readMuted()
        for selector in [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyMute] {
            var a = address(selector)
            AudioObjectAddPropertyListenerBlock(id, &a, .main) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.volumeChanged() }
            }
        }
    }

    private func readVolume() -> Float? {
        var addr = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        var vol: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &vol) == noErr else { return nil }
        return vol
    }

    private func readMuted() -> Bool {
        var addr = address(kAudioDevicePropertyMute)
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &muted) == noErr else { return false }
        return muted != 0
    }

    private func volumeChanged() {
        guard Pref.bool(Pref.volumeHUD), let vol = readVolume() else { return }
        let muted = readMuted()
        guard vol != lastVolume || muted != lastMuted else { return }
        lastVolume = vol
        lastMuted = muted
        show(.volume(vol, muted: muted), duration: 1.6)
    }


    private func setUpBrightness() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
           let sym = dlsym(handle, "DisplayServicesGetBrightness") {
            getBrightness = unsafeBitCast(sym, to: GetBrightness.self)
        }
        guard getBrightness != nil else { return }
        lastBrightness = readBrightness() ?? -1
        brightnessTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollBrightness() }
        }
    }

    private func builtInDisplay() -> CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        CGGetActiveDisplayList(8, &ids, &count)
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    private func readBrightness() -> Float? {
        guard let getBrightness, let display = builtInDisplay() else { return nil }
        var value: Float = 0
        return getBrightness(display, &value) == 0 ? value : nil
    }

    private func pollBrightness() {
        guard Pref.bool(Pref.brightnessHUD), let value = readBrightness() else { return }
        defer { lastBrightness = value }
        guard lastBrightness >= 0 else { return }
        if abs(value - lastBrightness) >= 0.03 { show(.brightness(value), duration: 1.6) }
    }


    private func powerInfo() -> (percent: Int, onAC: Bool)? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let source = list.first,
              let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
              let percent = info[kIOPSCurrentCapacityKey] as? Int else { return nil }
        return (percent, (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue)
    }

    private func setUpPower() {
        guard let initial = powerInfo() else { return }
        lastOnAC = initial.onAC
        lastPercent = initial.percent
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<HUDMonitor>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { MainActor.assumeIsolated { monitor.powerChanged() } }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    private func powerChanged() {
        guard let info = powerInfo() else { return }
        defer { lastOnAC = info.onAC; lastPercent = info.percent }
        guard Pref.bool(Pref.batteryHUD) else { return }
        if let was = lastOnAC, was != info.onAC {
            show(.battery(percent: info.percent, state: info.onAC ? .charging : .onBattery), duration: 3)
        } else if info.onAC, info.percent == 100, lastPercent < 100 {
            show(.battery(percent: 100, state: .full), duration: 3)
        } else if !info.onAC, info.percent < lastPercent, info.percent == 20 || info.percent == 10 || info.percent == 5 {
            show(.battery(percent: info.percent, state: .low), duration: 4)
        }
    }


    private func setUpLock() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lockChanged(unlocked: false) }
        }
        center.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lockChanged(unlocked: true) }
        }
    }

    private func lockChanged(unlocked: Bool) {
        guard Pref.bool(Pref.lockHUD) else { return }
        guard unlocked else { show(.lock(unlocked: false), duration: 1.5); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.show(.lock(unlocked: false), duration: 2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { self?.show(.lock(unlocked: true), duration: 1.6) }
        }
    }


    private func setUpCapsLock() {
        lastCaps = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
        capsTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let on = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
                guard on != self.lastCaps else { return }
                self.lastCaps = on
                if Pref.bool(Pref.capsLockHUD) { self.show(.capsLock(on: on), duration: 1.5) }
            }
        }
    }


    @objc nonisolated func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let name = device.name ?? "Bluetooth device"
        let isAudio = device.deviceClassMajor == 4
            || ["airpods", "beats", "headphones", "buds"].contains { name.lowercased().contains($0) }
        guard isAudio else { return }
        DispatchQueue.main.async { MainActor.assumeIsolated { self.bluetoothAudioConnected(name) } }
    }

    private func bluetoothAudioConnected(_ name: String) {
        guard Pref.bool(Pref.airpodsHUD) else { return }
        show(.airpods(name: name, battery: nil), duration: 3.5)
        DispatchQueue.global(qos: .utility).async {
            Thread.sleep(forTimeInterval: 2)
            let battery = Self.batteryText(for: name)
            guard let battery else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if case .airpods(let current, _)? = self.state?.hud?.kind, current == name {
                        self.show(.airpods(name: name, battery: battery), duration: 3.5)
                    }
                }
            }
        }
    }

    nonisolated private static func batteryText(for name: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        proc.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        guard (try? proc.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let section = (root["SPBluetoothDataType"] as? [[String: Any]])?.first,
              let connected = section["device_connected"] as? [[String: [String: Any]]] else { return nil }
        for entry in connected {
            guard let info = entry[name] else { continue }
            let parts = [("L", "device_batteryLevelLeft"), ("R", "device_batteryLevelRight"),
                         ("Case", "device_batteryLevelCase"), ("", "device_batteryLevelMain")]
                .compactMap { label, key in (info[key] as? String).map { label.isEmpty ? $0 : "\(label) \($0)" } }
            return parts.isEmpty ? nil : parts.joined(separator: "  ")
        }
        return nil
    }
}
