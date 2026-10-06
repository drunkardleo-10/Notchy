import SwiftUI

struct HUDSettingsTab: View {
    @Binding var volumeHUD: Bool
    @Binding var volumeHUDStyle: String
    @Binding var brightnessHUD: Bool
    @Binding var airpodsHUD: Bool
    @Binding var batteryHUD: Bool
    @Binding var lockHUD: Bool
    @Binding var capsLockHUD: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                SettingsCard(title: "Audio & Display") {
                    SettingRow(icon: "speaker.wave.2.fill", color: .blue, title: "Volume HUD", isOn: $volumeHUD)
                    CardDivider()
                    HStack(spacing: 12) {
                        Text("Volume & Brightness")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.86))
                            .padding(.leading, 42)
                        Spacer(minLength: 8)
                        VolumeHUDStyleSelector(selection: $volumeHUDStyle)
                    }
                    .padding(.vertical, 8)
                    .padding(.trailing, 14)
                    CardDivider()
                    SettingRow(icon: "sun.max.fill", color: .orange, title: "Brightness HUD", isOn: $brightnessHUD)
                    CardDivider()
                    SettingRow(icon: "airpods", color: .teal, title: "AirPods HUD", subtitle: "Bluetooth audio connects", isOn: $airpodsHUD)
                }
                SettingsCard(title: "System Status") {
                    SettingRow(icon: "battery.100", color: .green, title: "Battery HUD", subtitle: "Plug in, low and full", isOn: $batteryHUD)
                    CardDivider()
                    SettingRow(icon: "lock.fill", color: .gray, title: "Lock Animation", isOn: $lockHUD)
                    CardDivider()
                    SettingRow(icon: "capslock.fill", color: .purple, title: "Caps Lock HUD", isOn: $capsLockHUD)
                }
            }
            .padding(.top, 4)
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }
}
