import SwiftUI

struct BasketSurface: View {
    let targeted: Bool
    private let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)

    var body: some View {
        ZStack {
            if #available(macOS 26.0, *) {
                Color.clear.glassEffect(.regular.tint(targeted ? Color.accentColor.opacity(0.3) : nil), in: shape)
            } else {
                shape.fill(.ultraThinMaterial)
                shape.fill(Color.accentColor.opacity(targeted ? 0.18 : 0))
            }
            shape.fill(
                LinearGradient(
                    colors: [.white.opacity(targeted ? 0.16 : 0.08), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            )
        }
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.55), .white.opacity(0.05), .white.opacity(0.22)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
        }
        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
        .animation(.easeOut(duration: 0.2), value: targeted)
    }
}
