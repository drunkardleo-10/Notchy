import Foundation

enum Pref {
    static let shelf = "enableShelf"
    static let basket = "enableBasket"
    static let clipboard = "enableClipboard"
    static let media = "enableMedia"
    static let hoverOpen = "hoverToOpen"
    static let notchDisplayMode = "notchDisplayMode"
    static let externalDisplayID = "notchyExternalDisplayID"
    static let expandDelay = "expandDelay"
    static let notchAnimationSpeed = "notchAnimationSpeed"
    static let hapticFeedback = "hapticFeedback"
    static let clipboardLimit = "clipboardLimit"
    static let islandMode = "forceIslandMode"
    static let liveActivity = "enableLiveActivity"
    static let pausedActivityTimeout = "pausedActivityTimeout"
    static let browserMedia = "enableBrowserMedia"
    static let lockHUD = "enableLockHUD"
    static let batteryHUD = "enableBatteryHUD"
    static let capsLockHUD = "enableCapsLockHUD"
    static let timer = "enableTimer"
    static let tools = "enableTools"
    static let calendar = "enableCalendar"
    static let claude = "enableClaude"
    static let system = "enableSystem"
    static let mirror = "enableMirror"
    static let volumeHUD = "enableVolumeHUD"
    static let volumeHUDStyle = "volumeHUDStyle"
    static let brightnessHUD = "enableBrightnessHUD"
    static let airpodsHUD = "enableAirPodsHUD"
    static let glassLevel = "dynamicGlassLevel"
    static let lockWidgets = "enableLockWidgets"
    static let widgetBattery = "lockWidgetBattery"
    static let widgetWeather = "lockWidgetWeather"
    static let widgetAirQuality = "lockWidgetAirQuality"
    static let widgetSun = "lockWidgetSun"
    static let widgetEvent = "lockWidgetEvent"
    static let widgetMedia = "lockWidgetMedia"
    static let lockWidgetsOffset = "lockWidgetsOffset"
    static let onboardingVersion = "onboardingVersion"
    static let onboardingResume = "onboardingResumeStep"

    private static let legacyBundleID = "com.leo.notchy"
    private static let legacyMigrated = "migratedLegacyDefaults"

    static func migrateLegacyDefaults() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: legacyMigrated) else { return }
        defaults.set(true, forKey: legacyMigrated)
        guard Bundle.main.bundleIdentifier != legacyBundleID,
              let legacy = defaults.persistentDomain(forName: legacyBundleID) else { return }
        for (key, value) in legacy where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            media: true,
            shelf: false, basket: false, clipboard: false,
            timer: false, tools: false,
            calendar: false, claude: false, system: false, mirror: false,
            hoverOpen: true, notchDisplayMode: NotchDisplayMode.main.rawValue,
            expandDelay: 0.25, notchAnimationSpeed: NotchAnimationSpeed.normal.rawValue,
            hapticFeedback: true, clipboardLimit: 50, islandMode: false,
            liveActivity: true, browserMedia: true,
            pausedActivityTimeout: 5,
            lockHUD: true, batteryHUD: true, capsLockHUD: true,
            volumeHUD: true, brightnessHUD: true, airpodsHUD: true,
            volumeHUDStyle: VolumeHUDStyle.inline.rawValue,
            glassLevel: 0.5,
            lockWidgets: false, widgetBattery: true, widgetWeather: true,
            widgetAirQuality: true, widgetSun: true, widgetEvent: false, widgetMedia: true,
            lockWidgetsOffset: 0.0,
        ])
    }

    static func bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
    static func double(_ key: String) -> Double { UserDefaults.standard.double(forKey: key) }
}
