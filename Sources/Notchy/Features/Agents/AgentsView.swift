import SwiftUI

struct AgentsView: View {
    @ObservedObject var agents: AgentMonitor
    @ObservedObject private var inventory: AgentInventory
    @State private var shown: String?

    private static let maxIconSize: CGFloat = 64
    private static let iconGap: CGFloat = 12
    private static let compactScale: CGFloat = 0.62
    private static let detailGap: CGFloat = 8

    init(agents: AgentMonitor) {
        self.agents = agents
        self.inventory = agents.inventory
    }

    private var shownKind: AgentKind? {
        inventory.installed.first { $0.id == shown }
    }

    var body: some View {
        Group {
            if inventory.installed.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 22))
                    Text("No AI agents found").font(.system(size: 12))
                }
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { proxy in
                    let size = iconSize(for: proxy.size.width)
                    let open = shownKind != nil
                    let idleOffset = max(0, (proxy.size.height - size) / 2)
                    ZStack(alignment: .top) {
                        iconRow(size: size, width: proxy.size.width)
                            .scaleEffect(open ? Self.compactScale : 1, anchor: .top)
                            .offset(y: open ? 0 : idleOffset)

                        if let kind = shownKind {
                            AgentDetailView(kind: kind, usage: inventory.usage[kind.id], agents: agents)
                                .id(kind.id)
                                .padding(.horizontal, 12)
                                .frame(width: proxy.size.width, alignment: .topLeading)
                                .offset(y: size * Self.compactScale + Self.detailGap)
                                .transition(.opacity.combined(with: .offset(y: 8)))
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    .clipped()
                    .animation(.spring(response: 0.4, dampingFraction: 0.86), value: open)
                    .animation(.easeOut(duration: 0.2), value: shown)
                }
            }
        }
        .onAppear { inventory.refresh() }
    }

    private func iconSize(for width: CGFloat) -> CGFloat {
        let count = CGFloat(max(inventory.installed.count, 1))
        return min(Self.maxIconSize, (width - Self.iconGap * (count - 1)) / count)
    }

    private func iconRow(size: CGFloat, width: CGFloat) -> some View {
        HStack(spacing: Self.iconGap) {
            ForEach(inventory.installed) { kind in
                AgentIconButton(
                    kind: kind,
                    usage: inventory.usage[kind.id],
                    size: size,
                    highlighted: kind.id == shown,
                    dimmed: shown != nil && kind.id != shown,
                    activity: kind.id == "claude" ? agents.sessions.first?.state : nil
                )
                .onTapGesture { shown = shown == kind.id ? nil : kind.id }
            }
        }
        .frame(width: width, height: size)
    }
}

private struct AgentIconButton: View {
    let kind: AgentKind
    let usage: AgentUsage?
    let size: CGFloat
    let highlighted: Bool
    let dimmed: Bool
    let activity: AgentSession.State?

    private var inner: Double? {
        guard let windows = usage?.windows, windows.count > 1 else { return nil }
        return windows.first?.leftFraction()
    }

    private var outer: Double? {
        usage?.windows.last?.leftFraction()
    }

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(highlighted ? 0.1 : 0.04))
            UsageRing(outer: outer, inner: inner, size: size)
            AgentMark(kind: kind, size: size * 0.5)
        }
        .overlay(alignment: .topTrailing) {
            if let activity { activityDot(activity) }
        }
        .frame(width: size, height: size)
        .opacity(dimmed ? 0.45 : 1)
        .contentShape(Circle())
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: highlighted)
        .animation(.easeOut(duration: 0.2), value: dimmed)
    }

    private func activityDot(_ state: AgentSession.State) -> some View {
        Circle()
            .fill(state == .attention ? Color.orange : state == .working ? Color.blue : Color.green)
            .frame(width: 9, height: 9)
            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
    }
}

private struct AgentDetailView: View {
    let kind: AgentKind
    let usage: AgentUsage?
    @ObservedObject var agents: AgentMonitor
    @State private var limitsEnabled = ClaudeStatusline.isEnabled
    @State private var hooksInstalled = ClaudeHooks.isInstalled

    private var sessionSummary: (text: String, color: Color)? {
        guard kind.id == "claude", !agents.sessions.isEmpty else { return nil }
        let working = agents.sessions.filter { $0.state == .working }.count
        if let waiting = agents.sessions.first(where: { $0.state == .attention }) {
            return (waiting.message.isEmpty ? "Needs your input" : waiting.message, .orange)
        }
        if working > 0 { return ("\(working) working", .blue) }
        return ("\(agents.sessions.count) idle", .white.opacity(0.45))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(kind.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let summary = sessionSummary {
                    Text(summary.text)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(summary.color)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else if let plan = usage?.plan {
                    Text(plan)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }
            .frame(height: 16)

            if let windows = usage?.windows, !windows.isEmpty {
                ForEach(windows) { UsageBarRow(window: $0) }
            } else {
                emptyState
            }

            if kind.id == "claude" && !hooksInstalled {
                HStack(spacing: 8) {
                    Text("Approve permissions from the notch")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                    pill("Install hooks") { hooksInstalled = ClaudeHooks.install() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var emptyState: some View {
        if kind.id == "claude" {
            VStack(alignment: .leading, spacing: 6) {
                Text(limitsEnabled ? "Limits show after your next Claude message" : "Limits need a one-time setup")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                HStack(spacing: 6) {
                    if !limitsEnabled {
                        pill("Enable limits") { limitsEnabled = ClaudeStatusline.enable() }
                    }
                }
            }
        } else {
            Text("No usage limits reported")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
        }
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(.white.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct UsageBarRow: View {
    let window: UsageWindow

    private static func remaining(until date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        let days = seconds / 86_400, hours = seconds % 86_400 / 3_600, minutes = seconds % 3_600 / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(max(1, minutes))m"
    }

    var body: some View {
        let left = window.leftFraction()
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(window.label).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text("\(Int((left * 100).rounded()))% left").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                Spacer(minLength: 8)
                if let reset = window.resetsAt, reset > Date() {
                    Text("Resets in \(Self.remaining(until: reset))").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45)).lineLimit(1).fixedSize()
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(UsageTone.color(left: left))
                        .frame(width: max(4, proxy.size.width * left))
                }
            }
            .frame(height: 4)
        }
    }
}

private struct AgentMark: View {
    let kind: AgentKind
    let size: CGFloat

    private static let cache = NSCache<NSString, NSImage>()

    private var appIcon: NSImage? {
        guard let path = kind.appPath else { return nil }
        if let cached = Self.cache.object(forKey: path as NSString) { return cached }
        let icon = Self.bundleIcon(at: path) ?? NSWorkspace.shared.icon(forFile: path)
        Self.cache.setObject(icon, forKey: path as NSString)
        return icon
    }

    private static func bundleIcon(at path: String) -> NSImage? {
        guard let bundle = Bundle(path: path),
              var name = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String else { return nil }
        if (name as NSString).pathExtension.isEmpty { name += ".icns" }
        let url = bundle.resourceURL?.appendingPathComponent(name)
        return url.flatMap { NSImage(contentsOf: $0) }
    }

    var body: some View {
        if let appIcon {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: size * 1.25, height: size * 1.25)
        } else {
            AgentGlyph(id: kind.id, size: size)
        }
    }
}
