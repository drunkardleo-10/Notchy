import SwiftUI

enum OnboardingTheme {
    static let success = Color(red: 0.45, green: 0.9, blue: 0.55)
    static let warning = Color(red: 0.93, green: 0.55, blue: 0.27)
    static let mono = Font.system(size: 11.5, design: .monospaced)
}

struct OnboardingButton: View {
    let title: String
    var symbol: String? = nil
    var prominent = true
    var shortcut: Character? = nil
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 12.5, weight: .semibold))
                if let shortcut {
                    Text("⌘\(String(shortcut))").font(.system(size: 10, weight: .medium)).opacity(0.5)
                }
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 10.5, weight: .bold))
                }
            }
            .foregroundStyle(prominent ? Color.black : Color.white)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(prominent ? Color.white.opacity(hovering ? 1 : 0.9) : Color.white.opacity(hovering ? 0.2 : 0.12))
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(ShortcutModifier(shortcut: shortcut))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

private struct ShortcutModifier: ViewModifier {
    let shortcut: Character?

    func body(content: Content) -> some View {
        if let shortcut, let key = shortcut.lowercased().first {
            content.keyboardShortcut(KeyEquivalent(key), modifiers: .command)
        } else {
            content
        }
    }
}

struct OnboardingTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.opacity)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OnboardingProgress: View {
    let index: Int
    let total: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(i == index ? 0.9 : i < index ? 0.45 : 0.16))
                    .frame(width: i == index ? 16 : 5, height: 5)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: index)
        .accessibilityElement()
        .accessibilityLabel("Step \(index + 1) of \(total)")
    }
}

struct PulseDot: View {
    var color: Color = OnboardingTheme.warning
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .background(
                Circle()
                    .fill(color.opacity(0.35))
                    .scaleEffect(pulsing ? 2.6 : 1)
                    .opacity(pulsing ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { pulsing = true }
            }
    }
}

private struct StepTransitionModifier: ViewModifier {
    let offset: CGFloat
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content.offset(x: offset).blur(radius: blur).opacity(opacity)
    }
}

extension AnyTransition {
    static func onboardingStep(direction: Int) -> AnyTransition {
        let travel = CGFloat(direction) * 36
        return .asymmetric(
            insertion: .modifier(
                active: StepTransitionModifier(offset: travel, blur: 8, opacity: 0),
                identity: StepTransitionModifier(offset: 0, blur: 0, opacity: 1)
            ),
            removal: .modifier(
                active: StepTransitionModifier(offset: -travel, blur: 8, opacity: 0),
                identity: StepTransitionModifier(offset: 0, blur: 0, opacity: 1)
            )
        )
    }
}
