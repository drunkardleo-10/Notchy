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
                isSource: !state.expanded,
                skipAnimationID: media.artworkSkipAnimationID,
                skipDirection: media.artworkSkipDirection,
                skipArtwork: media.artworkSkipArtwork
            )
        } trailing: {
            ZStack {
                EqualizerBars(
                    active: media.isPlaying,
                    tint: media.artworkTint,
                    namespace: visualizerNamespace,
                    isSource: !state.expanded
                )
                .blur(radius: !state.expanded && state.hoveringNotch ? 3.5 : 0)
                .opacity(state.flashDirection != nil ? 0 : 1)

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
                }

                if !state.expanded && state.hoveringNotch && state.flashDirection == nil {
                    Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 2)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: state.flashDirection)
        }
        .foregroundStyle(.white)
    }
}

struct EqualizerBars: View {
    let active: Bool
    var useGradient: Bool = false
    var tint: Color = Color(white: 0.82)
    var namespace: Namespace.ID? = nil
    var isSource: Bool = true
    @ObservedObject private var visualizer = AudioVisualizer.shared

    private var width: CGFloat { useGradient ? 31.0 : 18.3 }
    private var height: CGFloat { useGradient ? 22.0 : 11.0 }

    var body: some View {
        let barsView = bars
            .frame(width: width, height: height)
            .clipped()

        Group {
            if let namespace {
                barsView.matchedGeometryEffect(id: "mediaVisualizer", in: namespace, isSource: isSource)
            } else {
                barsView
            }
        }
    }

    private var bars: some View {
        let count = AudioVisualizer.barCount
        let minimumHeight: CGFloat = useGradient ? 3.5 : 2
        let dynamicHeight: CGFloat = useGradient ? 22 : 13
        return HStack(alignment: .center, spacing: useGradient ? 2.6 : 1.5) {
            ForEach(0..<count, id: \.self) { i in
                let raw = visualizer.levels.indices.contains(i) && visualizer.levels[i].isFinite ? CGFloat(visualizer.levels[i]) : 0
                BarCapsule(
                    level: min(1, sqrt(max(0, raw)) * 1.2),
                    active: active,
                    tint: tint,
                    barWidth: useGradient ? 3.0 : 1.8,
                    minimumHeight: minimumHeight,
                    dynamicHeight: dynamicHeight,
                    idleHeight: useGradient ? 4 : 2
                )
            }
        }
    }
}

private struct BarCapsule: View {
    let level: CGFloat
    let active: Bool
    let tint: Color
    let barWidth: CGFloat
    let minimumHeight: CGFloat
    let dynamicHeight: CGFloat
    let idleHeight: CGFloat

    @State private var animatedHeight: CGFloat = 2

    private var targetHeight: CGFloat {
        let safeLevel = level.isFinite ? max(0, min(1, level)) : 0
        let h = active ? minimumHeight + safeLevel * dynamicHeight : idleHeight
        return max(minimumHeight, h)
    }

    var body: some View {
        Capsule()
            .fill(tint)
            .frame(width: barWidth, height: animatedHeight)
            .onChange(of: targetHeight) { _, newHeight in
                withAnimation(.linear(duration: 0.07)) {
                    animatedHeight = newHeight
                }
            }
            .onAppear {
                animatedHeight = targetHeight
            }
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
