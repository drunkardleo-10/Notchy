import AppKit
import EventKit

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: NSColor
    let joinURL: URL?
}

@MainActor
final class CalendarModel: ObservableObject {
    enum Access { case unknown, granted, denied }

    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var dayEvents: [CalendarEvent] = []
    @Published private(set) var nextDayEvents: [CalendarEvent] = []
    @Published private(set) var selectedDate = Calendar.current.startOfDay(for: Date())
    @Published private(set) var access: Access = .unknown
    @Published private(set) var resetToken = 0

    var onMeetingSoon: ((CalendarEvent, Int) -> Void)?

    private let store = EKEventStore()
    private var alerted = Set<String>()
    private var timer: Timer?

    private static let meetingHosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com", "whereby.com", "slack.com/huddle"]

    init() {
        updateAccess()
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh(); self?.checkUpcoming() }
        }
        refresh()
    }

    private func updateAccess() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: access = .granted
        case .notDetermined: access = .unknown
        default: access = .denied
        }
    }

    func requestAccess() {
        store.requestFullAccessToEvents { _, _ in
            DispatchQueue.main.async { self.updateAccess(); self.refresh() }
        }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    func refresh() {
        updateAccess()
        guard access == .granted, Pref.bool(Pref.calendar) else { events = []; dayEvents = []; nextDayEvents = []; return }
        let now = Date()
        loadDayEvents()
        let predicate = store.predicateForEvents(withStart: Calendar.current.startOfDay(for: now),
                                                 end: now.addingTimeInterval(36 * 3600), calendars: nil)
        events = store.events(matching: predicate)
            .filter { $0.endDate > now && $0.status != .canceled }
            .sorted { $0.startDate < $1.startDate }
            .prefix(8)
            .map(Self.makeEvent)
    }

    func resetToToday() {
        selectedDate = Calendar.current.startOfDay(for: Date())
        loadDayEvents()
        resetToken += 1
    }

    func select(_ date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
        loadDayEvents()
    }

    private func loadDayEvents() {
        guard access == .granted else { dayEvents = []; nextDayEvents = []; return }
        let start = selectedDate
        let next = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        let after = Calendar.current.date(byAdding: .day, value: 1, to: next) ?? next.addingTimeInterval(86400)
        dayEvents = events(from: start, to: next)
        nextDayEvents = events(from: next, to: after)
    }

    private func events(from start: Date, to end: Date) -> [CalendarEvent] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { $0.status != .canceled }
            .sorted { $0.startDate < $1.startDate }
            .prefix(20)
            .map(Self.makeEvent)
    }

    private static func makeEvent(_ e: EKEvent) -> CalendarEvent {
        CalendarEvent(id: e.eventIdentifier ?? UUID().uuidString, title: e.title ?? "Untitled",
                      start: e.startDate, end: e.endDate, isAllDay: e.isAllDay,
                      color: e.calendar.color ?? .systemBlue, joinURL: meetingLink(in: e))
    }

    private func checkUpcoming() {
        let now = Date()
        for e in events where !e.isAllDay && e.start > now && !alerted.contains(e.id) {
            let minutes = Int((e.start.timeIntervalSince(now) / 60).rounded(.up))
            if minutes <= 5 {
                alerted.insert(e.id)
                onMeetingSoon?(e, minutes)
            }
        }
    }

    private static func meetingLink(in event: EKEvent) -> URL? {
        let haystack = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }.joined(separator: " ")
        guard let regex = try? NSRegularExpression(pattern: "https?://[^\\s<>\"')]+") else { return nil }
        let range = NSRange(haystack.startIndex..., in: haystack)
        for match in regex.matches(in: haystack, range: range) {
            guard let r = Range(match.range, in: haystack) else { continue }
            let candidate = String(haystack[r])
            if meetingHosts.contains(where: candidate.contains) { return URL(string: candidate) }
        }
        return nil
    }
}
