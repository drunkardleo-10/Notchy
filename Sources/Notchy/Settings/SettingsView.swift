import SwiftUI
import ServiceManagement

enum SettingsTab: Int, CaseIterable {
    case modules, media, huds, general
    var title: String {
        switch self {
        case .modules: return "Modules"
        case .media: return "Media"
        case .huds: return "HUDs"
        case .general: return "General"
        }
    }
    var icon: String {
        switch self {
        case .modules: return "square.grid.2x2.fill"
        case .media: return "music.note"
        case .huds: return "slider.horizontal.3"
        case .general: return "gearshape.fill"
        }
    }
}

struct PremiumToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                isOn.toggle()
            }
        } label: {
            ZStack {
                Capsule()
                    .fill(isOn ? Color.accentBlueGradient : Color.toggleOffGradient)
                    .frame(width: 46, height: 27)
                    .overlay {
                        Capsule()
                            .strokeBorder(isOn ? .white.opacity(0.18) : .white.opacity(0.1), lineWidth: 1)
                    }
                Circle()
                    .fill(.white)
                    .frame(width: 21, height: 21)
                    .offset(x: isOn ? 9.5 : -9.5)
                    .scaleEffect(isOn ? 1 : 0.94)
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isOn)
        }
        .buttonStyle(.plain)
        .frame(width: 46, height: 27)
    }
}

extension Color {
    static var accentBlueGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.05, green: 0.5, blue: 1.0), Color(red: 0.25, green: 0.62, blue: 1.0)], startPoint: .leading, endPoint: .trailing)
    }
    static var toggleOffGradient: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.12)], startPoint: .top, endPoint: .bottom)
    }
}

struct PillTabBar: View {
    @Binding var selection: SettingsTab
    @Namespace private var pill
    var body: some View {
        HStack(spacing: 2) {
            ForEach(SettingsTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        selection = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 13, weight: selection == tab ? .semibold : .medium))
                    }
                    .foregroundStyle(selection == tab ? .white : .white.opacity(0.5))
                    .padding(.vertical, 7)
                    .padding(.horizontal, 14)
                    .background {
                        if selection == tab {
                            Capsule()
                                .fill(Color.white.opacity(0.13))
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(4)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.06))
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

struct ModuleRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.gradient)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(isOn ? .white : .white.opacity(0.85))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            PremiumToggle(isOn: $isOn)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                isOn.toggle()
            }
        }
    }
}

struct SettingRow: View {
    let icon: String
    let color: Color
    let title: String
    var subtitle: String? = nil
    var help: String? = nil
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.gradient)
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 7) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                    if let help {
                        SettingsInfoIcon(help: help)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }
            Spacer()
            PremiumToggle(isOn: $isOn)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
    }
}

struct VolumeHUDStyleSelector: View {
    @Binding var selection: String

    private var selectedStyle: VolumeHUDStyle {
        VolumeHUDStyle(rawValue: selection) ?? .inline
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(VolumeHUDStyle.allCases) { style in
                let isSelected = selectedStyle == style
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selection = style.rawValue
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: style.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(style.title)
                            .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                    }
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background {
                        if isSelected {
                            Capsule().fill(.white.opacity(0.15))
                        }
                    }
                }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityLabel("\(style.title) volume and brightness indicators")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(.white.opacity(0.07)))
        .overlay { Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1) }
        .frame(width: 190)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .textCase(.uppercase)
                        .tracking(0.4)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.38))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
            VStack(spacing: 0) {
                content
            }
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    }
            }
        }
    }
}

struct CardDivider: View {
    var body: some View {
        Divider()
            .background(Color.white.opacity(0.07))
            .padding(.leading, 56)
            .padding(.trailing, 14)
    }
}

