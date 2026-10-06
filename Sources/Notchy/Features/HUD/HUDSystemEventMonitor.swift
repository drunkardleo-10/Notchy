import AppKit
import CoreGraphics
import Foundation
import IOBluetooth
import IOKit.ps

@MainActor
final class HUDSystemEventMonitor: NSObject {
    private let states: () -> [NotchState]
    private let showEvent: (HUDKind, TimeInterval) -> Void

    private var lastBrightness: Float = -1
    private var brightnessTimer: Timer?
    private typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private var getBrightness: GetBrightness?
    private typealias SetBrightness = @convention(c) (UInt32, Float) -> Int32
    private var setBrightness: SetBrightness?

    private var lastOnAC: Bool?
    private var lastPercent = 100
    private var lastCaps = false
    private var capsTimer: Timer?

    init(states: @escaping () -> [NotchState], showEvent: @escaping (HUDKind, TimeInterval) -> Void) {
        self.states = states
        self.showEvent = showEvent
        super.init()
    }

    func start() {
        setUpBrightness()
        setUpPower()
        setUpLock()
        setUpCapsLock()
        IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
    }

    private func setUpBrightness() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) {
            if let sym = dlsym(handle, "DisplayServicesGetBrightness") {
                getBrightness = unsafeBitCast(sym, to: GetBrightness.self)
            }
            if let sym = dlsym(handle, "DisplayServicesSetBrightness") {
                setBrightness = unsafeBitCast(sym, to: SetBrightness.self)
            }
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
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 } ?? CGMainDisplayID()
    }

    private func readBrightness() -> Float? {
        guard let getBrightness, let display = builtInDisplay() else { return nil }
        var value: Float = 0
        return getBrightness(display, &value) == 0 ? value : nil
    }

    func setBrightness(_ value: Float) {
        guard let setBrightness, let display = builtInDisplay() else { return }
        let clamped = max(0, min(1, value))
        _ = setBrightness(display, clamped)
        lastBrightness = clamped
    }

    func stepBrightness(up: Bool, fine: Bool) {
        guard Pref.bool(Pref.brightnessHUD) else { return }
        let current = readBrightness() ?? (lastBrightness >= 0 ? lastBrightness : 0.5)
        let step: Float = (1.0 / 16.0) / (fine ? 4.0 : 1.0)
        let next = max(0, min(1, current + (up ? step : -step)))
        setBrightness(next)
        showEvent(.brightness(next), 1.6)
    }

    private func pollBrightness() {
        guard Pref.bool(Pref.brightnessHUD), let value = readBrightness() else { return }
        defer { lastBrightness = value }
        guard lastBrightness >= 0 else { return }
        if abs(value - lastBrightness) >= 0.03 { showEvent(.brightness(value), 1.6) }
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
            let monitor = Unmanaged<HUDSystemEventMonitor>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { MainActor.assumeIsolated { monitor.powerChanged() } }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    private func powerChanged() {
        guard let info = powerInfo() else { return }
        defer { lastOnAC = info.onAC; lastPercent = info.percent }
        guard Pref.bool(Pref.batteryHUD) else { return }
        if let was = lastOnAC, was != info.onAC {
            showEvent(.battery(percent: info.percent, state: info.onAC ? .charging : .onBattery), 3)
        } else if info.onAC, info.percent == 100, lastPercent < 100 {
            showEvent(.battery(percent: 100, state: .full), 3)
        } else if !info.onAC, info.percent < lastPercent, info.percent == 20 || info.percent == 10 || info.percent == 5 {
            showEvent(.battery(percent: info.percent, state: .low), 4)
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
        guard unlocked else { showEvent(.lock(unlocked: false), 1.5); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.showEvent(.lock(unlocked: false), 2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { self?.showEvent(.lock(unlocked: true), 1.6) }
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
                if Pref.bool(Pref.capsLockHUD) { self.showEvent(.capsLock(on: on), 1.5) }
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
        showEvent(.airpods(name: name, battery: nil), 3.5)
        DispatchQueue.global(qos: .utility).async {
            Thread.sleep(forTimeInterval: 2)
            let battery = Self.batteryText(for: name)
            guard let battery else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if self.states().contains(where: { state in
                        guard case .airpods(let current, _)? = state.hud?.kind else { return false }
                        return current == name
                    }) {
                        self.showEvent(.airpods(name: name, battery: battery), 3.5)
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
