import SwiftUI
import ServiceManagement

private struct NotchDisplayModeRow: View {
    @Binding var mode: String
    @Binding var externalDisplayID: String
    let externalDisplays: [NSScreen]

    private var selectedMode: NotchDisplayMode {
        NotchDisplayMode(rawValue: mode) ?? .main
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                SettingsRowIcon(icon: "display", color: .cyan)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Text("Notch display")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                        SettingsInfoIcon(help: "Choose which display shows the notch. All displays creates a separate, independently expandable notch on each screen.")
                    }
                    Text(selectedMode.detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Picker("Notch display", selection: $mode) {
                    ForEach(NotchDisplayMode.allCases) { option in
                        Text(option.title)
                            .tag(option.rawValue)
                            .disabled(option == .external && externalDisplays.isEmpty)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 150, alignment: .trailing)
            }
            if selectedMode == .external, !externalDisplays.isEmpty {
                HStack(spacing: 8) {
                    Spacer(minLength: 42)
                    Text("Display")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Picker("External display", selection: $externalDisplayID) {
                        ForEach(externalDisplays, id: \.self) { display in
                            Text(display.localizedName)
                                .tag(NotchGeometry.screenID(display) ?? "")
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 150, alignment: .trailing)
                }
                .padding(.leading, 42)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
    }
}

private struct ExpandDelayRow: View {
    @Binding var delay: Double

    var body: some View {
        HStack(spacing: 12) {
            SettingsRowIcon(icon: "timer", color: .orange)
            HStack(spacing: 7) {
                Text("Expand delay")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                SettingsInfoIcon(help: "Wait this long before opening the shelf after you hover over the notch.")
            }
            Spacer(minLength: 6)
            Slider(value: $delay, in: 0...1.5, step: 0.05)
                .frame(width: 180)
            Text(String(format: "%.2fs", delay))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
    }
}

private struct AnimationSpeedRow: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 12) {
            SettingsRowIcon(icon: "hare.fill", color: .purple)
            HStack(spacing: 7) {
                Text("Animation speed")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                SettingsInfoIcon(help: "Adjust the speed of notch and shelf animations.")
            }
            Spacer(minLength: 4)
            AnimationSpeedSelector(selection: $selection)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
    }
}

private struct SettingsRowIcon: View {
    let icon: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.gradient)
                .frame(width: 30, height: 30)
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

private struct AnimationSpeedSelector: View {
    @Binding var selection: String

    private var selectedSpeed: NotchAnimationSpeed {
        NotchAnimationSpeed(rawValue: selection) ?? .normal
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(NotchAnimationSpeed.allCases) { speed in
                let isSelected = selectedSpeed == speed
                Button {
                    withAnimation(NotchAnimation.spring(response: 0.2, dampingFraction: 0.8)) {
                        selection = speed.rawValue
                    }
                } label: {
                    Image(systemName: speed.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                        .frame(width: 36, height: 32)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color.accentColor)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .help(speed.title)
                .accessibilityLabel("\(speed.title) animation speed")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.07)))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

struct GeneralSettingsTab: View {
    @Binding var glassLevel: Double
    @Binding var hoverOpen: Bool
    @Binding var notchDisplayMode: String
    @Binding var externalDisplayID: String
    @Binding var expandDelay: Double
    @Binding var animationSpeed: String
    @Binding var haptics: Bool
    @Binding var island: Bool
    @Binding var limit: Int
    @Binding var launchAtLogin: Bool
    let externalDisplays: [NSScreen]
    var onGlassPreviewChanged: (Bool) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                DynamicGlassSettingsCard(glassLevel: $glassLevel, onEditingChanged: onGlassPreviewChanged)

                SettingsCard(title: "Notch Behavior") {
                    SettingRow(
                        icon: "cursor.rays",
                        color: .blue,
                        title: "Auto-expand",
                        help: "Open the shelf by hovering over the notch, without clicking it.",
                        isOn: $hoverOpen
                    )
                    CardDivider()
                    NotchDisplayModeRow(
                        mode: $notchDisplayMode,
                        externalDisplayID: $externalDisplayID,
                        externalDisplays: externalDisplays
                    )
                    CardDivider()
                    ExpandDelayRow(delay: $expandDelay)
                    CardDivider()
                    AnimationSpeedRow(selection: $animationSpeed)
                    CardDivider()
                    SettingRow(icon: "waveform.path", color: .purple, title: "Haptic Feedback", isOn: $haptics)
                    CardDivider()
                    SettingRow(icon: "rectangle.inset.filled", color: .cyan, title: "Dynamic Island Style", subtitle: "Ignore hardware notch", isOn: $island)
                }
                SettingsCard(title: "Clipboard", subtitle: "History never records passwords") {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.orange.gradient)
                                .frame(width: 30, height: 30)
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Text("History Size")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                        Spacer()
                        HStack(spacing: 0) {
                            Button { limit = max(10, limit - 10) } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 28, height: 26)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            Text("\(limit)")
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white)
                                .frame(minWidth: 34)
                            Button { limit = min(500, limit + 10) } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 28, height: 26)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                        .background(Capsule().fill(.white.opacity(0.09)))
                        .overlay { Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1) }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                }
                SettingsCard(title: "Startup") {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.gray.gradient)
                                .frame(width: 30, height: 30)
                            Image(systemName: "power")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Text("Launch at Login")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                        Spacer()
                        PremiumToggle(isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { _, on in
                                try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                            }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                            launchAtLogin.toggle()
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }
}
