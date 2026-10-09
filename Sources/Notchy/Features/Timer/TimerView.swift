import SwiftUI
import AppKit

enum PomodoroLayout {
    static let sideWidth: CGFloat = 46
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
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(tint.opacity(0.20), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: pomodoro.progress)
                        .stroke(
                            tint,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: pomodoro.progress)
                    PhaseGlyph(phase: pomodoro.phase, running: pomodoro.running, tint: tint)
                        .frame(width: 22, height: 22)
                }
                .shadow(color: tint.opacity(pomodoro.running ? 0.35 : 0), radius: 5)
                .animation(.easeInOut(duration: 0.4), value: pomodoro.running)
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(pomodoro.phase.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(tint)

                        if !pomodoro.running {
                            Text("Paused")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.10), in: Capsule())
                        }
                    }

                    Text(pomodoro.formatted)
                        .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.easeOut(duration: 0.22), value: pomodoro.remaining)
                }
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.94)) {
                        pomodoro.startPause()
                    }
                } label: {
                    HStack(spacing: 6) {
                        PlayPauseGlyph(showsPause: pomodoro.running, tint: tint, size: 10)
                        Text(pomodoro.running ? "Pause" : "Resume")
                            .contentTransition(.interpolate)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(tint.opacity(0.18), in: Capsule())
                }
                .buttonStyle(PressScaleStyle())

                Button {
                    withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.94)) {
                        pomodoro.reset()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(PressScaleStyle())

                Button {
                    withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.94)) {
                        pomodoro.skip()
                    }
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(PressScaleStyle())
            }
        }
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
            leadingWidth: PomodoroLayout.sideWidth,
            trailingWidth: PomodoroLayout.sideWidth
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
                .foregroundStyle(tint)
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeOut(duration: 0.22), value: pomodoro.remaining)
                .opacity(pomodoro.running ? 1.0 : 0.6)
        }
    }
}
