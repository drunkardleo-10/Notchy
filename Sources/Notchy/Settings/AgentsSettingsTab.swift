import SwiftUI

struct AgentsSettingsTab: View {
    @State private var detected: [AgentKind] = []
    @State private var scanning = true
    @State private var refreshToken = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                SettingsCard(title: "Detected Agents", subtitle: "Notchy shows their sessions in the notch") {
                    if detected.isEmpty {
                        Text(scanning ? "Looking for agents…" : "No coding agents found on this Mac")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 14)
                    }
                    ForEach(Array(detected.enumerated()), id: \.element.id) { index, kind in
                        if index > 0 { CardDivider() }
                        AgentSettingRow(kind: kind, refreshToken: refreshToken)
                    }
                }
                HStack {
                    Text("Hooks are added automatically when an agent is found. Codex also needs a one-time trust in /hooks.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.38))
                    Spacer(minLength: 12)
                    QuickActionButton(title: scanning ? "Scanning…" : "Scan Again", prominent: false) { scan() }
                        .disabled(scanning)
                }
                .padding(.horizontal, 14)
            }
            .padding(.top, 4)
        }
        .onAppear { scan() }
    }

    private func scan() {
        scanning = true
        Task {
            let found = await Task.detached { AgentScanner.installed() }.value
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                detected = found
                scanning = false
                refreshToken += 1
            }
        }
    }
}

private struct AgentSettingRow: View {
    let kind: AgentKind
    let refreshToken: Int

    @AppStorage private var enabled: Bool
    @State private var installed = false
    @State private var failed = false

    init(kind: AgentKind, refreshToken: Int) {
        self.kind = kind
        self.refreshToken = refreshToken
        _enabled = AppStorage(wrappedValue: true, AgentPrefs.key(kind.id))
    }

    private var integration: AgentIntegration? { AgentIntegration.forAgent(kind.id) }

    private var status: (text: String, color: Color) {
        guard let integration else { return ("Usage only, live status not supported yet", .white.opacity(0.42)) }
        if failed { return ("Couldn't add hooks", .orange) }
        if !installed { return ("Hooks missing", .orange) }
        return (integration.approvals ? "Live status and approvals" : "Live status", .green.opacity(0.85))
    }

    var body: some View {
        HStack(spacing: 12) {
            AgentGlyph(id: kind.id, size: 16)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.08)))
            VStack(alignment: .leading, spacing: 1) {
                Text(kind.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(enabled ? 0.92 : 0.5))
                Text(status.text)
                    .font(.system(size: 11.5))
                    .foregroundStyle(status.color)
            }
            Spacer()
            if integration != nil && !installed && enabled {
                QuickActionButton(title: failed ? "Retry" : "Install Hooks", prominent: true) { install() }
            }
            PremiumToggle(isOn: $enabled)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .onAppear(perform: check)
        .onChange(of: refreshToken) { _, _ in check() }
        .onChange(of: enabled) { _, on in AgentPrefs.setEnabled(kind.id, on) }
    }

    private func check() {
        installed = integration?.isInstalled() ?? false
    }

    private func install() {
        failed = !(integration?.install() ?? false)
        check()
    }
}
