import SwiftUI

@MainActor
final class OnboardingIntro: ObservableObject {
    enum Stage { case hidden, peek, duck, walk, wave, hop, depart, approach, farewell, gone }

    @Published private(set) var stage: Stage = .hidden

    var greeting: Bool { stage == .wave || stage == .hop }
    var parting: Bool { stage == .farewell }
    var showsBubble: Bool { greeting || parting }

    func reset() {
        stage = .hidden
    }

    func play(reduceMotion: Bool) async {
        if reduceMotion {
            stage = .wave
            try? await Task.sleep(for: .seconds(2.2))
            return
        }
        try? await Task.sleep(for: .seconds(0.6))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { stage = .peek }
        try? await Task.sleep(for: .seconds(0.9))
        withAnimation(.easeIn(duration: 0.18)) { stage = .duck }
        try? await Task.sleep(for: .seconds(0.4))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { stage = .peek }
        try? await Task.sleep(for: .seconds(0.6))
        withAnimation(.linear(duration: 1.1)) { stage = .walk }
        try? await Task.sleep(for: .seconds(1.1))
        OnboardingFeedback.blip()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { stage = .wave }
        try? await Task.sleep(for: .seconds(2.1))
        stage = .hop
        try? await Task.sleep(for: .seconds(0.6))
    }

    func playOutro(reduceMotion: Bool) async {
        if reduceMotion {
            stage = .farewell
            try? await Task.sleep(for: .seconds(1.6))
            stage = .gone
            return
        }
        stage = .depart
        try? await Task.sleep(for: .milliseconds(30))
        withAnimation(.timingCurve(0.2, 0.0, 0.2, 1.0, duration: OnboardingIntroLayout.outroDuration)) { stage = .approach }
        try? await Task.sleep(for: .seconds(OnboardingIntroLayout.outroDuration))
        OnboardingFeedback.blip()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { stage = .farewell }
        try? await Task.sleep(for: .seconds(1.7))
        withAnimation(.easeIn(duration: 0.35)) { stage = .gone }
        try? await Task.sleep(for: .seconds(0.4))
    }
}
