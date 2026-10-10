import SwiftUI

enum FocusDetailLayout {
    static let width: CGFloat = 168
    static let height: CGFloat = 78
    static let cornerRadius: CGFloat = 22
}

struct FocusDetailCard: View {
    @ObservedObject var pomodoro: PomodoroModel

    private var tint: Color { pomodoro.phase == .focus ? .orange : .green }
    private var symbol: String { pomodoro.phase == .focus ? "target" : "cup.and.saucer.fill" }
    private var totalMinutes: Int { pomodoro.totalSeconds / 60 }

    var body: some View {
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
        .frame(width: FocusDetailLayout.width, height: FocusDetailLayout.height)
        .background { glass }
    }

    @ViewBuilder
    private var glass: some View {
        let shape = RoundedRectangle(cornerRadius: FocusDetailLayout.cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: shape)
        } else {
            shape.fill(.ultraThinMaterial)
        }
    }
}
