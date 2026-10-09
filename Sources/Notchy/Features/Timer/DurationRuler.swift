import SwiftUI
import AppKit

struct DurationRuler: View {
    @Binding var minutes: Int
    var tint: Color = .orange
    @State private var offset: Double
    @State private var dragOrigin: Double?
    @State private var snapTask: Task<Void, Never>?
    @State private var lastDetent = Date.distantPast

    private let tickSpacing: CGFloat = 8
    private let range = 1...120

    init(minutes: Binding<Int>, tint: Color = .orange) {
        _minutes = minutes
        self.tint = tint
        _offset = State(initialValue: Double(minutes.wrappedValue))
    }

    var body: some View {
        RulerTicks(offset: offset, tint: tint, spacing: tickSpacing)
            .frame(height: 52)
            .overlay(alignment: .bottom) {
                VStack(spacing: 3) {
                    Capsule()
                        .fill(tint)
                        .frame(width: 2, height: 26)
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 5))
                        .rotationEffect(.degrees(180))
                        .foregroundStyle(tint)
                }
                .allowsHitTesting(false)
            }
            .overlay { input }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.12),
                        .init(color: .black, location: 0.88),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onChange(of: minutes) { _, value in
                guard dragOrigin == nil, snapTask == nil, Int(offset.rounded()) != value else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { offset = Double(value) }
            }
    }

    private var input: some View {
        GeometryReader { geo in
            PointerInput(
                onScroll: { points in
                    move(to: offset - Double(points / tickSpacing))
                    scheduleSnap(after: 0.14)
                },
                onDragChanged: { dx in
                    snapTask?.cancel()
                    snapTask = nil
                    let origin = dragOrigin ?? offset
                    dragOrigin = origin
                    move(to: origin - Double(dx / tickSpacing))
                },
                onDragEnded: {
                    dragOrigin = nil
                    scheduleSnap(after: 0)
                },
                onClick: { point in
                    let target = offset + Double((point.x - geo.size.width / 2) / tickSpacing)
                    let clamped = min(Double(range.upperBound), max(Double(range.lowerBound), target.rounded()))
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { offset = clamped }
                    commit(Int(clamped))
                }
            )
        }
    }

    private func move(to value: Double) {
        offset = min(Double(range.upperBound), max(Double(range.lowerBound), value))
        commit(Int(offset.rounded()))
    }

    private func commit(_ value: Int) {
        guard value != minutes else { return }
        minutes = value
        detent()
    }

    private func scheduleSnap(after delay: Double) {
        snapTask?.cancel()
        snapTask = Task { @MainActor in
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) { offset = Double(minutes) }
            snapTask = nil
        }
    }

    private func detent() {
        let now = Date()
        guard now.timeIntervalSince(lastDetent) >= 0.05 else { return }
        lastDetent = now
        if Pref.bool(Pref.hapticFeedback) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }
}

private struct RulerTicks: View, Animatable {
    var offset: Double
    let tint: Color
    let spacing: CGFloat

    var animatableData: Double {
        get { offset }
        set { offset = newValue }
    }

    var body: some View {
        Canvas { gc, size in
            let midX = size.width / 2
            let half = Double(midX / spacing) + 1
            let lo = max(1, Int((offset - half).rounded(.down)))
            let hi = min(120, Int((offset + half).rounded(.up)))
            guard lo <= hi else { return }
            for minute in lo...hi {
                let x = midX + CGFloat(Double(minute) - offset) * spacing
                let proximity = max(0, 1 - abs(x - midX) / midX)
                let major = minute.isMultiple(of: 5)
                let base: CGFloat = minute.isMultiple(of: 15) ? 25 : minute.isMultiple(of: 10) ? 22 : major ? 18 : 11
                let height = base * (0.94 + 0.06 * proximity)
                let width: CGFloat = major ? 2 : 1
                let fade = 0.2 + 0.8 * proximity
                let rect = CGRect(x: x - width / 2, y: size.height - height, width: width, height: height)
                gc.fill(
                    Path(roundedRect: rect, cornerRadius: width / 2),
                    with: .color(tint.opacity((major ? 0.9 : 0.45) * fade))
                )
                if major || minute == 1 {
                    let label = Text("\(minute)")
                        .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundColor(tint.opacity(0.85 * fade))
                    gc.draw(gc.resolve(label), at: CGPoint(x: x, y: 15), anchor: .center)
                }
            }
        }
    }
}
