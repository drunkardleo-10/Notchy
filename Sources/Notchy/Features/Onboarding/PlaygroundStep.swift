import SwiftUI

struct PlaygroundStep: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            DemoRequestCard(answer: model.playgroundAnswer) { allowed in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { model.playgroundAnswer = allowed }
                allowed ? OnboardingFeedback.success() : OnboardingFeedback.tick()
            }
            .frame(width: 290)

            NotchyGuide(pose: guidePose, title: guideTitle, message: guideMessage, cell: 2)
        }
    }

    private var guidePose: NotchyPose {
        guard let answer = model.playgroundAnswer else { return .idle }
        return answer ? .cheer : .idle
    }

    private var guideTitle: String {
        switch model.playgroundAnswer {
        case .none: "Try answering Claude"
        case .some(true): "Allowed. Claude keeps going."
        case .some(false): "Denied. Claude will find another way."
        }
    }

    private var guideMessage: String {
        switch model.playgroundAnswer {
        case .none: "When an agent needs permission, I drop this card down wherever you are. Command-Y allows, Command-N denies."
        case .some: "Real requests look exactly like this, and you never have to leave what you're doing."
        }
    }
}

private struct DemoRequestCard: View {
    let answer: Bool?
    let respond: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                ClaudeSpark(size: 13)
                Text("Permission Request")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer(minLength: 8)
                Text("my-app")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.warning)
                Text("Bash")
                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(OnboardingTheme.warning)
                Text("Reinstall dependencies")
                    .font(.system(size: 12.5, design: .monospaced))
                    .lineLimit(1)
            }
            Text("$ rm -rf node_modules && npm install")
                .font(OnboardingTheme.mono)
                .foregroundStyle(.white.opacity(0.85))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

            if let answer {
                HStack(spacing: 6) {
                    Image(systemName: answer ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(answer ? OnboardingTheme.success : OnboardingTheme.warning)
                    Text(answer ? "Allowed" : "Denied").font(.system(size: 12.5, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                HStack(spacing: 8) {
                    OnboardingButton(title: "Deny", prominent: false, shortcut: "N") { respond(false) }
                        .frame(maxWidth: .infinity)
                    OnboardingButton(title: "Allow", shortcut: "Y") { respond(true) }
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
    }
}
