import SwiftUI

private struct HUDLevelBar: View {
    let level: Float
    let height: CGFloat
    var hasGlow = false

    var body: some View {
        GeometryReader { geometry in
            Capsule()
                .fill(.white.opacity(0.25))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.white)
                        .frame(width: geometry.size.width * CGFloat(min(max(level, 0), 1)))
                        .shadow(color: .white.opacity(hasGlow ? 0.35 : 0), radius: hasGlow ? 8 : 0)
                }
        }
        .frame(height: height)
    }
}

private struct InlineHUDLevelReadout: View {
    let level: Float

    var body: some View {
        HStack(spacing: 6) {
            HUDLevelBar(level: level, height: 4, hasGlow: true)
                .frame(width: 40)
            Text("\(Int((level * 100).rounded()))")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
        }
    }
}

enum VolumeHUDStyle: CaseIterable, Identifiable {
    case inline
    case peek

    var rawValue: String {
        switch self {
        case .inline: "inline"
        case .peek: "peek"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "inline", "compact": self = .inline
        case "peek", "expanded": self = .peek
        default: return nil
        }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inline: "Inline"
        case .peek: "Peek"
        }
    }

    var icon: String {
        switch self {
        case .inline: "waveform"
        case .peek: "chevron.down"
        }
    }
}

enum HUDLayout {
    static let sideWidth: CGFloat = 95
    static let inlineVolumeLeadingWidth: CGFloat = LiveActivityLayout.sideWidth
    static let inlineVolumeTrailingWidth: CGFloat = 80
    static let inlineSymbolLeadingWidth: CGFloat = LiveActivityLayout.sideWidth
    static let inlineSymbolTrailingWidth: CGFloat = 64
    static let peekLeadingWidth: CGFloat = LiveActivityLayout.sideWidth
    static let peekTrailingWidth: CGFloat = LiveActivityLayout.sideWidth
    static let peekHeight: CGFloat = 68
    static let tallExtraHeight: CGFloat = 46

    static func volumeLeadingWidth(for style: VolumeHUDStyle) -> CGFloat {
        style == .peek ? peekLeadingWidth : inlineVolumeLeadingWidth
    }

    static func volumeTrailingWidth(for style: VolumeHUDStyle) -> CGFloat {
        style == .peek ? peekTrailingWidth : inlineVolumeTrailingWidth
    }

    static func size(for hud: HUDEvent, notch: CGSize, volumeStyle: VolumeHUDStyle = .inline) -> CGSize {
        switch hud.kind {
        case .volume, .brightness:
            if volumeStyle == .peek { return peekSize(notch: notch) }
            return NotchAccessoryLayout.size(
                notch: notch,
                leadingWidth: inlineVolumeLeadingWidth,
                trailingWidth: inlineVolumeTrailingWidth
            )
        case .lock, .capsLock:
            if volumeStyle == .peek { return peekSize(notch: notch) }
            return NotchAccessoryLayout.size(
                notch: notch,
                leadingWidth: inlineSymbolLeadingWidth,
                trailingWidth: inlineSymbolTrailingWidth
            )
        default:
            break
        }
        var h = notch.height
        switch hud.kind {
        case .airpods, .battery, .message: h += tallExtraHeight
        default: break
        }
        return CGSize(
            width: NotchAccessoryLayout.size(notch: notch, leadingWidth: sideWidth, trailingWidth: sideWidth).width,
            height: h
        )
    }

    static func peekSize(notch: CGSize) -> CGSize {
        let size = NotchAccessoryLayout.size(
            notch: notch,
            leadingWidth: peekLeadingWidth,
            trailingWidth: peekTrailingWidth
        )
        return CGSize(width: size.width, height: peekHeight)
    }
}

struct PeekHUDView<Content: View>: View {
    let notch: CGSize
    let leadingWidth: CGFloat
    let trailingWidth: CGFloat
    let height: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: 26)
                .padding(.bottom, 4)
        }
        .frame(
            width: NotchAccessoryLayout.size(
                notch: notch,
                leadingWidth: leadingWidth,
                trailingWidth: trailingWidth
            ).width,
            height: height
        )
    }
}

struct VolumeHUDView: View {
    let level: Float
    let muted: Bool
    let notch: CGSize
    var style: VolumeHUDStyle = .inline

