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

    private var side: CGFloat { LiveActivityLayout.sideWidth }

    var body: some View {
        NotchAccessory(
            notch: notch,
            leadingWidth: side,
            trailingWidth: side
        ) {
            ArtworkView(image: media.artwork, size: 20, cornerRadius: 5, namespace: albumArtNamespace)
        } trailing: {
            EqualizerBars(
                active: media.isPlaying,
                tint: media.artworkTint,
                namespace: visualizerNamespace
            )
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
