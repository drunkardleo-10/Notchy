import SwiftUI

struct CalendarEventList: View {
    let events: [CalendarEvent]
    let date: Date

    var body: some View {
        Group {
            if events.isEmpty {
                VStack(spacing: 5) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(Calendar.current.isDateInToday(date) ? "No events today" : "No events")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Enjoy your day!")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(events) { EventRow(event: $0) }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: events)
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
        HStack(spacing: 8) {
            Capsule().fill(Color(nsColor: event.color)).frame(width: 3, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text(timeText).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 4)
            if let url = event.joinURL {
                Button { NSWorkspace.shared.open(url) } label: {
                    Image(systemName: "video.fill").font(.system(size: 10, weight: .semibold))
                        .frame(width: 26, height: 22)
                        .background(Color.green.opacity(0.85), in: Capsule())
                        .contentShape(Capsule())
                }.buttonStyle(PressScaleStyle())
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .opacity(finished ? 0.45 : 1)
    }
}
