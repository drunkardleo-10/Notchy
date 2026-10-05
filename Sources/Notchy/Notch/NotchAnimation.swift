import SwiftUI
import AppKit

enum NotchAnimationSpeed: String, CaseIterable, Identifiable {
    case slow
    case normal
    case fast
    case fastest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slow: "Slow"
        case .normal: "Normal"
        case .fast: "Fast"
        case .fastest: "Fastest"
        }
    }

    var icon: String {
        switch self {
        case .slow: "tortoise.fill"
        case .normal: "figure.stand"
        case .fast: "hare.fill"
        case .fastest: "bolt.fill"
        }
    }

    var responseMultiplier: Double {
        switch self {
        case .slow: 1.55
        case .normal: 1
        case .fast: 0.72
        case .fastest: 0.5
        }
    }

    static var current: Self {
        let rawValue = UserDefaults.standard.string(forKey: Pref.notchAnimationSpeed) ?? Self.normal.rawValue
        return Self(rawValue: rawValue) ?? .normal
    }
}

enum NotchAnimation {
    static func rateMultiplier(for screen: NSScreen? = nil) -> Double {
        let target = screen ?? NSScreen.main
        let maxFPS = target?.maximumFramesPerSecond ?? 60
        if maxFPS < 75 {
            return 1.18
        } else if maxFPS < 100 {
            return 1.10
        }
        return 1.0
    }

    static func notchOpen(for screen: NSScreen? = nil) -> Animation {
        let mult = rateMultiplier(for: screen)
        return spring(response: 0.47 * mult, dampingFraction: 0.76)
    }

    static func notchClose(for screen: NSScreen? = nil) -> Animation {
        let mult = rateMultiplier(for: screen)
        return spring(response: 0.54 * mult, dampingFraction: 0.90)
    }

    static func notchPressDown(for screen: NSScreen? = nil) -> Animation {
        let mult = rateMultiplier(for: screen)
        return spring(response: 0.16 * mult, dampingFraction: 0.80)
    }

    static func notchPressRelease(for screen: NSScreen? = nil) -> Animation {
        let mult = rateMultiplier(for: screen)
        return spring(response: 0.18 * mult, dampingFraction: 0.80)
    }

    static func spring(response: Double, dampingFraction: Double, blendDuration: Double = 0) -> Animation {
        .spring(
            response: response * NotchAnimationSpeed.current.responseMultiplier,
            dampingFraction: dampingFraction,
            blendDuration: blendDuration
        )
    }

    static var state: Animation {
        spring(response: 0.27, dampingFraction: 0.80)
    }

    static var stateEmphasis: Animation {
        spring(response: 0.20, dampingFraction: 0.80)
    }

    static var controlMorph: Animation {
        spring(response: 0.18, dampingFraction: 0.80)
    }

    static var panelSlide: Animation {
        spring(response: 0.18, dampingFraction: 0.80)
    }

    static var tabSelect: Animation {
        spring(response: 0.16, dampingFraction: 0.80)
    }

    static var hover: Animation {
        spring(response: 0.14, dampingFraction: 0.80)
    }

    static var hoverQuick: Animation {
        spring(response: 0.10, dampingFraction: 0.80)
    }

    static var press: Animation {
        spring(response: 0.14, dampingFraction: 0.82)
    }

    static var pressSnap: Animation {
        spring(response: 0.18, dampingFraction: 0.62)
    }

    static var pressSettle: Animation {
        spring(response: 0.78, dampingFraction: 0.80)
    }

    static var release: Animation {
        spring(response: 0.74, dampingFraction: 0.80)
    }

    static var bounce: Animation {
        spring(response: 0.20, dampingFraction: 0.60)
    }

    static var drag: Animation {
        spring(response: 0.10, dampingFraction: 0.90, blendDuration: 0.25)
    }

    static var listChange: Animation {
        spring(response: 0.27, dampingFraction: 0.80)
    }
}
