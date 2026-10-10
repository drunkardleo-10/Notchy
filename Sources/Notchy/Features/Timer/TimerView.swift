import SwiftUI
import AppKit

enum PomodoroLayout {
    static let sideWidth: CGFloat = 46

    static func sideWidth(for text: String) -> CGFloat {
        text.count > 5 ? 60 : sideWidth
    }
}

struct TimerView: View {
    @ObservedObject var pomodoro: PomodoroModel
    @Namespace private var phaseNamespace

    private var tint: Color {
        pomodoro.phase == .focus ? .orange : .green
    }

    var body: some View {
        Group {
            if pomodoro.started {
                activeTimerView
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            } else {
                idleTimerView
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: pomodoro.started)
    }

    private var activeTimerView: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.94)) {
                    pomodoro.startPause()
                }
            } label: {
                PlayPauseGlyph(showsPause: pomodoro.running, tint: tint, size: 14)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.28), in: Circle())
            }
            .buttonStyle(PressScaleStyle())

            Button {
                withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.94)) {
                    pomodoro.reset()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.16), in: Circle())
            }
            .buttonStyle(PressScaleStyle())

            Spacer(minLength: 12)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(pomodoro.phase.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(pomodoro.formatted)
                    .font(.system(size: 38, weight: .semibold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeOut(duration: 0.22), value: pomodoro.remaining)
            }
            .lineLimit(1)
            .foregroundStyle(tint)
            .opacity(pomodoro.running ? 1 : 0.6)
            .animation(.easeInOut(duration: 0.25), value: pomodoro.running)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var idleTimerView: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    ForEach([PomodoroModel.Phase.focus, PomodoroModel.Phase.rest], id: \.self) { phase in
                        Button {
                            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.94)) {
                                pomodoro.phase = phase
                                pomodoro.remaining = (phase == .focus ? pomodoro.focusMinutes : pomodoro.breakMinutes) * 60
                            }
                        } label: {
                            Text(phase.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(pomodoro.phase == phase ? (phase == .focus ? Color.orange : Color.green) : .white.opacity(0.55))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 4)
                                .background {
                                    if pomodoro.phase == phase {
                                        Capsule()
                                            .fill((phase == .focus ? Color.orange : Color.green).opacity(0.18))
                                            .matchedGeometryEffect(id: "timerPhase", in: phaseNamespace)
                                    }
                                }
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .padding(3)
                .background(Color.white.opacity(0.08), in: Capsule())

                Spacer()

                Text(String(format: "%02d:00", pomodoro.phase == .focus ? pomodoro.focusMinutes : pomodoro.breakMinutes))
                    .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(pomodoro.phase == .focus ? Color.orange : Color.green)
                    .contentTransition(.numericText(value: Double(pomodoro.phase == .focus ? pomodoro.focusMinutes : pomodoro.breakMinutes)))
                    .animation(.easeOut(duration: 0.16), value: pomodoro.phase == .focus ? pomodoro.focusMinutes : pomodoro.breakMinutes)
            }
            .padding(.horizontal, 4)

            DurationRuler(
                minutes: Binding(
                    get: { pomodoro.phase == .focus ? pomodoro.focusMinutes : pomodoro.breakMinutes },
                    set: {
                        if pomodoro.phase == .focus {
                            pomodoro.focusMinutes = $0
                        } else {
                            pomodoro.breakMinutes = $0
                        }
                    }
                ),
                tint: pomodoro.phase == .focus ? Color.orange : Color.green
            )

            HStack {
                Spacer()

                Button {
                    withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.94)) {
                        pomodoro.startPause()
                    }
                } label: {
                    HStack(spacing: 6) {
                        PlayPauseGlyph(showsPause: false, tint: pomodoro.phase == .focus ? Color.orange : Color.green, size: 10)
                        Text("Start \(pomodoro.phase.title)")
                            .contentTransition(.interpolate)
                    }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(pomodoro.phase == .focus ? Color.orange : Color.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background((pomodoro.phase == .focus ? Color.orange : Color.green).opacity(0.18), in: Capsule())
                }
                .buttonStyle(PressScaleStyle())

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PomodoroPillView: View {
    @ObservedObject var pomodoro: PomodoroModel
    let notch: CGSize

    private var tint: Color {
        pomodoro.phase == .focus ? .orange : .green
    }

    var body: some View {
        NotchAccessory(
            notch: notch,
            leadingWidth: PomodoroLayout.sideWidth(for: pomodoro.formatted),
            trailingWidth: PomodoroLayout.sideWidth(for: pomodoro.formatted)
        ) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.20), lineWidth: 1.5)
                Circle()
                    .trim(from: 0, to: pomodoro.progress)
                    .stroke(
                        tint.opacity(pomodoro.running ? 0.95 : 0.5),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: pomodoro.progress)
                PhaseGlyph(phase: pomodoro.phase, running: pomodoro.running, tint: tint)
                    .frame(width: 11, height: 11)
            }
            .frame(width: 20, height: 20)
        } trailing: {
            Text(pomodoro.formatted)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(tint)
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeOut(duration: 0.22), value: pomodoro.remaining)
                .opacity(pomodoro.running ? 1.0 : 0.6)
        }
    }
}
