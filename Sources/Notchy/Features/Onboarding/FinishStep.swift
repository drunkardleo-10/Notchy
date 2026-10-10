import ServiceManagement
import SwiftUI

struct FinishStep: View {
    @ObservedObject var model: OnboardingModel
    @State private var launchAtLogin = true
    @AppStorage("SUEnableAutomaticChecks") private var autoUpdates = true

    var body: some View {
        HStack(spacing: 14) {
            NotchyMascot(pose: .cheer, cell: 4.4)

            VStack(alignment: .leading, spacing: 11) {
                SpeechBubble(tail: .leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("You're all set")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Hover over me anytime to open the notch, and swipe sideways on it to switch modules. I'll be right up here.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 16) {
                    FinishSwitch(title: "Launch at login", isOn: $launchAtLogin)
                    FinishSwitch(title: "Automatic updates", isOn: $autoUpdates)
                }
                .padding(.leading, 7)
                OnboardingButton(title: "Start using notchy", symbol: "arrow.right") { finish() }
                    .keyboardShortcut(.defaultAction)
                    .padding(.leading, 7)
            }
            .frame(width: 380, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
    }

    private func finish() {
        let service = SMAppService.mainApp
        if launchAtLogin, service.status != .enabled {
            try? service.register()
        } else if !launchAtLogin, service.status == .enabled {
            try? service.unregister()
        }
        OnboardingFeedback.success()
        model.beginOutro()
    }
}

private struct FinishSwitch: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { isOn.toggle() }
            OnboardingFeedback.tick()
        } label: {
            HStack(spacing: 7) {
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? OnboardingTheme.success.opacity(0.85) : Color.white.opacity(0.16))
                        .frame(width: 28, height: 16)
                    Circle().fill(.white).frame(width: 12, height: 12).padding(2)
                }
                Text(title).font(.system(size: 11.5, weight: .medium)).foregroundStyle(.white.opacity(0.8))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}
