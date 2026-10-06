import SwiftUI

struct MediaSettingsTab: View {
    @Binding var liveActivity: Bool
    @Binding var browserMedia: Bool
    @Binding var pausedActivityTimeout: Double

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                SettingsCard(title: "Notch Integration", subtitle: "Live activity inside the collapsed notch") {
                    SettingRow(icon: "waveform", color: .pink, title: "Live Activity", subtitle: "Show now playing in the notch", isOn: $liveActivity)
                    CardDivider()
                    HStack(spacing: 12) {
                        Image(systemName: "pause.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Close after pause")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.92))
                            Text("Hide the live activity when playback is paused")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.white.opacity(0.42))
                        }
                        Spacer()
                        Text("\(Int(pausedActivityTimeout))s")
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 28, alignment: .trailing)
                        Slider(value: $pausedActivityTimeout, in: 0...30, step: 1)
                            .frame(width: 100)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                }
                SettingsCard(title: "Browser Sources", subtitle: "Detect web playback automatically") {
                    SettingRow(icon: "globe", color: .blue, title: "Browser Media", subtitle: "YouTube, SoundCloud and more", isOn: $browserMedia)
                    VStack(alignment: .leading, spacing: 0) {
                        Divider().background(Color.white.opacity(0.07))
                        Text("For track details from Chrome, Brave, Arc or Edge, enable View → Developer → Allow JavaScript from Apple Events.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.38))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                    }
                }
            }
            .padding(.top, 4)
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }
}
