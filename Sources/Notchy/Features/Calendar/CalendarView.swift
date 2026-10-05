import SwiftUI

struct CalendarView: View {
    @ObservedObject var calendar: CalendarModel

    var body: some View {
        switch calendar.access {
        case .unknown:
            placeholder(icon: "calendar", title: "See your next meetings here",
                        button: "Allow Calendar Access", action: calendar.requestAccess)
        case .denied:
            placeholder(icon: "calendar.badge.exclamationmark", title: "Calendar access is turned off",
                        button: "Open Privacy Settings", action: calendar.openPrivacySettings)
        case .granted:
            if calendar.events.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle").font(.system(size: 22))
                    Text("Nothing coming up").font(.system(size: 12))
                }
                .foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 5) { ForEach(calendar.events) { EventRow(event: $0) } }
                }
            }
        }
    }

    private func placeholder(icon: String, title: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 22))
            Text(title).font(.system(size: 12))
            Button(button, action: action).buttonStyle(.plain).font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 5).background(.white.opacity(0.18), in: Capsule())
        }
        .foregroundStyle(.white.opacity(0.7)).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EventRow: View {
    let event: CalendarEvent

    private var timeText: String {
        if event.isAllDay { return "All day" }
        let f = DateFormatter()
        f.timeStyle = .short
        return "\(f.string(from: event.start)) – \(f.string(from: event.end))"
    }

    private var relative: String? {
        let minutes = Int(event.start.timeIntervalSinceNow / 60)
        if event.isAllDay { return nil }
        if minutes <= 0 { return "now" }
        if minutes < 60 { return "in \(minutes) min" }
        return nil
    }

    var body: some View {
        HStack(spacing: 8) {
            Capsule().fill(Color(nsColor: event.color)).frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text(timeText).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            if let relative { Text(relative).font(.system(size: 10)).foregroundStyle(.orange) }
            if let url = event.joinURL {
                Button { NSWorkspace.shared.open(url) } label: {
                    Label("Join", systemImage: "video.fill").font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 9).padding(.vertical, 4).background(Color.green.opacity(0.85), in: Capsule())
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}
