import Foundation

enum OnboardingStep: Hashable {
    case welcome
    case modules
    case appearance
    case agents
    case permission(PermissionKind)
    case playground
    case finish

    var key: String {
        switch self {
        case .welcome: "welcome"
        case .modules: "modules"
        case .appearance: "appearance"
        case .agents: "agents"
        case .permission(let kind): "permission." + kind.rawValue
        case .playground: "playground"
        case .finish: "finish"
        }
    }

    init?(key: String) {
        if key.hasPrefix("permission."), let kind = PermissionKind(rawValue: String(key.dropFirst("permission.".count))) {
            self = .permission(kind)
            return
        }
        let simple: [OnboardingStep] = [.welcome, .modules, .appearance, .agents, .playground, .finish]
        guard let match = simple.first(where: { $0.key == key }) else { return nil }
        self = match
    }

    var showsFooter: Bool {
        switch self {
        case .welcome, .finish: false
        default: true
        }
    }
}

struct OnboardingModule: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let detail: String

    static let all: [OnboardingModule] = [
        OnboardingModule(id: Pref.media, title: "Media", symbol: "music.note",
                         detail: "Now playing, lyrics and a live visualizer around the notch."),
        OnboardingModule(id: Pref.claude, title: "Agents", symbol: "sparkles",
                         detail: "Watch coding agents work and answer their requests without switching windows."),
        OnboardingModule(id: Pref.calendar, title: "Calendar", symbol: "calendar",
                         detail: "Your next meetings, with a join button when they start."),
        OnboardingModule(id: Pref.shelf, title: "Shelf", symbol: "tray.full",
                         detail: "Drop files on the notch to keep them close."),
        OnboardingModule(id: Pref.clipboard, title: "Clipboard", symbol: "doc.on.clipboard",
                         detail: "Everything you copied, one hover away."),
        OnboardingModule(id: Pref.timer, title: "Timer", symbol: "timer",
                         detail: "Focus sessions that sit quietly beside the notch."),
        OnboardingModule(id: Pref.system, title: "System", symbol: "cpu",
                         detail: "CPU, memory, disk and network at a glance."),
        OnboardingModule(id: Pref.mirror, title: "Mirror", symbol: "camera.fill",
                         detail: "A quick camera check before your next call."),
        OnboardingModule(id: Pref.tools, title: "Tools", symbol: "wrench.and.screwdriver",
                         detail: "Keep your Mac awake and other handy switches."),
        OnboardingModule(id: Pref.lockWidgets, title: "Lock Screen", symbol: "lock.rectangle.stack",
                         detail: "Weather, battery and music widgets on your lock screen.")
    ]
}
