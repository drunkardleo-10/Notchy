import SwiftUI
import ServiceManagement

struct ModuleRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.gradient)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 4)
    }
}

struct SettingsView: View {
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

    @AppStorage(Pref.volumeHUD) private var volumeHUD = true
    @AppStorage(Pref.brightnessHUD) private var brightnessHUD = true
    @AppStorage(Pref.airpodsHUD) private var airpodsHUD = true
    @AppStorage(Pref.batteryHUD) private var batteryHUD = true
    @AppStorage(Pref.lockHUD) private var lockHUD = true
    @AppStorage(Pref.capsLockHUD) private var capsLockHUD = true

    @AppStorage(Pref.hoverOpen) private var hoverOpen = true
    @AppStorage(Pref.hapticFeedback) private var haptics = true
    @AppStorage(Pref.islandMode) private var island = false
    @AppStorage(Pref.clipboardLimit) private var limit = 50
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        TabView {
            modulesTab
                .tabItem { Label("Modules", systemImage: "square.grid.2x2") }
            mediaTab
                .tabItem { Label("Media", systemImage: "music.note") }
            hudsTab
                .tabItem { Label("HUDs", systemImage: "slider.horizontal.3") }
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 520, height: 520)
    }

    private var modulesTab: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notch Modules")
                        .font(.system(size: 14, weight: .bold))
                    Text("Enable features to display in the notch")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Media Only") {
                    media = true
                    shelf = false
                    basket = false
                    clipboard = false
                    timer = false
                    tools = false
                    calendar = false
                    claude = false
                    shortcuts = false
                    system = false
                    mirror = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Enable All") {
                    media = true
                    shelf = true
                    basket = true
                    clipboard = true
                    timer = true
                    tools = true
                    calendar = true
                    claude = true
                    shortcuts = true
                    system = true
                    mirror = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(spacing: 6) {
                    ModuleRow(icon: "music.note", color: .pink, title: "Media Player",
                              subtitle: "Now playing, scrubber and playback controls", isOn: $media)
                    Divider().padding(.leading, 44)

                    ModuleRow(icon: "tray.full", color: .blue, title: "File Shelf",
                              subtitle: "Drag & drop files into the notch for temporary holding", isOn: $shelf)
                    if shelf {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.indigo.gradient)
                                .frame(width: 26, height: 26)
                                .overlay { Image(systemName: "basket.fill").font(.system(size: 12)).foregroundStyle(.white) }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Floating Basket").font(.system(size: 12, weight: .medium))
                                Text("Jiggle while dragging to summon a floating file basket").font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $basket).labelsHidden().toggleStyle(.switch)
                        }
                        .padding(.leading, 24)
                        .padding(.vertical, 2)
                    }
                    Divider().padding(.leading, 44)

                    ModuleRow(icon: "doc.on.clipboard", color: .orange, title: "Clipboard Manager",
                              subtitle: "Searchable history, favorites and OCR text extraction", isOn: $clipboard)
                    Divider().padding(.leading, 44)

                    ModuleRow(icon: "timer", color: .red, title: "Pomodoro Timer",
                              subtitle: "Focus sessions and interval break tracking", isOn: $timer)
                    Divider().padding(.leading, 44)

                    ModuleRow(icon: "calendar", color: .green, title: "Calendar & Meetings",
                              subtitle: "Upcoming calendar events and one-click meeting joins", isOn: $calendar)
                    Divider().padding(.leading, 44)

                    ModuleRow(icon: "sparkles", color: .purple, title: "Claude Code Monitor",
                              subtitle: "Live session status and notification alerts for Claude Code", isOn: $claude)
                    Divider().padding(.leading, 44)

                    ModuleRow(icon: "bolt.fill", color: .yellow, title: "Shortcuts Launcher",
                              subtitle: "Quick access to your favorite macOS Shortcuts", isOn: $shortcuts)
                    Divider().padding(.leading, 44)

                    ModuleRow(icon: "cpu", color: .teal, title: "System Monitor",
                              subtitle: "Live CPU usage, memory and system statistics", isOn: $system)
                    Divider().padding(.leading, 44)

                    ModuleRow(icon: "camera.fill", color: .cyan, title: "Camera Mirror",
                              subtitle: "Instant webcam mirror preview for video calls", isOn: $mirror)
                    Divider().padding(.leading, 44)

                    ModuleRow(icon: "wrench.and.screwdriver", color: .gray, title: "Tools & High Alert",
                              subtitle: "Keep your Mac awake and quick utility tools", isOn: $tools)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
    }

    private var mediaTab: some View {
        Form {
            Section("Notch Integration") {
                Toggle("Live activity in the collapsed notch", isOn: $liveActivity)
            }
            Section("Browser Sources") {
                Toggle("Detect browser media (YouTube, SoundCloud…)", isOn: $browserMedia)
                Text("For track details and play/pause from Chrome, Brave, Arc or Edge, enable View → Developer → Allow JavaScript from Apple Events (Safari: Develop menu).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    private var hudsTab: some View {
        Form {
            Section("Audio & Display") {
                Toggle("Volume HUD", isOn: $volumeHUD)
                Toggle("Brightness HUD", isOn: $brightnessHUD)
                Toggle("AirPods / Bluetooth audio HUD", isOn: $airpodsHUD)
            }
            Section("System Status") {
                Toggle("Battery HUD (plug in, low, full)", isOn: $batteryHUD)
                Toggle("Lock / unlock animation", isOn: $lockHUD)
                Toggle("Caps Lock HUD", isOn: $capsLockHUD)
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    private var generalTab: some View {
        Form {
            Section("Notch Behavior") {
                Toggle("Open on hover", isOn: $hoverOpen)
                Toggle("Haptic feedback", isOn: $haptics)
                Toggle("Dynamic Island style (ignore hardware notch)", isOn: $island)
            }
            Section("Clipboard Settings") {
                Stepper("History size: \(limit)", value: $limit, in: 10...500, step: 10)
                Text("Password managers and concealed copies are never recorded.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}
