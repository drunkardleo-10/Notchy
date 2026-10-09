import SwiftUI
import AppKit

struct DissolveDot {
    let x: CGFloat
    let y: CGFloat
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    let seedA: Double
    let seedB: Double
    let seedC: Double
}

struct DissolveField {
    let size: CGSize
    let cell: CGFloat
    let dots: [DissolveDot]
}

@MainActor
enum Dissolve {
    static let duration: Double = 1.0
    static let margin: CGFloat = 60
    static let cell: CGFloat = 2

    static func capture<V: View>(_ view: V) -> DissolveField? {
        let renderer = ImageRenderer(content: view.fixedSize())
        renderer.scale = 2
        guard let image = renderer.cgImage else { return nil }
        let size = CGSize(width: CGFloat(image.width) / 2, height: CGFloat(image.height) / 2)
        let cols = max(1, Int((size.width / cell).rounded()))
        let rows = max(1, Int((size.height / cell).rounded()))
        var bytes = [UInt8](repeating: 0, count: cols * rows * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: cols, height: rows, bitsPerComponent: 8,
                bytesPerRow: cols * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: cols, height: rows))
            return true
        }
        guard drawn else { return nil }
        var dots: [DissolveDot] = []
        dots.reserveCapacity(cols * rows)
        for row in 0..<rows {
            for col in 0..<cols {
                let i = (row * cols + col) * 4
                let a = Double(bytes[i + 3]) / 255
                guard a > 0.1 else { continue }
                dots.append(DissolveDot(
                    x: (CGFloat(col) + 0.5) * size.width / CGFloat(cols),
                    y: (CGFloat(row) + 0.5) * size.height / CGFloat(rows),
                    red: min(1, Double(bytes[i]) / 255 / a),
                    green: min(1, Double(bytes[i + 1]) / 255 / a),
                    blue: min(1, Double(bytes[i + 2]) / 255 / a),
                    alpha: a,
                    seedA: .random(in: 0...1),
                    seedB: .random(in: 0...1),
                    seedC: .random(in: 0...1)
                ))
            }
        }
        return DissolveField(size: size, cell: cell, dots: dots)
    }
}

struct DissolveLayer: View {
    let field: DissolveField
    let start: Date

    var body: some View {
        TimelineView(.animation) { context in
            let progress = context.date.timeIntervalSince(start) / Dissolve.duration
            Canvas { gc, _ in
                guard progress < 1.2 else { return }
                gc.translateBy(x: Dissolve.margin, y: Dissolve.margin)
                let width = max(field.size.width, 1)
                for dot in field.dots {
                    let begin = Double(dot.x / width) * 0.4 + dot.seedA * 0.15
                    let local = min(1, max(0, (progress - begin) / 0.45))
                    guard local < 1 else { continue }
                    let wobble = sin(local * 6 + dot.seedA * 6) * 3 * local
                    let dx = (10 + 44 * dot.seedB) * local + wobble
                    let dy = -(8 + 38 * dot.seedC) * local
                    let side = field.cell * (1 - 0.55 * local) + 0.2
                    let rect = CGRect(x: dot.x + dx - side / 2, y: dot.y + dy - side / 2, width: side, height: side)
                    let opacity = dot.alpha * pow(1 - local, 1.3)
                    gc.fill(
                        Path(roundedRect: rect, cornerRadius: side / 2),
                        with: .color(Color(.sRGB, red: dot.red, green: dot.green, blue: dot.blue, opacity: opacity))
                    )
                }
            }
        }
        .frame(width: field.size.width + Dissolve.margin * 2, height: field.size.height + Dissolve.margin * 2)
        .allowsHitTesting(false)
    }
}

private struct DissolveModifier<Snapshot: View>: ViewModifier {
    let delay: Double?
    let snapshot: () -> Snapshot
    @State private var field: DissolveField?
    @State private var start: Date?

    func body(content: Content) -> some View {
        content
            .opacity(field == nil ? 1 : 0)
            .allowsHitTesting(delay == nil)
            .overlay {
                if let field, let start {
                    DissolveLayer(field: field, start: start)
                }
            }
            .onChange(of: delay) { _, value in
                guard let value else { return }
                Task { @MainActor in
                    if value > 0 { try? await Task.sleep(nanoseconds: UInt64(value * 1_000_000_000)) }
                    let captured = Dissolve.capture(snapshot())
                    start = Date()
                    withAnimation(.easeOut(duration: 0.12)) { field = captured }
                }
            }
    }
}

extension View {
    func dissolving<Snapshot: View>(after delay: Double?, snapshot: @escaping () -> Snapshot) -> some View {
        modifier(DissolveModifier(delay: delay, snapshot: snapshot))
    }
}
