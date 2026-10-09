import SwiftUI

struct PhaseGlyph: View {
    let phase: PomodoroModel.Phase
    let running: Bool
    let tint: Color

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !running)) { context in
                Canvas { gc, size in
                    let t = context.date.timeIntervalSinceReferenceDate
                    if phase == .focus {
                        drawFocus(&gc, size: size, t: t)
                    } else {
                        drawRest(&gc, size: size, t: t)
                    }
                }
            }
            .opacity(running ? 1 : 0)
            .scaleEffect(running ? 1 : 0.6)

            PlayPauseGlyph(showsPause: true, tint: tint)
                .opacity(running ? 0 : 1)
                .scaleEffect(running ? 0.6 : 1)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: running)
    }

    private func drawFocus(_ gc: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let s = min(size.width, size.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let breath = 0.5 + 0.5 * sin(t * 2 * .pi / 2.4)
        let core = s * (0.15 + 0.03 * breath)
        gc.fill(Path(ellipseIn: CGRect(x: center.x - core, y: center.y - core, width: core * 2, height: core * 2)), with: .color(tint))
        for k in 0..<2 {
            let p = (t / 2.4 + Double(k) * 0.5).truncatingRemainder(dividingBy: 1)
            let r = s * (0.2 + 0.3 * p)
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            gc.stroke(Path(ellipseIn: rect), with: .color(tint.opacity((1 - p) * 0.8)), lineWidth: max(1, s * 0.05))
        }
    }

    private func drawRest(_ gc: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let s = min(size.width, size.height)
        let barWidth = s * 0.13
        let gap = s * 0.1
        let total = barWidth * 3 + gap * 2
        let originX = (size.width - total) / 2
        for i in 0..<3 {
            let wave = 0.5 + 0.5 * sin(t * 2 * .pi / 2.2 - Double(i) * 0.9)
            let h = s * (0.22 + 0.4 * wave)
            let rect = CGRect(
                x: originX + CGFloat(i) * (barWidth + gap),
                y: (size.height - h) / 2,
                width: barWidth,
                height: h
            )
            gc.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(tint))
        }
    }
}

struct PlayPauseShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let left: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 0.12, y: 0.0), CGPoint(x: 0.12, y: 0.0)),
            (CGPoint(x: 0.5, y: 0.25), CGPoint(x: 0.38, y: 0.0)),
            (CGPoint(x: 0.5, y: 0.75), CGPoint(x: 0.38, y: 1.0)),
            (CGPoint(x: 0.12, y: 1.0), CGPoint(x: 0.12, y: 1.0))
        ]
        let right: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 0.5, y: 0.25), CGPoint(x: 0.62, y: 0.0)),
            (CGPoint(x: 0.92, y: 0.5), CGPoint(x: 0.88, y: 0.0)),
            (CGPoint(x: 0.92, y: 0.5), CGPoint(x: 0.88, y: 1.0)),
            (CGPoint(x: 0.5, y: 0.75), CGPoint(x: 0.62, y: 1.0))
        ]
        var path = Path()
        for quad in [left, right] {
            let pts = quad.map { pair -> CGPoint in
                let x = pair.0.x + (pair.1.x - pair.0.x) * progress
                let y = pair.0.y + (pair.1.y - pair.0.y) * progress
                return CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
            }
            path.move(to: pts[0])
            pts.dropFirst().forEach { path.addLine(to: $0) }
            path.closeSubpath()
        }
        return path
    }
}

struct PlayPauseGlyph: View {
    let showsPause: Bool
    var tint: Color = .white
    var size: CGFloat = 12

    var body: some View {
        PlayPauseShape(progress: showsPause ? 1 : 0)
            .fill(tint)
            .frame(width: size, height: size)
            .animation(.spring(response: 0.34, dampingFraction: 0.78), value: showsPause)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
