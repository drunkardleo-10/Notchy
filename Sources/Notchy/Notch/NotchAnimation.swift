import SwiftUI
import AppKit

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
        return .spring(response: 0.47 * mult, dampingFraction: 0.76, blendDuration: 0)
    }

    static func notchClose(for screen: NSScreen? = nil) -> Animation {
        let mult = rateMultiplier(for: screen)
        return .spring(response: 0.54 * mult, dampingFraction: 0.90, blendDuration: 0)
    }

    static func notchPressDown(for screen: NSScreen? = nil) -> Animation {
        let mult = rateMultiplier(for: screen)
        return .spring(response: 0.16 * mult, dampingFraction: 0.80, blendDuration: 0)
    }

    static func notchPressRelease(for screen: NSScreen? = nil) -> Animation {
        let mult = rateMultiplier(for: screen)
        return .spring(response: 0.18 * mult, dampingFraction: 0.80, blendDuration: 0)
    }

    static var state: Animation {
        .spring(response: 0.27, dampingFraction: 0.80, blendDuration: 0)
    }

    static var stateEmphasis: Animation {
        .spring(response: 0.20, dampingFraction: 0.80, blendDuration: 0)
    }

    static var controlMorph: Animation {
        .spring(response: 0.18, dampingFraction: 0.80, blendDuration: 0)
    }

    static var panelSlide: Animation {
        .spring(response: 0.18, dampingFraction: 0.80, blendDuration: 0)
    }

    static var tabSelect: Animation {
        .spring(response: 0.16, dampingFraction: 0.80, blendDuration: 0)
    }

    static var hover: Animation {
        .spring(response: 0.14, dampingFraction: 0.80, blendDuration: 0)
    }

    static var hoverQuick: Animation {
        .spring(response: 0.10, dampingFraction: 0.80, blendDuration: 0)
    }

    static var hoverScale: Animation {
        .spring(response: 0.12, dampingFraction: 0.80, blendDuration: 0)
    }

    static var press: Animation {
        .spring(response: 0.14, dampingFraction: 0.82, blendDuration: 0)
    }

    static var pressSnap: Animation {
        .spring(response: 0.18, dampingFraction: 0.62, blendDuration: 0)
    }

    static var pressSettle: Animation {
        .spring(response: 0.78, dampingFraction: 0.80, blendDuration: 0)
    }

    static var release: Animation {
        .spring(response: 0.74, dampingFraction: 0.80, blendDuration: 0)
    }

    static var bounce: Animation {
        .spring(response: 0.20, dampingFraction: 0.60, blendDuration: 0)
    }

    static var drag: Animation {
        .spring(response: 0.10, dampingFraction: 0.90, blendDuration: 0.25)
    }

    static var listChange: Animation {
        .spring(response: 0.27, dampingFraction: 0.80, blendDuration: 0)
    }
}
