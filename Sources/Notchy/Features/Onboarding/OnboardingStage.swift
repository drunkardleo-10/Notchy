import SwiftUI

struct OnboardingStage: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        if let kind = model.waitingForSettings {
            SettingsWaitCard(kind: kind) { model.returnFromSettings() }
                .padding(.horizontal, 22)
                .foregroundStyle(.white)
                .transition(.opacity)
        } else {
            steps
                .transition(.opacity)
        }
    }

    private var steps: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .top) {
                stepView
                    .id(model.step)
                    .transition(.onboardingStep(direction: model.direction))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if model.step.showsFooter {
                OnboardingFooter(model: model)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 22)
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var stepView: some View {
        switch model.step {
        case .welcome: WelcomeStep(model: model)
        case .modules: ModulesStep()
        case .appearance: AppearanceStep()
        case .agents: AgentRadarStep(radar: model.radar)
        case .permission(let kind): PermissionStep(kind: kind, model: model)
        case .playground: PlaygroundStep(model: model)
        case .finish: FinishStep(model: model)
        }
    }
}

private struct OnboardingFooter: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        HStack(spacing: 12) {
            OnboardingButton(title: "Back", prominent: false) { model.back() }
                .opacity(model.canGoBack ? 1 : 0)
                .allowsHitTesting(model.canGoBack)
            Spacer()
            OnboardingProgress(index: model.progress.index, total: model.progress.total)
            Spacer()
            OnboardingButton(title: model.continueTitle, symbol: "arrow.right", prominent: model.continueProminent) {
                model.advance()
            }
            .animation(NotchAnimation.state, value: model.continueProminent)
        }
        .frame(height: 30)
    }
}
