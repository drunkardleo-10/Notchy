import AppKit

@MainActor
enum OnboardingFeedback {
    static func tick() {
        haptic(.alignment)
    }

    static func blip() {
        play("Pop", volume: 0.35)
        haptic(.levelChange)
    }

    static func success() {
        play("Glass", volume: 0.5)
        haptic(.generic)
    }

    private static func play(_ name: String, volume: Float) {
        guard let sound = NSSound(named: name)?.copy() as? NSSound else { return }
        sound.volume = volume
        sound.play()
    }

    private static func haptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard Pref.bool(Pref.hapticFeedback) else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}
