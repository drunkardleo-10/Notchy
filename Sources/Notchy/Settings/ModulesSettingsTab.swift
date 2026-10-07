import SwiftUI

struct ModulesSettingsTab: View {
    @Binding var media: Bool
    @Binding var shelf: Bool
    @Binding var basket: Bool
    @Binding var clipboard: Bool
    @Binding var timer: Bool
    @Binding var tools: Bool
    @Binding var calendar: Bool
    @Binding var claude: Bool
    @Binding var system: Bool
    @Binding var shortcuts: Bool
    @Binding var mirror: Bool

    private var enabledCount: Int {
        [media, shelf, clipboard, timer, calendar, claude, shortcuts, system, mirror, tools].filter { $0 }.count
    }

    var body: some View {
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                                basket.toggle()
                            }
                        }
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
}
