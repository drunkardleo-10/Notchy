import AppKit
import AVFoundation
import CoreLocation
import CoreServices
import EventKit

enum PermissionStatus {
    case granted, denied, undetermined, unavailable
}

enum PermissionKind: String, Hashable, CaseIterable {
    case accessibility, automation, calendar, location, camera

    static let mediaBundleIDs = ["com.spotify.client", "com.apple.Music"]
    private static let locationManager = CLLocationManager()

    var title: String {
        switch self {
        case .accessibility: "Volume and brightness keys"
        case .automation: "Music and Spotify"
        case .calendar: "Calendar"
        case .location: "Weather"
        case .camera: "Camera mirror"
        }
    }

    var reason: String {
        switch self {
        case .accessibility: "I'll replace the system volume and brightness overlay with my own. I only listen for media keys."
        case .automation: "I need this to show the current track and control playback in Music and Spotify."
        case .calendar: "I'll show your next meeting and a join button, right in the notch."
        case .location: "I use your approximate location for weather and sunrise on the lock screen."
        case .camera: "I can turn into a quick mirror. The camera only runs while Mirror is open."
        }
    }

    var shortTitle: String {
        switch self {
        case .accessibility: "Media keys"
        case .automation: "Music"
        case .calendar: "Calendar"
        case .location: "Weather"
        case .camera: "Camera"
        }
    }

    var unlocks: String {
        switch self {
        case .accessibility: "Volume and brightness HUD"
        case .automation: "Now playing and controls"
        case .calendar: "Next meeting with join button"
        case .location: "Weather and sunrise widgets"
        case .camera: "Mirror module"
        }
    }

    var thanks: String {
        switch self {
        case .accessibility: "Thanks. Now press a volume key."
        case .automation: "Thanks. I can see what's playing."
        case .calendar: "Thanks. Here's what's next."
        case .location: "Thanks. Here's your weather."
        case .camera: "Thanks. Looking good."
        }
    }

    var symbol: String {
        switch self {
        case .accessibility: "speaker.wave.2.fill"
        case .automation: "music.note"
        case .calendar: "calendar"
        case .location: "cloud.sun.fill"
        case .camera: "camera.fill"
        }
    }

    var actionTitle: String {
        switch self {
        case .accessibility: "Open System Settings"
        default: "Allow"
        }
    }

    private var settingsAnchor: String {
        switch self {
        case .accessibility: "Privacy_Accessibility"
        case .automation: "Privacy_Automation"
        case .calendar: "Privacy_Calendars"
        case .location: "Privacy_LocationServices"
        case .camera: "Privacy_Camera"
        }
    }

    static func needed() -> [PermissionKind] {
        var kinds: [PermissionKind] = [.accessibility]
        if Pref.bool(Pref.media) { kinds.append(.automation) }
        if Pref.bool(Pref.calendar) { kinds.append(.calendar) }
        if Pref.bool(Pref.lockWidgets) { kinds.append(.location) }
        if Pref.bool(Pref.mirror) { kinds.append(.camera) }
        return kinds
    }

    @MainActor
    var status: PermissionStatus {
        switch self {
        case .accessibility:
            return AXIsProcessTrusted() ? .granted : .undetermined
        case .automation:
            guard let target = Self.automationTarget else { return .unavailable }
            return Self.automationStatus(target, ask: false)
        case .calendar:
            switch EKEventStore.authorizationStatus(for: .event) {
            case .fullAccess: return .granted
            case .notDetermined: return .undetermined
            default: return .denied
            }
        case .location:
            switch Self.locationManager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse: return .granted
            case .notDetermined: return .undetermined
            default: return .denied
            }
        case .camera:
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: return .granted
            case .notDetermined: return .undetermined
            default: return .denied
            }
        }
    }

    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(settingsAnchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    static var automationTarget: String? {
        mediaBundleIDs.first { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty }
    }

    nonisolated static func automationStatus(_ bundleID: String, ask: Bool) -> PermissionStatus {
        var target = AEAddressDesc()
        let bytes = Array(bundleID.utf8)
        guard AECreateDesc(DescType(typeApplicationBundleID), bytes, bytes.count, &target) == noErr else { return .unavailable }
        defer { AEDisposeDesc(&target) }
        let result = AEDeterminePermissionToAutomateTarget(&target, AEEventClass(typeWildCard), AEEventID(typeWildCard), ask)
        switch result {
        case noErr: return .granted
        case OSStatus(errAEEventWouldRequireUserConsent): return .undetermined
        case OSStatus(errAEEventNotPermitted): return .denied
        default: return .unavailable
        }
    }
}
