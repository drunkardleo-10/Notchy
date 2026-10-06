import AppKit
import AudioToolbox
import CoreAudio

@MainActor
final class HUDMonitor: NSObject {
    private let states: () -> [NotchState]
    private lazy var systemEventMonitor = HUDSystemEventMonitor(states: states) { [weak self] kind, duration in
        self?.show(kind, duration: duration)
    }
    private var hideWork: DispatchWorkItem?

    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var lastVolume: Float = -1
    private var lastMuted = false

    private var mediaKeyInterceptor: MediaKeyInterceptor?
    private let feedbackSound = NSSound(contentsOfFile: "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff", byReference: true)

    init(states: @escaping () -> [NotchState]) {
        self.states = states
        super.init()
        setUpVolume()
        systemEventMonitor.start()
        mediaKeyInterceptor = MediaKeyInterceptor(hudMonitor: self)
        mediaKeyInterceptor?.start()
    }


    private func show(_ kind: HUDKind, duration: TimeInterval) {
        let visibleStates = states().filter { !$0.expanded }
        guard !visibleStates.isEmpty else { return }
        for state in visibleStates { state.hud = HUDEvent(kind: kind) }
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            for state in self?.states() ?? [] { state.hud = nil }
        }
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


    func setVolume(_ volume: Float) {
        guard deviceID != kAudioObjectUnknown else { return }
        let clamped = max(0, min(1, volume))
        var addr = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        var vol: Float32 = clamped
        let size = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &vol) != noErr {
            var scalarAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectSetPropertyData(deviceID, &scalarAddr, 0, nil, size, &vol) != noErr {
                for ch: UInt32 in 1...2 {
                    var chAddr = AudioObjectPropertyAddress(
                        mSelector: kAudioDevicePropertyVolumeScalar,
                        mScope: kAudioDevicePropertyScopeOutput,
                        mElement: ch
                    )
                    _ = AudioObjectSetPropertyData(deviceID, &chAddr, 0, nil, size, &vol)
                }
            }
        }
        lastVolume = clamped
    }

    func setMuted(_ muted: Bool) {
        guard deviceID != kAudioObjectUnknown else { return }
        var addr = address(kAudioDevicePropertyMute)
        var val: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        _ = AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &val)
        lastMuted = muted
    }

    func stepVolume(up: Bool, fine: Bool, shiftOnly: Bool) {
        guard Pref.bool(Pref.volumeHUD) else { return }
        let current = readVolume() ?? (lastVolume >= 0 ? lastVolume : 0.5)
        let step: Float = (1.0 / 16.0) / (fine ? 4.0 : 1.0)
        let next = max(0, min(1, current + (up ? step : -step)))
        if readMuted() {
            setMuted(false)
        }
        setVolume(next)
        playFeedbackSoundIfNeeded(shiftOnly: shiftOnly)
        show(.volume(next, muted: false), duration: 1.6)
    }

    func toggleMute() {
        guard Pref.bool(Pref.volumeHUD) else { return }
        let currentMuted = readMuted()
        let nextMuted = !currentMuted
        setMuted(nextMuted)
        let current = readVolume() ?? (lastVolume >= 0 ? lastVolume : 0.5)
        show(.volume(current, muted: nextMuted), duration: 1.6)
    }

    private func playFeedbackSoundIfNeeded(shiftOnly: Bool) {
        let feedbackPref = (UserDefaults.standard.persistentDomain(forName: "NSGlobalDomain")?["com.apple.sound.beep.feedback"] as? Int) == 1
        let shouldPlay = shiftOnly ? !feedbackPref : feedbackPref
        guard shouldPlay else { return }
        if let sound = feedbackSound {
            if sound.isPlaying {
                sound.stop()
            }
            sound.play()
        }
    }

    func setBrightness(_ value: Float) {
        systemEventMonitor.setBrightness(value)
    }

    func stepBrightness(up: Bool, fine: Bool) {
        systemEventMonitor.stepBrightness(up: up, fine: fine)
    }
}
