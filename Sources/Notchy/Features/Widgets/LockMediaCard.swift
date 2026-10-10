import SwiftUI

struct LockMediaCard: View {
    @ObservedObject var media: MediaController
    @StateObject private var state = NotchState()
    @State private var shown = false

    private var wide: Bool { state.showQueue || state.showLyrics }

    var body: some View {
        ZStack {
            if media.hasTrack {
                card
                    .opacity(shown ? 1 : 0)
                    .scaleEffect(shown ? 1 : 0.96)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: media.hasTrack)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { shown = true }
        }
    }

    private var card: some View {
        MediaView(media: media, state: state, showsFavorite: false, showsSettings: false)
            .frame(width: wide ? NotchState.queueExpandedSize.width - 48 : 428)
            .padding(.vertical, 18)
            .foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
            .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
            .modifier(LiquidGlassSurface(cornerRadius: 28))
            .animation(NotchAnimation.state, value: wide)
    }
}

private struct LiquidGlassSurface: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .contentShape(shape)
            .background {
                ZStack {
                    VisualEffectBackground(material: .hudWindow)
                        .opacity(0.35)
                    shape
                        .fill(.white.opacity(0.06))
                    shape
                        .stroke(.white.opacity(0.22), lineWidth: 8)
                        .blur(radius: 7)
                    shape
                        .stroke(.black.opacity(0.12), lineWidth: 5)
                        .blur(radius: 5)
                        .offset(y: -2)
                }
                .mask(shape)
                .allowsHitTesting(false)
            }
            .overlay { rim(shape) }
    }

    private func rim(_ shape: RoundedRectangle) -> some View {
        ZStack {
            shape
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.7), location: 0),
                            .init(color: .white.opacity(0.12), location: 0.3),
                            .init(color: .white.opacity(0.05), location: 0.6),
                            .init(color: .white.opacity(0.45), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
            shape
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.18)),
                    lineWidth: 2
                )
                .blur(radius: 0.8)
        }
        .allowsHitTesting(false)
    }
}
