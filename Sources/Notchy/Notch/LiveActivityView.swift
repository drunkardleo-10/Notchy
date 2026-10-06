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
    @ObservedObject var state: NotchState

    private var side: CGFloat { LiveActivityLayout.sideWidth }

    var body: some View {
        NotchAccessory(
            notch: notch,
            leadingWidth: side,
            trailingWidth: side
        ) {
            ArtworkView(image: media.artwork, size: 20, cornerRadius: 5, namespace: albumArtNamespace)
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
                    EqualizerBars(active: media.isPlaying)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: state.flashDirection)
        }
        .foregroundStyle(.white)
        .offset(x: state.swipeOffset * 0.35)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: state.swipeOffset)
    }
}

struct EqualizerBars: View {
    let active: Bool
    var useGradient: Bool = false

    var body: some View {
        barsView
            .animation(.smooth(duration: 0.25), value: active)
    }

    @ViewBuilder
    private var barsView: some View {
        if active {
            TimelineView(.animation(minimumInterval: 1 / 24)) { context in
                bars(t: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            bars(t: 0)
        }
    }

    private func bars(t: Double) -> some View {
        let count = useGradient ? 5 : 4
        return HStack(alignment: .center, spacing: useGradient ? 2.6 : 2.2) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(
                        width: useGradient ? 3.0 : 2.5,
                        height: active
                            ? (useGradient
                                ? (5 + 14 * abs(sin(t * (1.6 + Double(i) * 0.45) + Double(i))))
                                : (4 + 11 * abs(sin(t * (1.4 + Double(i) * 0.35) + Double(i)))))
                            : 4
                    )
            }
        }
        .frame(height: useGradient ? 20 : 16)
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
