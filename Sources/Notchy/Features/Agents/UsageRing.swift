import SwiftUI

enum UsageTone {
    static func color(left: Double) -> Color {
        if left > 0.3 { return Color(red: 0.24, green: 0.77, blue: 0.5) }
        if left > 0.1 { return Color(red: 1, green: 0.67, blue: 0.2) }
        return Color(red: 1, green: 0.34, blue: 0.3)
    }
}

struct UsageRing: View {
    let outer: Double?
    let inner: Double?
    let size: CGFloat

    private var width: CGFloat { max(2.4, size * 0.055) }

    var body: some View {
        ZStack {
            ring(outer, diameter: size)
            ring(inner, diameter: size - size * 0.2)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func ring(_ left: Double?, diameter: CGFloat) -> some View {
        if let left {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: width)
                Circle()
                    .trim(from: 0, to: max(0.012, left))
                    .stroke(UsageTone.color(left: left), style: StrokeStyle(lineWidth: width, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: diameter - width, height: diameter - width)
            .animation(.easeOut(duration: 0.4), value: left)
        }
    }
}
