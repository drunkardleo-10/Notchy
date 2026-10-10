import SwiftUI

enum OnboardingIntroLayout {
    static var sideWidth: CGFloat { LiveActivityLayout.sideWidth }
    static let outroDuration: Double = 1.15

    static func size(notch: CGSize) -> CGSize {
        LiveActivityLayout.size(notch: notch)
    }

    static func cell(notch: CGSize) -> CGFloat {
        let fitted = (notch.height - 6) / CGFloat(NotchyMascotSprites.rows)
        return max(1.25, min(2, (fitted * 4).rounded(.down) / 4))
    }

    @MainActor
    static func mascotX(stage: OnboardingIntro.Stage, notch: CGSize) -> CGFloat {
        let width = CGFloat(NotchyMascotSprites.columns) * cell(notch: notch)
        let edge = sideWidth
        switch stage {
        case .hidden, .gone: return edge + width / 2 + 6
        case .duck: return edge + width * 0.2
        case .peek: return edge - width * 0.05
        case .walk, .wave, .hop: return edge / 2
        case .depart: return -(NotchState.onboardingSize.width - size(notch: notch).width) / 2 + 70
        case .approach, .farewell: return edge - width / 2 - 1
        }
    }
}

struct OnboardingIntroView: View {
    @ObservedObject var intro: OnboardingIntro
    let notch: CGSize
    var outro = false
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pose: NotchyPose {
        switch intro.stage {
        case .hidden, .peek, .duck: .idle
        case .walk, .depart, .approach, .gone: .walk
        case .wave, .farewell: .wave
        case .hop: .cheer
        }
    }

    var body: some View {
        let cell = OnboardingIntroLayout.cell(notch: notch)
        NotchyMascot(pose: pose, cell: cell)
            .position(x: OnboardingIntroLayout.mascotX(stage: intro.stage, notch: notch), y: notch.height / 2)
            .frame(width: OnboardingIntroLayout.size(notch: notch).width, height: notch.height, alignment: .topLeading)
            .task(id: outro) {
                if outro {
                    await intro.playOutro(reduceMotion: reduceMotion)
                } else {
                    await intro.play(reduceMotion: reduceMotion)
                }
                onFinish()
            }
    }
}

struct OnboardingIntroBubble: View {
    @ObservedObject var intro: OnboardingIntro
    let notch: CGSize

    var body: some View {
        let x = OnboardingIntroLayout.mascotX(stage: intro.stage, notch: notch)
        SpeechBubble(tail: .top, style: .light) {
            Text(intro.parting ? "See you around" : "Hi, I'm Notchy")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)
        }
        .fixedSize()
        .scaleEffect(intro.showsBubble ? 1 : 0.6, anchor: .topLeading)
        .opacity(intro.showsBubble ? 1 : 0)
        .offset(x: x - BubbleShape.tailInset, y: notch.height + 6)
        .animation(.spring(response: 0.4, dampingFraction: 0.68), value: intro.showsBubble)
        .allowsHitTesting(false)
    }
}
