import SwiftUI

enum EventCountdown {
    static func next(in events: [CalendarEvent], now: Date) -> CalendarEvent? {
        events.first { !$0.isAllDay && $0.end > now }
    }

    static func text(for event: CalendarEvent, now: Date) -> String {
        if event.start > now {
            let minutes = Int((event.start.timeIntervalSince(now) / 60).rounded(.up))
            return "Next " + duration(minutes: minutes, prefix: "in ")
        }
        let minutes = Int((event.end.timeIntervalSince(now) / 60).rounded(.up))
        return "Live · " + duration(minutes: minutes, suffix: " left")
    }

    private static func duration(minutes: Int, prefix: String = "", suffix: String = "") -> String {
        if minutes <= 1 { return minutes <= 0 ? "now" : prefix + "1 min" + suffix }
        if minutes < 60 { return prefix + "\(minutes) min" + suffix }
        let hours = minutes / 60
        let rest = minutes % 60
        return prefix + (rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m") + suffix
    }
}

struct EventCountdownLabel: View {
    let events: [CalendarEvent]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            if let event = EventCountdown.next(in: events, now: context.date) {
                let live = event.start <= context.date
                Text(EventCountdown.text(for: event, now: context.date))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(live ? Color.green : Color.white.opacity(0.6))
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
        }
    }
}
