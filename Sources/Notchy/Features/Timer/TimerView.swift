import SwiftUI

struct TimerView: View {
    @ObservedObject var pomodoro: PomodoroModel
    @Namespace private var phaseNamespace

    var body: some View {
        Group {
            if pomodoro.started {
                activeTimerView
            } else {
                idleTimerView
            }
        }
        .animation(.interactiveSpring(response: 0.36, dampingFraction: 0.94), value: pomodoro.started)
    }

    private var activeTimerView: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke((pomodoro.phase == .focus ? Color.orange : Color.green).opacity(0.20), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: pomodoro.progress)
                    .stroke(
                        pomodoro.phase == .focus ? Color.orange : Color.green,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: pomodoro.progress)
                Image(systemName: pomodoro.running ? pomodoro.phase.icon : "pause.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(pomodoro.phase == .focus ? Color.orange : Color.green)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Label(pomodoro.running ? pomodoro.phase.title : "Paused", systemImage: pomodoro.phase.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(pomodoro.phase == .focus ? Color.orange : Color.green)

                Text(pomodoro.formatted)
                    .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeOut(duration: 0.22), value: pomodoro.remaining)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button {
                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.94)) {
                        pomodoro.startPause()
                    }
                } label: {
                    Label(
                        pomodoro.running ? "Pause" : "Resume",
                        systemImage: pomodoro.running ? "pause.fill" : "play.fill"
                    )
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(pomodoro.phase == .focus ? Color.orange : Color.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background((pomodoro.phase == .focus ? Color.orange : Color.green).opacity(0.18), in: Capsule())
                }

                Button {
                    withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.94)) {
                        pomodoro.reset()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.12), in: Circle())
                }

                Button {
                    withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.94)) {
                        pomodoro.skip()
                    }
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var idleTimerView: some View {
        VStack(spacing: 8) {
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
                        .buttonStyle(.plain)
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
                Button {
                    withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.94)) {
                        pomodoro.startPause()
                    }
                } label: {
                    Label("Start \(pomodoro.phase.title)", systemImage: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(pomodoro.phase == .focus ? Color.orange : Color.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background((pomodoro.phase == .focus ? Color.orange : Color.green).opacity(0.18), in: Capsule())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DurationRuler: View {
    @Binding var minutes: Int
    var tint: Color = .orange
    @State private var position: Int?
    @State private var lastDetent = Date.distantPast
    private let tickSpacing: CGFloat = 8

    var body: some View {
        GeometryReader { viewport in
            ScrollView(.horizontal) {
                LazyHStack(alignment: .bottom, spacing: 0) {
                    ForEach(1...120, id: \.self) { minute in
                        DurationRulerTick(minute: minute, spacing: tickSpacing, tint: tint)
                            .visualEffect { effect, geometry in
                                let distance = abs(geometry.frame(in: .scrollView(axis: .horizontal)).midX - viewport.size.width / 2)
                                let proximity = max(0, 1 - distance / (viewport.size.width / 2))
                                return effect
                                    .opacity(0.2 + 0.8 * proximity)
                                    .scaleEffect(x: 0.96 + 0.04 * proximity, y: 0.94 + 0.06 * proximity, anchor: .bottom)
                            }
                            .id(minute)
                    }
                }
                .frame(height: 52)
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, max(0, (viewport.size.width - tickSpacing) / 2), for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
            .scrollPosition(id: $position, anchor: .center)
            .overlay(alignment: .bottom) {
                VStack(spacing: 3) {
                    Capsule()
                        .fill(tint)
                        .frame(width: 2, height: 26)
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 5))
                        .rotationEffect(.degrees(180))
                        .foregroundStyle(tint)
                }
                .allowsHitTesting(false)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.12),
                        .init(color: .black, location: 0.88),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .frame(height: 52)
        .onChange(of: position) { _, minute in
            guard let minute, minutes != minute else { return }
            minutes = minute
        }
        .onChange(of: minutes) { _, minute in
            if position != minute {
                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.94)) {
                    position = minute
                }
            }
            let now = Date()
            guard now.timeIntervalSince(lastDetent) >= 0.07 else { return }
            lastDetent = now
            if Pref.bool(Pref.hapticFeedback) {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        }
        .task {
            position = minutes
        }
    }
}

struct DurationRulerTick: View {
    let minute: Int
    let spacing: CGFloat
    var tint: Color = .orange

    private var major: Bool { minute.isMultiple(of: 5) }
    private var height: CGFloat {
        if minute.isMultiple(of: 15) { return 25 }
        if minute.isMultiple(of: 10) { return 22 }
        return major ? 18 : 11
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(major || minute == 1 ? "\(minute)" : "")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .monospacedDigit()
                .fixedSize()
                .foregroundStyle(tint.opacity(0.85))
                .frame(height: 12)
            Capsule()
                .fill(tint.opacity(major ? 0.9 : 0.45))
                .frame(width: major ? 2 : 1, height: height)
                .frame(height: 25, alignment: .bottom)
        }
        .frame(width: spacing, height: 52, alignment: .bottom)
    }
}

struct PomodoroPillView: View {
    @ObservedObject var pomodoro: PomodoroModel
    let notch: CGSize

    var body: some View {
        NotchAccessory(
            notch: notch,
            leadingWidth: HUDLayout.sideWidth,
            trailingWidth: HUDLayout.sideWidth,
            leadingAlignment: .trailing,
            trailingAlignment: .leading,
            leadingInset: 4,
            trailingInset: 6
        ) {
            ZStack {
                Circle()
                    .stroke((pomodoro.phase == .focus ? Color.orange : Color.green).opacity(0.20), lineWidth: 1.5)
                Circle()
                    .trim(from: 0, to: pomodoro.progress)
                    .stroke(
                        (pomodoro.phase == .focus ? Color.orange : Color.green).opacity(pomodoro.running ? 0.95 : 0.5),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: pomodoro.progress)
                Image(systemName: pomodoro.running ? pomodoro.phase.icon : "pause.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(pomodoro.phase == .focus ? Color.orange : Color.green)
            }
            .frame(width: 20, height: 20)
        } trailing: {
            Text(pomodoro.formatted)
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(pomodoro.phase == .focus ? Color.orange : Color.green)
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeOut(duration: 0.22), value: pomodoro.remaining)
                .opacity(pomodoro.running ? 1.0 : 0.6)
        }
    }
}
