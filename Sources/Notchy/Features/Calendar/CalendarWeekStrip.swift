import SwiftUI

struct CalendarWeekStrip: View {
    let selected: Date
    let onSelect: (Date) -> Void
    @State private var position: Double
    @State private var dragOrigin: Double?

    private static let cellWidth: CGFloat = 36
    private static let dayRange = -30...90
    private let cal = Calendar.current

    init(selected: Date, onSelect: @escaping (Date) -> Void) {
        self.selected = selected
        self.onSelect = onSelect
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let index = cal.dateComponents([.day], from: today, to: selected).day ?? 0
        _position = State(initialValue: Double(index))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(selected.formatted(.dateTime.month(.wide)))
                    .font(.system(size: 22, weight: .bold))
                Text(selected.formatted(.dateTime.year()))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer(minLength: 0)
            }
            .contentTransition(.interpolate)
            .animation(.easeOut(duration: 0.2), value: selected)
            .padding(.leading, 4)

            GeometryReader { geo in
                DayStrip(position: position, selected: selected, cellWidth: Self.cellWidth, range: Self.dayRange)
                    .overlay {
                        PointerInput(
                            onScroll: { points in move(to: position - Double(points / Self.cellWidth)) },
                            onDragChanged: { dx in
                                let origin = dragOrigin ?? position
                                dragOrigin = origin
                                move(to: origin - Double(dx / Self.cellWidth))
                            },
                            onDragEnded: { dragOrigin = nil },
                            onClick: { point in
                                let index = Int((position + Double((point.x - geo.size.width / 2) / Self.cellWidth)).rounded())
                                select(index)
                            }
                        )
                    }
            }
            .frame(height: 66)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.1),
                        .init(color: .black, location: 0.9),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            Spacer(minLength: 0)
        }
    }

    private func move(to value: Double) {
        position = min(Double(Self.dayRange.upperBound), max(Double(Self.dayRange.lowerBound), value))
    }

    private func select(_ index: Int) {
        let clamped = min(Self.dayRange.upperBound, max(Self.dayRange.lowerBound, index))
        let today = cal.startOfDay(for: Date())
        guard let day = cal.date(byAdding: .day, value: clamped, to: today) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            position = Double(clamped)
            onSelect(day)
        }
    }
}

private struct DayStrip: View, Animatable {
    var position: Double
    let selected: Date
    let cellWidth: CGFloat
    let range: ClosedRange<Int>

    var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    private let cal = Calendar.current

    var body: some View {
        GeometryReader { geo in
            let half = Int(geo.size.width / 2 / cellWidth) + 2
            let center = Int(position.rounded())
            let lo = max(range.lowerBound, center - half)
            let hi = min(range.upperBound, center + half)
            let today = cal.startOfDay(for: Date())
            ZStack {
                if lo <= hi {
                    ForEach(lo...hi, id: \.self) { index in
                        let day = cal.date(byAdding: .day, value: index, to: today) ?? today
                        DayCell(day: day, isSelected: cal.isDate(day, inSameDayAs: selected), isToday: index == 0)
                            .frame(width: cellWidth)
                            .position(
                                x: geo.size.width / 2 + CGFloat(Double(index) - position) * cellWidth,
                                y: geo.size.height / 2
                            )
                    }
                }
            }
        }
    }
}

private struct DayCell: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(day.formatted(.dateTime.weekday(.narrow)))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
            Text(day.formatted(.dateTime.day()))
                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                .foregroundStyle(isSelected ? .white : isToday ? Color.accentColor : .white.opacity(0.85))
                .frame(width: 34, height: 34)
                .background {
                    if isSelected {
                        Circle().fill(Color.accentColor)
                    } else if isToday {
                        Circle().strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1)
                    }
                }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}
