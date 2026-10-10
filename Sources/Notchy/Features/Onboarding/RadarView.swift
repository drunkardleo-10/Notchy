import SwiftUI

struct RadarView: View {
    let found: [AgentKind]
    let scanning: Bool
    let live: Bool

    private let accent = OnboardingTheme.success

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let radius = side / 2
            ZStack {
                ForEach(1...3, id: \.self) { ring in
                    Circle()
                        .strokeBorder(Color.white.opacity(0.06 + Double(ring) * 0.025), lineWidth: 1)
                        .frame(width: side * CGFloat(ring) / 3, height: side * CGFloat(ring) / 3)
                }
                Rectangle().fill(Color.white.opacity(0.06)).frame(width: side, height: 1)
                Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1, height: side)

                TimelineView(.animation(minimumInterval: 1 / 60)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    Circle()
                        .fill(AngularGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .clear, location: 0.72),
                                .init(color: accent.opacity(scanning ? 0.42 : 0.18), location: 1)
                            ],
                            center: .center
                        ))
                        .rotationEffect(.degrees((t * (scanning ? 200 : 70)).truncatingRemainder(dividingBy: 360)))
                }
                .frame(width: side, height: side)

                ForEach(Array(found.enumerated()), id: \.element.id) { index, kind in
                    AgentGlyph(id: kind.id, size: 15)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.black.opacity(0.75)))
                        .overlay(Circle().strokeBorder(accent.opacity(0.5), lineWidth: 1))
                        .offset(blipOffset(index: index, radius: radius))
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }

                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                    .shadow(color: accent, radius: live ? 8 : 4)
                    .scaleEffect(live ? 1.4 : 1)
            }
            .frame(width: side, height: side)
            .clipShape(Circle())
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .accessibilityHidden(true)
    }

    private func blipOffset(index: Int, radius: CGFloat) -> CGSize {
        let angle = (Double(index) * 137.5 - 60) * .pi / 180
        let distance = radius * (0.5 + 0.14 * CGFloat(index % 3))
        return CGSize(width: cos(angle) * distance, height: sin(angle) * distance)
    }
}
