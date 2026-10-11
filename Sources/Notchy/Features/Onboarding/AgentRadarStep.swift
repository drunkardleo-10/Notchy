import SwiftUI

struct AgentRadarStep: View {
    @ObservedObject var radar: AgentRadarModel

    private var isLive: Bool {
        if case .live = radar.link { return true }
        return false
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            RadarView(found: radar.found, scanning: radar.phase != .done, live: isLive)
                .frame(width: 128, height: 128)

            VStack(alignment: .leading, spacing: 10) {
                NotchyGuide(pose: guidePose, title: title, message: subtitle, cell: 2)
                FoundAgentsRow(found: radar.found)
                AgentLinkCard(radar: radar)
            }
        }
        .onAppear { radar.start() }
    }

    private var guidePose: NotchyPose {
        if isLive { return .cheer }
        return radar.phase == .done ? .idle : .scan
    }

    private var title: String {
        switch radar.phase {
        case .idle, .scanning: return "Let me look for your coding agents"
        case .done:
            switch radar.found.count {
            case 0: return "I didn't find any agents yet"
            case 1: return "I found 1 agent"
            default: return "I found \(radar.found.count) agents"
            }
        }
    }

    private var subtitle: String {
        switch radar.phase {
        case .idle, .scanning: return "Checking your apps and command line tools."
        case .done:
            return radar.found.isEmpty
                ? "I work with Claude Code, Codex, Cursor, Gemini and more. Install one anytime."
                : "I'll show what they're doing, how much usage is left, and when they need you."
        }
    }
}

private struct FoundAgentsRow: View {
    let found: [AgentKind]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(found) { kind in
                    HStack(spacing: 5) {
                        AgentGlyph(id: kind.id, size: 13)
                        Text(kind.name).font(.system(size: 11.5, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
        }
        .frame(height: found.isEmpty ? 0 : 24)
    }
}

private struct AgentLinkCard: View {
    @ObservedObject var radar: AgentRadarModel

    var body: some View {
        Group {
            switch radar.link {
            case .unavailable:
                EmptyView()
            case .disconnected:
                card {
                    AgentStack(kinds: radar.connectable)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connect \(radar.connectableNames)").font(.system(size: 12.5, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("One click adds Notchy's hooks to each agent. Backups are saved first.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer(minLength: 6)
                    OnboardingButton(title: "Connect") { radar.connect() }
                }
            case .waiting:
                card {
                    PulseDot()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Waiting for a session").font(.system(size: 12.5, weight: .semibold))
                        Text(radar.needsCodexTrust
                             ? "Run any prompt to see it here. In Codex, trust Notchy once in /hooks."
                             : "Run any prompt in one of your agents to see it here.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer(minLength: 6)
                    ClaudeSpark(spinning: true, size: 16)
                }
            case .live(let agent, let project):
                card {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.success)
                        .symbolEffect(.bounce, value: project)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(agent) is connected").font(.system(size: 12.5, weight: .semibold))
                        Text("Live session in \(project)")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer(minLength: 0)
                }
            case .failed(let agents):
                card {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.warning)
                    Text("Couldn't connect \(agents.joined(separator: ", "))")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                    OnboardingButton(title: "Retry", prominent: false) { radar.connect() }
                }
            }
        }
        .transition(.opacity.combined(with: .offset(y: 6)))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: radar.link)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 10, content: content)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.white.opacity(0.06)))
    }
}

private struct AgentStack: View {
    let kinds: [AgentKind]

    var body: some View {
        HStack(spacing: -5) {
            ForEach(kinds.prefix(4)) { kind in
                AgentGlyph(id: kind.id, size: 12)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color(white: 0.16)))
                    .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
            }
        }
    }
}
