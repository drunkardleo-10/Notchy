import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var onGlassPreviewChanged: (Bool) -> Void = { _ in }
    var onDisplayConfigurationChanged: () -> Void = {}
    var onCheckForUpdates: () -> Void = {}

    @AppStorage(Pref.media) private var media = true
    @AppStorage(Pref.shelf) private var shelf = false
    @AppStorage(Pref.basket) private var basket = false
    @AppStorage(Pref.clipboard) private var clipboard = false
    @AppStorage(Pref.timer) private var timer = false
    @AppStorage(Pref.tools) private var tools = false
    @AppStorage(Pref.calendar) private var calendar = false
    @AppStorage(Pref.claude) private var claude = false
    @AppStorage(Pref.system) private var system = false
    @AppStorage(Pref.mirror) private var mirror = false

    @AppStorage(Pref.liveActivity) private var liveActivity = true
    @AppStorage(Pref.browserMedia) private var browserMedia = true
    @AppStorage(Pref.pausedActivityTimeout) private var pausedActivityTimeout = 5.0

    @AppStorage(Pref.volumeHUD) private var volumeHUD = true
    @AppStorage(Pref.volumeHUDStyle) private var volumeHUDStyle = VolumeHUDStyle.inline.rawValue
    @AppStorage(Pref.brightnessHUD) private var brightnessHUD = true
    @AppStorage(Pref.airpodsHUD) private var airpodsHUD = true
    @AppStorage(Pref.batteryHUD) private var batteryHUD = true
    @AppStorage(Pref.lockHUD) private var lockHUD = true
    @AppStorage(Pref.capsLockHUD) private var capsLockHUD = true

    @AppStorage(Pref.hoverOpen) private var hoverOpen = true
    @AppStorage(Pref.notchDisplayMode) private var notchDisplayMode = NotchDisplayMode.main.rawValue
    @AppStorage(Pref.externalDisplayID) private var externalDisplayID = ""
    @AppStorage(Pref.expandDelay) private var expandDelay = 0.25
    @AppStorage(Pref.notchAnimationSpeed) private var animationSpeed = NotchAnimationSpeed.normal.rawValue
    @AppStorage(Pref.hapticFeedback) private var haptics = true
    @AppStorage(Pref.islandMode) private var island = false
    @AppStorage(Pref.glassLevel) private var glassLevel = 0.5
    @AppStorage(Pref.clipboardLimit) private var limit = 50
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var displayRefreshToken = 0
    @State private var selection: SettingsTab = .modules

    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.11).ignoresSafeArea()
            VStack(spacing: 0) {
                PillTabBar(selection: $selection)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                ZStack {
                    switch selection {
                    case .modules:
                        ModulesSettingsTab(
                            media: $media, shelf: $shelf, basket: $basket, clipboard: $clipboard,
                            timer: $timer, tools: $tools, calendar: $calendar, claude: $claude,
                            system: $system, mirror: $mirror
                        )
                    case .media:
                        MediaSettingsTab(
                            liveActivity: $liveActivity,
                            browserMedia: $browserMedia,
                            pausedActivityTimeout: $pausedActivityTimeout
                        )
                    case .huds:
                        HUDSettingsTab(
                            volumeHUD: $volumeHUD,
                            volumeHUDStyle: $volumeHUDStyle,
                            brightnessHUD: $brightnessHUD,
                            airpodsHUD: $airpodsHUD,
                            batteryHUD: $batteryHUD,
                            lockHUD: $lockHUD,
                            capsLockHUD: $capsLockHUD
                        )
                    case .general:
                        GeneralSettingsTab(
                            glassLevel: $glassLevel,
                            hoverOpen: $hoverOpen,
                            notchDisplayMode: $notchDisplayMode,
                            externalDisplayID: $externalDisplayID,
                            expandDelay: $expandDelay,
                            animationSpeed: $animationSpeed,
                            haptics: $haptics,
                            island: $island,
                            limit: $limit,
                            launchAtLogin: $launchAtLogin,
                            externalDisplays: externalDisplays,
                            onGlassPreviewChanged: onGlassPreviewChanged,
                            onCheckForUpdates: onCheckForUpdates
                        )
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selection)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .frame(width: 560, height: 600)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            displayRefreshToken += 1
            if !NotchGeometry.externalDisplays.contains(where: { NotchGeometry.screenID($0) == externalDisplayID }),
               let first = NotchGeometry.externalDisplays.first {
                externalDisplayID = NotchGeometry.screenID(first) ?? ""
            }
            onDisplayConfigurationChanged()
        }
        .onChange(of: notchDisplayMode) { _, rawValue in
            if rawValue == NotchDisplayMode.external.rawValue,
               !externalDisplays.contains(where: { NotchGeometry.screenID($0) == externalDisplayID }),
               let first = externalDisplays.first {
                externalDisplayID = NotchGeometry.screenID(first) ?? ""
            }
            onDisplayConfigurationChanged()
        }
        .onChange(of: externalDisplayID) { _, _ in onDisplayConfigurationChanged() }
    }

    private var externalDisplays: [NSScreen] {
        _ = displayRefreshToken
        return NotchGeometry.externalDisplays
    }
}
