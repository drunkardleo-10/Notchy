import SwiftUI

struct SettingsWaitCard: View {
    let kind: PermissionKind
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            NotchyMascot(pose: .scan, cell: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Switch on notchy in System Settings")
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                Text("\(kind.shortTitle). I'll pop back the moment it's on.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            OnboardingButton(title: "Back to setup", prominent: false, action: onBack)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
