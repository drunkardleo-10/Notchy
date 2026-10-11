import SwiftUI

private struct SmokeParticle {
    let angle: Double
    let speed: Double
    let lift: Double
    let size: CGFloat
    let shade: Double
    let delay: Double
    let life: Double

    static func batch(_ count: Int) -> [SmokeParticle] {
        (0..<count).map { _ in
            SmokeParticle(
                angle: .random(in: 0..<(2 * .pi)),
                speed: .random(in: 14...34),
                lift: .random(in: 10...26),
                size: [4, 6, 6, 8, 10].randomElement() ?? 6,
                shade: .random(in: 0.62...1),
                delay: .random(in: 0...0.1),
                life: .random(in: 0.55...0.85)
            )
        }
    }
}

struct SmokePuff: View {
    static let duration: Double = 1.0

    let start: Date
    @State private var particles = SmokeParticle.batch(18)

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(start)
            Canvas { gc, size in
                guard elapsed < Self.duration else { return }
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                drawFlash(&gc, center: center, elapsed: elapsed)
                for particle in particles {
                    let t = (elapsed - particle.delay) / particle.life
                    guard t > 0, t < 1 else { continue }
                    let eased = 1 - pow(1 - t, 2.4)
                    let x = center.x + cos(particle.angle) * particle.speed * eased
                    let y = center.y + sin(particle.angle) * particle.speed * 0.7 * eased - particle.lift * eased
                    let side = max(2, snap(particle.size * (1 - 0.55 * t)))
                    let rect = CGRect(x: snap(x) - side / 2, y: snap(y) - side / 2, width: side, height: side)
                    let opacity = pow(1 - t, 1.3) * 0.9
                    gc.fill(Path(rect), with: .color(Color(white: particle.shade, opacity: opacity)))
                    let shadow = CGRect(x: rect.minX, y: rect.maxY - 2, width: side, height: 2)
                    gc.fill(Path(shadow), with: .color(Color(white: particle.shade * 0.7, opacity: opacity)))
                }
            }
        }
        .frame(width: 140, height: 140)
        .allowsHitTesting(false)
    }

    private func snap(_ value: CGFloat) -> CGFloat {
        (value / 2).rounded() * 2
    }

    private func drawFlash(_ gc: inout GraphicsContext, center: CGPoint, elapsed: Double) {
        let t = min(1, elapsed / 0.3)
        guard t < 1 else { return }
        let radius = 18 + 30 * t
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        gc.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.35 * (1 - t)), .clear]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }
}
