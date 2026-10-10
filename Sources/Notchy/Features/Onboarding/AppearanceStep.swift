import SwiftUI

struct AppearanceStep: View {
    @AppStorage(Pref.glassLevel) private var glassLevel = 0.5

    private let presets: [(title: String, level: Double)] = [("Solid", 0), ("Smoky", 0.45), ("Glass", 1)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NotchyGuide(
                pose: .idle,
                title: "How see-through should I be?",
                message: "Drag the slider and watch me change. You can tweak this later in Settings, under Dynamic Glass.",
                reservedLines: 2
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.title) { preset in
                        PresetChip(title: preset.title, selected: abs(glassLevel - preset.level) < 0.04) {
                            withAnimation(.easeInOut(duration: 0.35)) { glassLevel = preset.level }
                            OnboardingFeedback.tick()
                        }
                    }
                    Spacer()
                    Text("\(Int(glassLevel * 100))%")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                        .contentTransition(.numericText())
                }
                HStack(spacing: 10) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                    Slider(value: $glassLevel, in: 0...1)
                        .tint(Color(red: 0.74, green: 0.69, blue: 1.0))
                        .accessibilityLabel("Notch transparency")
                        .accessibilityValue("\(Int(glassLevel * 100)) percent")
                    Image(systemName: "circle.dotted")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
            .padding(.leading, 46)
        }
    }
}

private struct PresetChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(selected ? Color.black : Color.white.opacity(0.8))
                .padding(.horizontal, 12)
                .frame(height: 24)
                .background(Capsule().fill(selected ? Color.white.opacity(0.9) : Color.white.opacity(hovering ? 0.16 : 0.09)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.18), value: hovering)
        .animation(.easeOut(duration: 0.2), value: selected)
    }
}
