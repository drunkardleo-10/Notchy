import AppKit
import EventKit
import IOKit.ps

struct LockWidgetItem: Identifiable, Equatable {
    let id: String
    let icon: String
    let value: String
    var label: String? = nil
}

@MainActor
final class LockWidgetsModel: ObservableObject {
    @Published private(set) var items: [LockWidgetItem] = []

    let weather = WeatherService()
    private let store = EKEventStore()
    private var requestedEvents = false

    init() {
        weather.onUpdate = { [weak self] in self?.refresh() }
        observePower()
    }

    private func observePower() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let model = Unmanaged<LockWidgetsModel>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { MainActor.assumeIsolated { model.refresh() } }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    func prepare() {
        guard Pref.bool(Pref.lockWidgets), !OnboardingModel.holdsPermissionPrompts else { return }
        if Pref.bool(Pref.widgetWeather) || Pref.bool(Pref.widgetAirQuality) || Pref.bool(Pref.widgetSun) {
            weather.prepare()
        }
        if Pref.bool(Pref.widgetEvent), !requestedEvents, EKEventStore.authorizationStatus(for: .event) == .notDetermined {
            requestedEvents = true
            store.requestFullAccessToEvents { _, _ in
                DispatchQueue.main.async { MainActor.assumeIsolated { self.refresh() } }
            }
        }
    }

    func refresh() {
        var next: [LockWidgetItem] = []
        if Pref.bool(Pref.widgetBattery), let item = batteryItem() { next.append(item) }
        if let snapshot = weather.snapshot {
            if Pref.bool(Pref.widgetWeather) {
                let condition = snapshot.condition
                next.append(LockWidgetItem(id: "weather", icon: condition.symbol, value: "\(snapshot.temperature)°", label: condition.label))
            }
            if Pref.bool(Pref.widgetAirQuality), let aqi = snapshot.aqi {
                let quality = WeatherSnapshot.airQuality(aqi)
                next.append(LockWidgetItem(id: "aqi", icon: quality.symbol, value: "AQI \(aqi)", label: quality.label))
            }
            if Pref.bool(Pref.widgetSun), let sun = snapshot.nextSunEvent(after: Date()) {
                next.append(LockWidgetItem(id: "sun", icon: sun.rising ? "sunrise.fill" : "sunset.fill",
                                           value: sun.time.formatted(date: .omitted, time: .shortened)))
            }
        }
        if Pref.bool(Pref.widgetEvent), let item = eventItem() { next.append(item) }
        if next != items { items = next }
    }

    private func batteryItem() -> LockWidgetItem? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let source = list.first,
              let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
              let percent = info[kIOPSCurrentCapacityKey] as? Int else { return nil }
        let onAC = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let charging = info[kIOPSIsChargingKey] as? Bool ?? false
        if onAC {
            return LockWidgetItem(id: "battery", icon: charging ? "bolt.fill" : "laptopcomputer",
                                  value: "\(percent)%", label: charging ? "Charging" : "Plugged In")
        }
        let level = [100, 75, 50, 25].first { percent >= $0 - 12 } ?? 0
        return LockWidgetItem(id: "battery", icon: "battery.\(level)percent", value: "\(percent)%", label: "Battery")
    }

    private func eventItem() -> LockWidgetItem? {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            return LockWidgetItem(id: "event", icon: "calendar.badge.exclamationmark", value: "Enable Calendar")
        }
        let now = Date()
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86400)
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        guard let event = store.events(matching: predicate)
            .filter({ !$0.isAllDay && $0.endDate > now && $0.status != .canceled })
            .min(by: { $0.startDate < $1.startDate }) else {
            return LockWidgetItem(id: "event", icon: "calendar", value: "Free", label: "Rest of Today")
        }
        let title = event.title ?? "Untitled"
        let short = title.count > 24 ? String(title.prefix(23)) + "…" : title
        let value = event.startDate <= now ? "Now" : event.startDate.formatted(date: .omitted, time: .shortened)
        return LockWidgetItem(id: "event", icon: "calendar", value: value, label: short)
    }
}
