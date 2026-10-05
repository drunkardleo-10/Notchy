import Foundation

enum Pref {
    static let shelf = "enableShelf"
    static let basket = "enableBasket"
    static let clipboard = "enableClipboard"
    static let media = "enableMedia"
    static let hoverOpen = "hoverToOpen"
    static let expandOnMainDisplay = "expandOnMainDisplay"
    static let expandOnExternalDisplays = "expandOnExternalDisplays"
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
    static let shortcuts = "enableShortcuts"
    static let mirror = "enableMirror"
    static let volumeHUD = "enableVolumeHUD"
    static let volumeHUDStyle = "volumeHUDStyle"
    static let brightnessHUD = "enableBrightnessHUD"
    static let airpodsHUD = "enableAirPodsHUD"
    static let glassLevel = "dynamicGlassLevel"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            media: true,
            shelf: false, basket: false, clipboard: false,
            timer: false, tools: false,
            calendar: false, claude: false, system: false, shortcuts: false, mirror: false,
            hoverOpen: true, expandOnMainDisplay: true, expandOnExternalDisplays: false,
            expandDelay: 0.25, notchAnimationSpeed: NotchAnimationSpeed.normal.rawValue,
            hapticFeedback: true, clipboardLimit: 50, islandMode: false,
            liveActivity: true, browserMedia: true,
            pausedActivityTimeout: 5,
            lockHUD: true, batteryHUD: true, capsLockHUD: true,
            volumeHUD: true, brightnessHUD: true, airpodsHUD: true,
            volumeHUDStyle: VolumeHUDStyle.inline.rawValue,
            glassLevel: 0.5,
        ])
    }

    static func bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
    static func double(_ key: String) -> Double { UserDefaults.standard.double(forKey: key) }
}
