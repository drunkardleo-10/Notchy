import SwiftUI

struct CalendarEventList: View {
    let events: [CalendarEvent]
    let nextEvents: [CalendarEvent]
    let date: Date

    private let cal = Calendar.current
    private static let tint = Color(red: 0.93, green: 0.38, blue: 0.35)

    private var nextDate: Date { cal.date(byAdding: .day, value: 1, to: date) ?? date }

    private var nextLabel: String {
        cal.isDateInTomorrow(nextDate) ? "TOMORROW" : nextDate.formatted(.dateTime.weekday(.abbreviated).day()).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 5) {
                    if events.isEmpty {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("No events").font(.system(size: 15, weight: .bold))
                            Text("This day is clear").font(.system(size: 13)).foregroundStyle(.white.opacity(0.45))
                        }
                        .padding(.bottom, 2)
                    } else {
                        ForEach(events) { EventRow(event: $0) }
                    }
                    if !nextEvents.isEmpty {
                        Text(nextLabel)
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.top, 3)
                        ForEach(nextEvents) { EventRow(event: $0) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeOut(duration: 0.2), value: events)
        .animation(.easeOut(duration: 0.2), value: nextEvents)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .foregroundStyle(Self.tint)
            Text(date.formatted(.dateTime.day()))
                .foregroundStyle(.white)
            Text("W\(cal.component(.weekOfYear, from: date))")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Self.tint.opacity(0.75))
            Spacer(minLength: 0)
        }
        .font(.system(size: 14, weight: .bold))
        .frame(height: 18)
        .contentTransition(.interpolate)
    }
}

private struct EventRow: View {
    let event: CalendarEvent

    private var timeText: String {
        if event.isAllDay { return "All day" }
        let start = event.start.formatted(date: .omitted, time: .shortened)
        let end = event.end.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    private var finished: Bool { !event.isAllDay && event.end < Date() }

    var body: some View {
        HStack(spacing: 7) {
            Capsule().fill(Color(nsColor: event.color)).frame(width: 3, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                Text(timeText).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
            }
            Spacer(minLength: 4)
            if let url = event.joinURL {
                Button { NSWorkspace.shared.open(url) } label: {
                    Image(systemName: "video.fill").font(.system(size: 9, weight: .semibold))
                        .frame(width: 24, height: 20)
                        .background(Color.green.opacity(0.85), in: Capsule())
                        .contentShape(Capsule())
                }.buttonStyle(PressScaleStyle())
            }
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(Color(nsColor: event.color).opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
        .opacity(finished ? 0.45 : 1)
    }
}
