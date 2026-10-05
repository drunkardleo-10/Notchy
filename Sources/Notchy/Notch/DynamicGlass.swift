import SwiftUI

enum DynamicGlassStyle {
    static func blackOpacity(for level: Double) -> Double {
        1 - min(max(level, 0), 1)
    }
}

struct DynamicGlassGradient: View, Animatable {
    var expansion: Double

    var animatableData: Double {
        get { expansion }
        set { expansion = newValue }
    }

    var body: some View {
        LinearGradient(
            stops: [
                stop(1, at: 0),
                stop(1, at: 0.30),
                stop(0.40, at: 0.52),
                stop(0.10, at: 0.70),
                stop(0, at: 0.86)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func stop(_ openOpacity: Double, at location: CGFloat) -> Gradient.Stop {
        let opacity = 1 + (openOpacity - 1) * min(max(expansion, 0), 1)
        return .init(color: .black.opacity(opacity), location: location)
    }
}