    var body: some View {
        Group {
            if style == .peek {
                PeekHUDView(
                    notch: notch,
                    leadingWidth: HUDLayout.peekLeadingWidth,
                    trailingWidth: HUDLayout.peekTrailingWidth,
                    height: HUDLayout.peekHeight
                ) {
                    HStack(spacing: 14) {
                        Image(systemName: Self.icon(level, muted))
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 18, height: 26)
                        HUDLevelBar(level: muted ? 0 : level, height: 6, hasGlow: true)
                    }
                }
            } else {
                NotchAccessory(
                    notch: notch,
                    leadingWidth: HUDLayout.inlineVolumeLeadingWidth,
                    trailingWidth: HUDLayout.inlineVolumeTrailingWidth,
                    trailingAlignment: .leading,
                    trailingInset: 6
                ) {
                    Image(systemName: Self.icon(level, muted))
                        .font(.system(size: 13, weight: .semibold))
                } trailing: {
                    InlineHUDLevelReadout(level: muted ? 0 : level)
                }
            }
        }
        .foregroundStyle(.white)
        .animation(.easeOut(duration: 0.12), value: level)
    }

    private static func icon(_ level: Float, _ muted: Bool) -> String {
        if muted || level == 0 { return "speaker.slash.fill" }
        return level < 0.33 ? "speaker.wave.1.fill" : level < 0.66 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
    }
}

struct HUDView: View {
    let hud: HUDEvent
    let notch: CGSize
    var volumeStyle: VolumeHUDStyle = .inline

    var body: some View {
        VStack(spacing: 0) {
            switch hud.kind {
            case .volume:
                EmptyView()
            case .brightness(let level):
                let icon = level > 0.5 ? "sun.max.fill" : "sun.min.fill"
                if volumeStyle == .peek {
                    peekLevelRow(icon: icon, level: level)
                } else {
                    inlineLevelRow(icon: icon, level: level)
                }
            case .airpods(let name, let battery):
                tallRow(icon: Self.airpodsIcon(name), title: name, subtitle: battery.map { "Connected · \($0)" } ?? "Connected")
            case .battery(let percent, let state):
                tallRow(icon: Self.batteryIcon(percent, state), title: state.title, subtitle: "\(percent)%", tint: state.tint)
            case .message(let icon, let title, let subtitle):
                tallRow(icon: icon, title: title, subtitle: subtitle)
            case .lock(let unlocked):
                if volumeStyle == .peek {
                    PeekHUDView(
                        notch: notch,
                        leadingWidth: HUDLayout.peekLeadingWidth,
                        trailingWidth: HUDLayout.peekTrailingWidth,
                        height: HUDLayout.peekHeight
                    ) {
                        HStack(spacing: 10) {
                            Image(systemName: unlocked ? "lock.open.fill" : "lock.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 18, height: 26)
                            Text(unlocked ? "Unlocked" : "Locked")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer(minLength: 0)
                        }
                    }
                } else {
                    inlineSymbolRow(
                        icon: unlocked ? "lock.open.fill" : "lock.fill",
                        text: unlocked ? "Unlocked" : "Locked"
                    )
                }
            case .capsLock(let on):
                if volumeStyle == .peek {
                    PeekHUDView(
                        notch: notch,
                        leadingWidth: HUDLayout.peekLeadingWidth,
                        trailingWidth: HUDLayout.peekTrailingWidth,
                        height: HUDLayout.peekHeight
                    ) {
                        HStack(spacing: 10) {
                            Image(systemName: on ? "capslock.fill" : "capslock")
                                .font(.system(size: 16, weight: .semibold))
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 18, height: 26)
                            Text(on ? "Caps Lock On" : "Caps Lock Off")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer(minLength: 0)
                        }
                    }
                } else {
                    inlineSymbolRow(
                        icon: on ? "capslock.fill" : "capslock",
                        text: on ? "Caps On" : "Caps Off"
                    )
                }
            }
        }
        .foregroundStyle(.white)
    }

    private func inlineSymbolRow(icon: String, text: String) -> some View {
        NotchAccessory(
            notch: notch,
            leadingWidth: HUDLayout.inlineSymbolLeadingWidth,
            trailingWidth: HUDLayout.inlineSymbolTrailingWidth,
            leadingAlignment: .center,
            trailingAlignment: .leading,
            trailingInset: 4
        ) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
        } trailing: {
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
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

    private func inlineLevelRow(icon: String, level: Float) -> some View {
        NotchAccessory(
            notch: notch,
            leadingWidth: HUDLayout.inlineVolumeLeadingWidth,
            trailingWidth: HUDLayout.inlineVolumeTrailingWidth,
            trailingAlignment: .leading,
            trailingInset: 6
        ) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
        } trailing: {
            InlineHUDLevelReadout(level: level)
        }
        .animation(.easeOut(duration: 0.12), value: level)
    }

    private func peekLevelRow(icon: String, level: Float) -> some View {
        PeekHUDView(
            notch: notch,
            leadingWidth: HUDLayout.peekLeadingWidth,
            trailingWidth: HUDLayout.peekTrailingWidth,
            height: HUDLayout.peekHeight
        ) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 18, height: 26)
                HUDLevelBar(level: level, height: 6, hasGlow: true)
            }
            .animation(.easeOut(duration: 0.12), value: level)
        }
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
