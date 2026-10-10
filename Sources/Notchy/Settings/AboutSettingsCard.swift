import SwiftUI

struct AboutSettingsCard: View {
    var onCheckForUpdates: () -> Void

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "Dev"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }

    var body: some View {
        SettingsCard(title: "About") {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.indigo.gradient)
                        .frame(width: 30, height: 30)
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(version)
                        .font(.system(size: 11.5).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.42))
                }
                Spacer()
                QuickActionButton(title: "Replay Onboarding", prominent: false) {
                    NotificationCenter.default.post(name: .replayOnboarding, object: nil)
                }
                QuickActionButton(title: "Check for Updates", prominent: false, action: onCheckForUpdates)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
        }
    }
}
