import SwiftUI

enum HUDLayout {
    static let sideWidth: CGFloat = 95
    static let tallExtraHeight: CGFloat = 46

    static func size(for hud: HUDEvent, notch: CGSize) -> CGSize {
        var h = notch.height
        switch hud.kind {
        case .airpods, .battery, .message: h += tallExtraHeight
        default: break
        }
        return CGSize(width: notch.width + sideWidth * 2, height: h)
    }
}

struct HUDView: View {
    let hud: HUDEvent
    let notch: CGSize

    var body: some View {
        VStack(spacing: 0) {
            switch hud.kind {
            case .volume(let level, let muted):
                levelRow(icon: Self.volumeIcon(level, muted), level: muted ? 0 : level)
            case .brightness(let level):
                levelRow(icon: level > 0.5 ? "sun.max.fill" : "sun.min.fill", level: level)
            case .airpods(let name, let battery):
                tallRow(icon: Self.airpodsIcon(name), title: name, subtitle: battery.map { "Connected · \($0)" } ?? "Connected")
            case .battery(let percent, let state):
                tallRow(icon: Self.batteryIcon(percent, state), title: state.title, subtitle: "\(percent)%", tint: state.tint)
            case .message(let icon, let title, let subtitle):
                tallRow(icon: icon, title: title, subtitle: subtitle)
            case .lock(let unlocked):
                symbolRow(icon: unlocked ? "lock.open.fill" : "lock.fill", text: unlocked ? "Unlocked" : "Locked")
            case .capsLock(let on):
                symbolRow(icon: on ? "capslock.fill" : "capslock", text: on ? "Caps On" : "Caps Off")
            }
        }
        .foregroundStyle(.white)
    }

    private func symbolRow(icon: String, text: String, tint: Color = .white) -> some View {
        HStack(spacing: 0) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: HUDLayout.sideWidth, alignment: .trailing).padding(.trailing, 4)
            Spacer().frame(width: notch.width)
            Text(text).font(.system(size: 11, weight: .medium)).lineLimit(1)
                .frame(width: HUDLayout.sideWidth, alignment: .leading).padding(.leading, 6)
        }
        .frame(height: notch.height)
    }

    private func tallRow(icon: String, title: String, subtitle: String, tint: Color = .white) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: notch.height)
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)
            .frame(height: HUDLayout.tallExtraHeight)
        }
    }

    private func levelRow(icon: String, level: Float) -> some View {
        HStack(spacing: 0) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .frame(width: HUDLayout.sideWidth, alignment: .trailing).padding(.trailing, 4)
            Spacer().frame(width: notch.width)
            HStack(spacing: 6) {
                Capsule().fill(.white.opacity(0.25)).frame(width: 40, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(.white).frame(width: 40 * CGFloat(min(max(level, 0), 1)), height: 4)
                    }
                Text("\(Int((level * 100).rounded()))").font(.system(size: 11, weight: .medium).monospacedDigit())
            }
            .frame(width: HUDLayout.sideWidth, alignment: .leading).padding(.leading, 6)
        }
        .frame(height: notch.height)
        .animation(.easeOut(duration: 0.12), value: level)
    }

    private static func volumeIcon(_ level: Float, _ muted: Bool) -> String {
        if muted || level == 0 { return "speaker.slash.fill" }
        return level < 0.33 ? "speaker.wave.1.fill" : level < 0.66 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
    }

    private static func airpodsIcon(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("max") { return "airpodsmax" }
        if n.contains("pro") { return "airpodspro" }
        if n.contains("airpods") { return "airpods" }
        return "headphones"
    }

    private static func batteryIcon(_ percent: Int, _ state: BatteryState) -> String {
        if state == .charging || state == .full { return "battery.100percent.bolt" }
        switch percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}

extension BatteryState {
    var title: String {
        switch self {
        case .charging: "Charging"
        case .onBattery: "On battery"
        case .low: "Low battery"
        case .full: "Fully charged"
        }
    }

    var tint: Color {
        switch self {
        case .charging, .full: .green
        case .onBattery: .white
        case .low: .red
        }
    }
}
