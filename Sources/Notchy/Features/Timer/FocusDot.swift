import SwiftUI

enum FocusDotLayout {
    static let gap: CGFloat = 8
    static let bodyInset: CGFloat = 6
    static let stubLength: CGFloat = 12
    static let stubHeight: CGFloat = 12
    static let blur: CGFloat = 6
    static let pad: CGFloat = 16
    static let overshoot: CGFloat = 10

    static func diameter(notchHeight: CGFloat) -> CGFloat { notchHeight - 6 }
}

struct FocusDotView: View {
    @ObservedObject var pomodoro: PomodoroModel
    let active: Bool
    let detailOpen: Bool
    let hovering: Bool
    let anchorWidth: CGFloat
    let notchHeight: CGFloat

    @State private var progress: CGFloat = 0
    @State private var detailProgress: CGFloat = 0
    @State private var pendingDetach: Task<Void, Never>?

    private var tint: Color { pomodoro.phase == .focus ? .orange : .green }

    private var detailOffset: CGSize {
        let diameter = FocusDotLayout.diameter(notchHeight: notchHeight)
        let dotCenter = anchorWidth + FocusDotLayout.gap + diameter / 2
        return CGSize(width: dotCenter - FocusDetailLayout.width / 2, height: notchHeight + 4)
    }

    private var detailTravel: CGFloat {
        (detailOffset.height + FocusDetailLayout.height / 2) - notchHeight / 2
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            dot
            if detailProgress > 0.001 {
                FocusDetailCard(
                    pomodoro: pomodoro,
                    progress: detailProgress,
                    dotDiameter: FocusDotLayout.diameter(notchHeight: notchHeight),
                    travel: detailTravel
                )
                .offset(detailOffset)
            }
        }
        .onChange(of: detailOpen) { _, open in
            withAnimation(NotchAnimation.spring(response: 0.42, dampingFraction: 0.82)) {
                detailProgress = open && active ? 1 : 0
            }
        }
        .onChange(of: active) { _, isActive in
            if !isActive { detailProgress = 0 }
        }
    }

    private var dot: some View {
        FocusDotLayer(
            progress: progress,
            hover: hovering ? 1 : 0,
            anchorWidth: anchorWidth,
            notchHeight: notchHeight,
            content: FocusRing(
                tint: tint,
                symbol: pomodoro.phase == .focus ? "target" : "cup.and.saucer.fill",
                ringProgress: pomodoro.progress,
                running: pomodoro.running
            )
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(NotchAnimation.spring(response: 0.28, dampingFraction: 0.72), value: hovering)
        .onAppear { settle(animated: false) }
        .onChange(of: active) { _, _ in settle(animated: true) }
    }

    private func settle(animated: Bool) {
        pendingDetach?.cancel()
        let target: CGFloat = active ? 1 : 0
        guard animated else {
            progress = target
            return
        }
        guard active else {
            withAnimation(NotchAnimation.spring(response: 0.34, dampingFraction: 0.92)) { progress = 0 }
            return
        }
        pendingDetach = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Self.detachDelay))
            guard !Task.isCancelled else { return }
            withAnimation(NotchAnimation.spring(response: 0.52, dampingFraction: 0.7)) { progress = 1 }
        }
    }

    private static let detachDelay = 520
}

struct FocusDotLayer<Content: View>: View, Animatable {
    var progress: CGFloat
    var hover: CGFloat
    let anchorWidth: CGFloat
    let notchHeight: CGFloat
    let content: Content

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, hover) }
        set {
            progress = newValue.first
            hover = newValue.second
        }
    }

    private typealias L = FocusDotLayout

    private var diameter: CGFloat { L.diameter(notchHeight: notchHeight) }
    private var seamX: CGFloat { L.pad + L.stubLength }
    private var restX: CGFloat { seamX + L.bodyInset + L.gap + diameter / 2 }
    private var startX: CGFloat { seamX - 4 }
    private var centerY: CGFloat { L.pad + notchHeight / 2 }
    private var canvasWidth: CGFloat { restX + diameter / 2 + L.overshoot + L.pad }
    private var canvasHeight: CGFloat { notchHeight + L.pad * 2 }

    private var centerX: CGFloat { startX + (restX - startX) * progress }
    private var scale: CGFloat { max(0.3, min(1.15, 0.3 + 0.7 * progress)) * (1 + 0.16 * hover) }
    private var contentOpacity: Double { Double(max(0, min(1, (progress - 0.6) / 0.4))) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                guard progress > 0.001 else { return }
                context.addFilter(.alphaThreshold(min: 0.5, color: .black))
                context.addFilter(.blur(radius: L.blur))
                context.drawLayer { layer in
                    let stub = CGRect(
                        x: L.pad,
                        y: centerY - L.stubHeight / 2,
                        width: L.stubLength,
                        height: L.stubHeight
                    )
                    layer.fill(Path(roundedRect: stub, cornerRadius: 3), with: .color(.black))
                    let r = diameter / 2 * scale
                    let dot = CGRect(x: centerX - r, y: centerY - r, width: r * 2, height: r * 2)
                    layer.fill(Path(ellipseIn: dot), with: .color(.black))
                }
            }
            .frame(width: canvasWidth, height: canvasHeight)
            .mask(alignment: .topLeading) {
                Rectangle()
                    .frame(width: canvasWidth - seamX, height: canvasHeight)
                    .offset(x: seamX)
            }

            content
                .frame(width: diameter - 4, height: diameter - 4)
                .scaleEffect(scale)
                .opacity(contentOpacity)
                .position(x: centerX, y: centerY)
        }
        .frame(width: canvasWidth, height: canvasHeight, alignment: .topLeading)
        .offset(x: anchorWidth - L.bodyInset - seamX, y: -L.pad)
        .opacity(progress > 0.001 ? 1 : 0)
    }
}

private struct FocusRing: View {
    let tint: Color
    let symbol: String
    let ringProgress: Double
    let running: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: 2)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    tint.opacity(running ? 0.95 : 0.55),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: ringProgress)
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint.opacity(running ? 1 : 0.65))
                .contentTransition(.symbolEffect(.replace))
        }
    }
}
