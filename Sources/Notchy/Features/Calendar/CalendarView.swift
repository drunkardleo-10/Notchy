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
            HStack(alignment: .top, spacing: 14) {
                CalendarMonthGrid(selected: calendar.selectedDate, resetToken: calendar.resetToken, onSelect: calendar.select)
                    .frame(width: 198)
                CalendarEventList(events: calendar.dayEvents, nextEvents: calendar.nextDayEvents, date: calendar.selectedDate)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { calendar.refresh() }
        }
    }

    private func placeholder(icon: String, title: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 22))
            Text(title).font(.system(size: 12))
            Button(button, action: action).buttonStyle(.plain).font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 5).background(.white.opacity(0.18), in: Capsule())
                .contentShape(Capsule())
        }
        .foregroundStyle(.white.opacity(0.7)).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
