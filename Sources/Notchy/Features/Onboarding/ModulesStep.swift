import SwiftUI

struct ModulesStep: View {
    @State private var enabled = Set(OnboardingModule.all.filter { Pref.bool($0.id) }.map(\.id))
    @State private var hovered: OnboardingModule?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NotchyGuide(
                pose: .idle,
                title: "What should I keep up here?",
                message: hovered.map { "\($0.title): \($0.detail)" }
                    ?? "Pick a few. Hover a tile and I'll tell you what it does. You can change this anytime in Settings.",
                reservedLines: 2
            )

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(OnboardingModule.all) { module in
                    ModuleTile(module: module, isOn: enabled.contains(module.id)) { toggle(module) }
                        .onHover { inside in
                            if inside { hovered = module }
                        }
                }
            }
            .onHover { inside in
                if !inside { hovered = nil }
            }
        }
    }

    private func toggle(_ module: OnboardingModule) {
        let on = !enabled.contains(module.id)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if on { enabled.insert(module.id) } else { enabled.remove(module.id) }
        }
        UserDefaults.standard.set(on, forKey: module.id)
        OnboardingFeedback.tick()
    }
}

private struct ModuleTile: View {
    let module: OnboardingModule
    let isOn: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: module.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolEffect(.bounce, value: isOn)
                    .frame(height: 18)
                Text(module.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? .white : .white.opacity(0.45))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(isOn ? 0.16 : (hovering ? 0.09 : 0.05)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.white.opacity(isOn ? 0.4 : 0.06), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(OnboardingTheme.success)
                        .padding(5)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.18), value: hovering)
        .accessibilityLabel(module.title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}
