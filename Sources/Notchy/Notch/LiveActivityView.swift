import SwiftUI

enum LiveActivityLayout {
    static let sideWidth: CGFloat = 46

    static func size(notch: CGSize) -> CGSize {
        NotchAccessoryLayout.size(notch: notch, leadingWidth: sideWidth, trailingWidth: sideWidth)
    }
}

struct LiveActivityView: View {
    @ObservedObject var media: MediaController
    let notch: CGSize
    var albumArtNamespace: Namespace.ID? = nil
    var visualizerNamespace: Namespace.ID? = nil
    @ObservedObject var state: NotchState

    private var side: CGFloat { LiveActivityLayout.sideWidth }

    var body: some View {
        NotchAccessory(
            notch: notch,
            leadingWidth: side,
            trailingWidth: side
        ) {
            ArtworkView(
                image: media.artwork,
                size: 20,
                cornerRadius: 5,
                namespace: albumArtNamespace,
                skipAnimationID: media.artworkSkipAnimationID,
                skipDirection: media.artworkSkipDirection,
                skipArtwork: media.artworkSkipArtwork
            )
        } trailing: {
            ZStack {
                if state.flashDirection == .previous {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                } else if state.flashDirection == .next {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    ZStack {
                        EqualizerBars(
                            active: media.isPlaying,
                            tint: media.artworkTint,
                            namespace: visualizerNamespace
                        )
                        .blur(radius: !state.expanded && state.hoveringNotch ? 3.5 : 0)

                        if !state.expanded && state.hoveringNotch {
                            Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.35), radius: 2)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: state.flashDirection)
            .animation(.spring(response: 0.24, dampingFraction: 0.75), value: state.hoveringNotch)
            .animation(.easeInOut(duration: 0.15), value: media.isPlaying)
        }
        .foregroundStyle(.white)
    }
}

struct EqualizerBars: View {
    let active: Bool
    var useGradient: Bool = false
    var tint: Color = Color(white: 0.82)
    var namespace: Namespace.ID? = nil
    @ObservedObject private var visualizer = AudioVisualizer.shared

    var body: some View {
        Group {
            if let namespace {
                barsView.matchedGeometryEffect(id: "mediaVisualizer", in: namespace)
            } else {
                barsView
            }
        }
        .animation(.smooth(duration: 0.25), value: active)
        .animation(.linear(duration: 0.07), value: visualizer.levels)
        .animation(.easeInOut(duration: 0.25), value: tint)
    }

    @ViewBuilder
    private var barsView: some View {
        bars
    }

    private var bars: some View {
        let count = AudioVisualizer.barCount
        let minimumHeight: CGFloat = useGradient ? 3.5 : 2
        let dynamicHeight: CGFloat = useGradient ? 22 : 13
        return HStack(alignment: .center, spacing: useGradient ? 2.6 : 1.5) {
            ForEach(0..<count, id: \.self) { i in
                let level = min(1, sqrt(CGFloat(visualizer.levels[i])) * 1.2)
                Capsule()
                    .fill(tint)
                    .frame(
                        width: useGradient ? 3.0 : 1.8,
                        height: active
                            ? minimumHeight + level * dynamicHeight
                            : (useGradient ? 4 : 2)
                    )
            }
        }
        .frame(height: useGradient ? 22 : 11)
    }
}

struct MarqueeText: View {
    let text: String
    let width: CGFloat
    @State private var offset: CGFloat = 0

    private let font = NSFont.systemFont(ofSize: 11, weight: .medium)
    private let gap: CGFloat = 28

    private var textWidth: CGFloat { (text as NSString).size(withAttributes: [.font: font]).width }

    var body: some View {
        Group {
            if textWidth <= width {
                label.frame(width: width, alignment: .leading)
            } else {
                HStack(spacing: gap) { label; label }
                    .fixedSize()
                    .offset(x: offset)
                    .frame(width: width, alignment: .leading)
                    .clipped()
                    .onAppear { start() }
            }
        }
    }

    private var label: some View {
        Text(text).font(Font(font)).lineLimit(1).fixedSize()
    }

    private func start() {
        offset = 0
        let distance = textWidth + gap
        withAnimation(.linear(duration: Double(distance) / 28).delay(1.2).repeatForever(autoreverses: false)) {
            offset = -distance
        }
    }
}
