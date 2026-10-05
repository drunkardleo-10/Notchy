import SwiftUI

struct ClaudeView: View {
    @ObservedObject var agents: AgentMonitor
    @State private var copied = false

    var body: some View {
        if agents.sessions.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 22))
                Text("No Claude Code sessions yet").font(.system(size: 12))
                Text("Add the hooks to ~/.claude/settings.json, then start a session.")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                copyButton
            }
            .foregroundStyle(.white.opacity(0.7)).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 5) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 5) { ForEach(agents.sessions) { SessionRow(session: $0) } }
                }
                HStack { Spacer(); copyButton }
            }
        }
    }

    private var copyButton: some View {
        Button {
            agents.copyHookConfig()
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
            Text(copied ? "Copied hook config" : "Copy hook config").font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 3).background(.white.opacity(0.14), in: Capsule())
        }.buttonStyle(.plain)
    }
}

private struct SessionRow: View {
    let session: AgentSession

    private var label: String {
        switch session.state {
        case .working: "Working"
        case .attention: session.message.isEmpty ? "Needs your input" : session.message
        case .done: "Finished"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                switch session.state {
                case .working: ProgressView().controlSize(.small).scaleEffect(0.7)
                case .attention: Image(systemName: "exclamationmark.bubble.fill").foregroundStyle(.orange)
                case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.project).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
            }
            Spacer()
            Text(session.updated, style: .relative).font(.system(size: 10)).foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}