struct QuickActionButton: View {
    let title: String
    let prominent: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(prominent ? .white : .white.opacity(0.7))
                .padding(.vertical, 6)
                .padding(.horizontal, 13)
                .background {
                    Capsule()
                        .fill(prominent ? Color(red: 0.05, green: 0.5, blue: 1.0) : Color.white.opacity(0.09))
                        .overlay {
                            if !prominent {
                                Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1)
                            }
                        }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsInfoIcon: View {
    let help: String

    var body: some View {
        Image(systemName: "info.circle.fill")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
            .help(help)
            .accessibilityLabel(help)
    }
}

private struct ExpandTargetsRow: View {
    @Binding var mainMac: Bool
    @Binding var externalDisplays: Bool
    let externalDisplaysAvailable: Bool

    var body: some View {
        HStack(spacing: 12) {
            SettingsRowIcon(icon: "display", color: .cyan)
            HStack(spacing: 7) {
                Text("Expand on")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                SettingsInfoIcon(help: "Choose which displays open the shelf when you hover over the notch.")
            }
            Spacer(minLength: 4)
            Toggle("Main Mac", isOn: $mainMac)
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .font(.system(size: 12, weight: .medium))
            Toggle("External displays", isOn: $externalDisplays)
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .font(.system(size: 12, weight: .medium))
                .disabled(!externalDisplaysAvailable)
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
                }
                .buttonStyle(.plain)
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

struct SettingsView: View {
    var onGlassPreviewChanged: (Bool) -> Void = { _ in }

    @AppStorage(Pref.media) private var media = true
    @AppStorage(Pref.shelf) private var shelf = false
    @AppStorage(Pref.basket) private var basket = false
    @AppStorage(Pref.clipboard) private var clipboard = false
    @AppStorage(Pref.timer) private var timer = false
    @AppStorage(Pref.tools) private var tools = false
    @AppStorage(Pref.calendar) private var calendar = false
    @AppStorage(Pref.claude) private var claude = false
    @AppStorage(Pref.system) private var system = false
    @AppStorage(Pref.shortcuts) private var shortcuts = false
    @AppStorage(Pref.mirror) private var mirror = false

    @AppStorage(Pref.liveActivity) private var liveActivity = true
    @AppStorage(Pref.browserMedia) private var browserMedia = true
    @AppStorage(Pref.pausedActivityTimeout) private var pausedActivityTimeout = 5.0

    @AppStorage(Pref.volumeHUD) private var volumeHUD = true
    @AppStorage(Pref.volumeHUDStyle) private var volumeHUDStyle = VolumeHUDStyle.inline.rawValue
    @AppStorage(Pref.brightnessHUD) private var brightnessHUD = true
    @AppStorage(Pref.airpodsHUD) private var airpodsHUD = true
    @AppStorage(Pref.batteryHUD) private var batteryHUD = true
    @AppStorage(Pref.lockHUD) private var lockHUD = true
    @AppStorage(Pref.capsLockHUD) private var capsLockHUD = true

    @AppStorage(Pref.hoverOpen) private var hoverOpen = true
    @AppStorage(Pref.expandOnMainDisplay) private var expandOnMainDisplay = true
    @AppStorage(Pref.expandOnExternalDisplays) private var expandOnExternalDisplays = false
    @AppStorage(Pref.expandDelay) private var expandDelay = 0.25
    @AppStorage(Pref.notchAnimationSpeed) private var animationSpeed = NotchAnimationSpeed.normal.rawValue
    @AppStorage(Pref.hapticFeedback) private var haptics = true
    @AppStorage(Pref.islandMode) private var island = false
    @AppStorage(Pref.glassLevel) private var glassLevel = 0.5
    @AppStorage(Pref.clipboardLimit) private var limit = 50
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var externalDisplaysAvailable = NotchGeometry.hasExternalDisplays
    @State private var selection: SettingsTab = .modules

    private var enabledCount: Int {
        [media, shelf, clipboard, timer, calendar, claude, shortcuts, system, mirror, tools].filter { $0 }.count
    }

    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.11).ignoresSafeArea()
            VStack(spacing: 0) {
                PillTabBar(selection: $selection)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                ZStack {
                    switch selection {
                    case .modules: modulesTab
                    case .media: mediaTab
                    case .huds: hudsTab
                    case .general: generalTab
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selection)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .frame(width: 560, height: 600)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            externalDisplaysAvailable = NotchGeometry.hasExternalDisplays
        }
    }

    private var modulesTab: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Notch Modules")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(enabledCount) on")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.vertical, 3)
                            .padding(.horizontal, 8)
                            .background(Capsule().fill(.white.opacity(0.09)))
                    }
                    Text("Choose what lives in your notch")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                HStack(spacing: 8) {
                    QuickActionButton(title: "Media Only", prominent: true) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            media = true; shelf = false; basket = false; clipboard = false
                            timer = false; tools = false; calendar = false; claude = false
                            shortcuts = false; system = false; mirror = false
                        }
                    }
                    QuickActionButton(title: "Enable All", prominent: false) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            media = true; shelf = true; clipboard = true; timer = true
                            tools = true; calendar = true; claude = true; shortcuts = true
                            system = true; mirror = true
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ModuleRow(icon: "music.note", color: .pink, title: "Media Player", subtitle: "Now playing, scrubber and controls", isOn: $media)
                    CardDivider()
                    ModuleRow(icon: "tray.full", color: .blue, title: "File Shelf", subtitle: "Drop files into the notch to hold", isOn: $shelf)
                    if shelf {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.indigo.gradient)
                                    .frame(width: 30, height: 30)
                                Image(systemName: "basket.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Floating Basket")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                                Text("Jiggle while dragging to summon")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            Spacer()
                            PremiumToggle(isOn: $basket)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .padding(.leading, 22)
                        .background(Color.white.opacity(0.03))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    CardDivider()
                    ModuleRow(icon: "doc.on.clipboard", color: .orange, title: "Clipboard Manager", subtitle: "History, favorites and OCR", isOn: $clipboard)
                    CardDivider()
                    ModuleRow(icon: "timer", color: .red, title: "Pomodoro Timer", subtitle: "Focus sessions and breaks", isOn: $timer)
                    CardDivider()
                    ModuleRow(icon: "calendar", color: .green, title: "Calendar & Meetings", subtitle: "Upcoming events, one-click join", isOn: $calendar)
                    CardDivider()
                    ModuleRow(icon: "sparkles", color: .purple, title: "Claude Code Monitor", subtitle: "Live session status and alerts", isOn: $claude)
                    CardDivider()
                    ModuleRow(icon: "bolt.fill", color: .yellow, title: "Shortcuts Launcher", subtitle: "Favorite macOS Shortcuts", isOn: $shortcuts)
                    CardDivider()
                    ModuleRow(icon: "cpu", color: .teal, title: "System Monitor", subtitle: "CPU, memory and stats", isOn: $system)
                    CardDivider()
                    ModuleRow(icon: "camera.fill", color: .cyan, title: "Camera Mirror", subtitle: "Webcam preview for calls", isOn: $mirror)
                    CardDivider()
                    ModuleRow(icon: "wrench.and.screwdriver", color: .gray, title: "Tools & High Alert", subtitle: "Stay awake and utilities", isOn: $tools)
                }
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.055))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                        }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .leading)))
    }

    private var mediaTab: some View {
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

    private var hudsTab: some View {
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

    private var generalTab: some View {
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
                    ExpandTargetsRow(
                        mainMac: $expandOnMainDisplay,
                        externalDisplays: $expandOnExternalDisplays,
                        externalDisplaysAvailable: externalDisplaysAvailable
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
                            }.buttonStyle(.plain)
                            Text("\(limit)")
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white)
                                .frame(minWidth: 34)
                            Button { limit = min(500, limit + 10) } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 28, height: 26)
                            }.buttonStyle(.plain)
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
                }
            }
            .padding(.top, 4)
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }
}
