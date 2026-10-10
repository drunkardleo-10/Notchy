import SwiftUI

struct WelcomeStep: View {
    @ObservedObject var model: OnboardingModel
    @State private var arrived = false
    @State private var revealed = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            NotchyMascot(pose: arrived ? .wave : .cheer, cell: 4.4)
                .offset(y: arrived ? 0 : -70)
                .opacity(arrived ? 1 : 0)

            VStack(alignment: .leading, spacing: 12) {
                SpeechBubble(tail: .leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hi, I'm Notchy")
                            .font(.system(size: 20, weight: .semibold))
                        Text("I live in your notch. I keep your music, coding agents, files and focus right where your eyes already are. Let me show you around. It takes about a minute, and everything stays on your Mac.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 10) {
                    OnboardingButton(title: "Show me around", symbol: "arrow.right") { model.advance() }
                        .keyboardShortcut(.defaultAction)
                    OnboardingButton(title: "Skip setup", prominent: false) { model.complete() }
                }
                .padding(.leading, 7)
            }
            .frame(width: 380, alignment: .leading)
            .opacity(revealed ? 1 : 0)
            .scaleEffect(revealed ? 1 : 0.92, anchor: .leading)
            .blur(radius: revealed ? 0 : 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.58).delay(0.15)) { arrived = true }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.45)) { revealed = true }
        }
    }
}
