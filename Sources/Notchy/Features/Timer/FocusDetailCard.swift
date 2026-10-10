import SwiftUI

enum FocusDetailLayout {
    static let width: CGFloat = 168
    static let height: CGFloat = 78
    static let cornerRadius: CGFloat = 22
}

struct FocusDetailCard: View, Animatable {
    @ObservedObject var pomodoro: PomodoroModel
    var progress: CGFloat
    let dotDiameter: CGFloat
    let travel: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private var tint: Color { pomodoro.phase == .focus ? .orange : .green }
    private var symbol: String { pomodoro.phase == .focus ? "target" : "cup.and.saucer.fill" }
    private var totalMinutes: Int { pomodoro.totalSeconds / 60 }

    private func lerp(_ from: CGFloat, _ to: CGFloat) -> CGFloat { from + (to - from) * progress }

    private var contentOpacity: Double { Double(max(0, min(1, (progress - 0.45) / 0.45))) }

    var body: some View {
        content
            .frame(width: FocusDetailLayout.width, height: FocusDetailLayout.height)
            .opacity(contentOpacity)
            .blur(radius: (1 - min(1, progress)) * 4)
            .frame(width: lerp(dotDiameter, FocusDetailLayout.width), height: lerp(dotDiameter, FocusDetailLayout.height))
            .background { glass(cornerRadius: lerp(dotDiameter / 2, FocusDetailLayout.cornerRadius)) }
            .clipped()
            .frame(width: FocusDetailLayout.width, height: FocusDetailLayout.height)
            .offset(y: -(1 - progress) * travel)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                Text(pomodoro.phase.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer(minLength: 0)
                Text(pomodoro.formatted)
                    .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(tint)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeOut(duration: 0.22), value: pomodoro.remaining)
            }
            Capsule()
                .fill(.white.opacity(0.14))
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(tint)
                            .frame(width: max(4, geo.size.width * pomodoro.progress))
                            .animation(.easeInOut(duration: 0.3), value: pomodoro.progress)
                    }
                }
            Text("\(pomodoro.running ? "Running" : "Paused") · \(totalMinutes) min")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func glass(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: shape)
        } else {
            shape.fill(.ultraThinMaterial)
        }
    }
}
