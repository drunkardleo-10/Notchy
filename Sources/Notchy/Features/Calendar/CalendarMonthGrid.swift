import SwiftUI

struct CalendarMonthGrid: View {
    let selected: Date
    let resetToken: Int
    let onSelect: (Date) -> Void
    @State private var month: Date

    private let cal = Calendar.current
    private static let todayTint = Color(red: 0.93, green: 0.38, blue: 0.35)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    init(selected: Date, resetToken: Int, onSelect: @escaping (Date) -> Void) {
        self.selected = selected
        self.resetToken = resetToken
        self.onSelect = onSelect
        _month = State(initialValue: Self.startOfMonth(selected))
    }

    private static func startOfMonth(_ date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    private var weekdaySymbols: [String] {
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let offset = cal.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private var cells: [Date?] {
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let days = (0..<count).map { cal.date(byAdding: .day, value: $0, to: month) }
        let padding = max(0, 42 - lead - count)
        return Array(repeating: nil, count: lead) + days + Array(repeating: nil, count: padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            header
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(isWeekendColumn(index) ? 0.35 : 0.7))
                        .frame(height: 16)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        DayNumber(
                            day: day,
                            isToday: cal.isDateInToday(day),
                            isSelected: cal.isDate(day, inSameDayAs: selected),
                            isWeekend: cal.isDateInWeekend(day)
                        )
                        .onTapGesture { onSelect(day) }
                    } else {
                        Color.clear.frame(height: 17)
                    }
                }
            }
        }
        .onChange(of: resetToken) { _, _ in
            month = Self.startOfMonth(selected)
        }
        .onChange(of: selected) { _, newValue in
            month = Self.startOfMonth(newValue)
        }
    }

    private func isWeekendColumn(_ index: Int) -> Bool {
        let weekday = (cal.firstWeekday - 1 + index) % 7 + 1
        return weekday == 1 || weekday == 7
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text(month.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Self.todayTint)
            Text(month.formatted(.dateTime.year()))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            Spacer(minLength: 0)
            stepButton("chevron.left", -1)
            stepButton("chevron.right", 1)
        }
        .frame(height: 18)
        .contentTransition(.interpolate)
    }

    private func stepButton(_ symbol: String, _ delta: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                month = cal.date(byAdding: .month, value: delta, to: month) ?? month
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 18, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct DayNumber: View {
    let day: Date
    let isToday: Bool
    let isSelected: Bool
    let isWeekend: Bool

    private static let todayTint = Color(red: 0.93, green: 0.38, blue: 0.35)

    var body: some View {
        Text(day.formatted(.dateTime.day()))
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .foregroundStyle(isToday ? .white : .white.opacity(isWeekend ? 0.45 : 0.9))
            .frame(width: 24, height: 17)
            .background {
                if isToday {
                    Capsule().fill(Self.todayTint)
                } else if isSelected {
                    Capsule().fill(Color.white.opacity(0.2))
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
    }
}
