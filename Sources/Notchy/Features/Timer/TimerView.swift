import SwiftUI

struct TimerView: View {
    @ObservedObject var pomodoro: PomodoroModel

    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 6) {
                Label(pomodoro.phase.title, systemImage: pomodoro.phase.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(pomodoro.phase == .focus ? Color.orange : .green)
                Text(pomodoro.formatted)
                    .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                HStack(spacing: 10) {
                    Button { pomodoro.startPause() } label: {
                        Label(pomodoro.running ? "Pause" : pomodoro.started ? "Resume" : "Start",
                              systemImage: pomodoro.running ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(.white.opacity(0.18), in: Capsule())
                    }
                    Button { pomodoro.reset() } label: { Image(systemName: "arrow.counterclockwise") }
                    Button { pomodoro.skip() } label: { Image(systemName: "forward.end.fill") }
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                Stepper(value: $pomodoro.focusMinutes, in: 5...90, step: 5) {
                    Text("Focus  \(pomodoro.focusMinutes) min").font(.system(size: 11))
                }
                Stepper(value: $pomodoro.breakMinutes, in: 1...30) {
                    Text("Break  \(pomodoro.breakMinutes) min").font(.system(size: 11))
                }
                Text("Shows a countdown in the notch while it runs.")
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
            }
            .frame(width: 170)
        }
        .padding(.horizontal, 6)
    }
}

struct PomodoroPillView: View {
    @ObservedObject var pomodoro: PomodoroModel
    let notch: CGSize

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: pomodoro.phase.icon).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(pomodoro.phase == .focus ? Color.orange : .green)
                .frame(width: HUDLayout.sideWidth, alignment: .trailing).padding(.trailing, 4)
            Spacer().frame(width: notch.width)
            Text(pomodoro.formatted)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(pomodoro.running ? 1 : 0.5))
                .frame(width: HUDLayout.sideWidth, alignment: .leading).padding(.leading, 6)
        }
        .frame(height: notch.height)
    }
}
