import SwiftUI

struct WidgetsSettingsTab: View {
    @Binding var lockWidgets: Bool
    @Binding var battery: Bool
    @Binding var weather: Bool
    @Binding var airQuality: Bool
    @Binding var sun: Bool
    @Binding var event: Bool
    @Binding var media: Bool
    @Binding var offset: Double

    private var previewItems: [LockWidgetItem] {
        [
            battery ? LockWidgetItem(id: "battery", icon: "laptopcomputer", value: "80%", label: "Plugged In") : nil,
            weather ? LockWidgetItem(id: "weather", icon: "cloud.sun.fill", value: "18°", label: "Partly Cloudy") : nil,
            airQuality ? LockWidgetItem(id: "aqi", icon: "aqi.medium", value: "AQI 57", label: "Moderate") : nil,
            sun ? LockWidgetItem(id: "sun", icon: "sunrise.fill", value: "7:13 AM") : nil,
            event ? LockWidgetItem(id: "event", icon: "calendar", value: "3:00 PM", label: "Design Review") : nil,
        ].compactMap { $0 }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                preview
                SettingsCard(title: "Lock Screen") {
                    SettingRow(icon: "lock.fill", color: .indigo, title: "Lock Screen Widgets",
                               subtitle: "Glanceable info beneath the clock", isOn: $lockWidgets)
                }
                if lockWidgets {
                    SettingsCard(title: "Widgets") {
                        SettingRow(icon: "battery.75percent", color: .green, title: "Battery", subtitle: "Charge level and power source", isOn: $battery)
                        CardDivider()
                        SettingRow(icon: "cloud.sun.fill", color: .blue, title: "Weather", subtitle: "Current temperature and conditions", isOn: $weather)
                        CardDivider()
                        SettingRow(icon: "aqi.medium", color: .teal, title: "Air Quality", subtitle: "US AQI for your area", isOn: $airQuality)
                        CardDivider()
                        SettingRow(icon: "sunrise.fill", color: .orange, title: "Sunrise & Sunset", subtitle: "Whichever comes next", isOn: $sun)
                        CardDivider()
                        SettingRow(icon: "calendar", color: .red, title: "Next Event", subtitle: "Your next meeting today", isOn: $event)
                        CardDivider()
                        SettingRow(icon: "play.fill", color: .pink, title: "Media Player", subtitle: "Now playing card with controls", isOn: $media)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    SettingsCard(title: "Layout") {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.and.down")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.75))
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Vertical Position")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.92))
                                Text("Nudge the row to sit under your clock")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.white.opacity(0.42))
                            }
                            Spacer()
                            Text("\(Int(offset))")
                                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 30, alignment: .trailing)
                            Slider(value: $offset, in: -80...80, step: 2)
                                .frame(width: 110)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    Text("Weather, air quality and sun times use your approximate location with Open-Meteo.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.38))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                }
            }
            .padding(.top, 4)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: lockWidgets)
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private var preview: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.55, green: 0.27, blue: 0.18), Color(red: 0.24, green: 0.12, blue: 0.09)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 2) {
                Text(Date().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text(Date().formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()))
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                Color.clear
                    .frame(height: 24)
                    .padding(.top, 4)
            }
            .overlay(alignment: .bottom) {
                ViewThatFits(in: .horizontal) {
                    ForEach([0.58, 0.5, 0.42, 0.36], id: \.self) { scale in
                        LockWidgetsRow(items: lockWidgets ? previewItems : [], scale: scale)
                    }
                }
                .frame(width: 480, height: 24)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }
}
