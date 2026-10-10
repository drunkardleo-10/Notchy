import SwiftUI

struct NotchyMascot: View {
    let pose: NotchyPose
    var cell: CGFloat = 2
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let duration = NotchyMascotSprites.frameDuration(for: pose)
        let count = NotchyMascotSprites.frameCount(for: pose)
        Group {
            if animated && !reduceMotion {
                TimelineView(.periodic(from: .now, by: duration)) { context in
                    canvas(frame: Int(context.date.timeIntervalSinceReferenceDate / duration) % count)
                }
            } else {
                canvas(frame: 0)
            }
        }
        .frame(width: CGFloat(NotchyMascotSprites.columns) * cell, height: CGFloat(NotchyMascotSprites.rows) * cell)
        .accessibilityHidden(true)
    }

    private func canvas(frame: Int) -> some View {
        Canvas { context, _ in
            for layer in NotchyMascotSprites.layers(for: pose, frame: frame) {
                for (row, line) in layer.pixels.enumerated() {
                    for (column, key) in line.enumerated() {
                        guard let color = NotchyMascotSprites.palette[key] else { continue }
                        let rect = CGRect(
                            x: CGFloat(layer.x + column) * cell,
                            y: CGFloat(layer.y + row) * cell,
                            width: cell,
                            height: cell
                        )
                        context.fill(Path(rect), with: .color(color), style: FillStyle(antialiased: false))
                    }
                }
            }
        }
    }
}
