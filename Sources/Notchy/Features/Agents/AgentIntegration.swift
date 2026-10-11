import Foundation

struct AgentIntegration {
    let caption: String
    var approvals = false
    let isInstalled: () -> Bool
    let install: () -> Bool

    static func forAgent(_ id: String) -> AgentIntegration? {
        switch id {
        case "claude":
            AgentIntegration(caption: "Approve permissions from the notch", approvals: true, isInstalled: { ClaudeHooks.isInstalled }, install: { ClaudeHooks.install() })
        case "codex":
            hookFile(codex)
        case "devin":
            hookFile(devin)
        case "opencode":
            AgentIntegration(caption: statusCaption, isInstalled: { OpenCodePlugin.isInstalled }, install: { OpenCodePlugin.install() })
        case "antigravity":
            AgentIntegration(caption: statusCaption, isInstalled: { AntigravityPlugin.isInstalled }, install: { AntigravityPlugin.install() })
        default:
            nil
        }
    }

    static func autoInstall(_ kinds: [AgentKind]) {
        for kind in kinds where AgentPrefs.isEnabled(kind.id) {
            let key = "agentHooksAutoInstalled.\(kind.id)"
            guard !UserDefaults.standard.bool(forKey: key), let integration = forAgent(kind.id) else { continue }
            if integration.isInstalled() || integration.install() {
                UserDefaults.standard.set(true, forKey: key)
            }
        }
    }

    private static let statusCaption = "Show sessions in the notch"

    private static func hookFile(_ file: HookConfigFile) -> AgentIntegration {
        AgentIntegration(caption: statusCaption, isInstalled: { file.isInstalled }, install: {
            AgentHookScript.install()
            return file.install()
        })
    }

    private static func claudeStyleEvents(agent: String) -> [HookEvent] {
        let run = { (state: String) in AgentHookScript.command(agent: agent, state: state) }
        return [
            HookEvent(name: "UserPromptSubmit", command: run("working"), timeout: 5),
            HookEvent(name: "PreToolUse", command: run("working"), timeout: 5),
            HookEvent(name: "PostToolUse", command: run("working"), timeout: 5),
            HookEvent(name: "PermissionRequest", command: run("attention"), timeout: 5),
            HookEvent(name: "Stop", command: run("done"), timeout: 5),
            HookEvent(name: "SessionEnd", command: run("ended"), timeout: 5)
        ]
    }

    private static let home = FileManager.default.homeDirectoryForCurrentUser

    private static var codex: HookConfigFile {
        HookConfigFile(url: home.appendingPathComponent(".codex/hooks.json"), events: claudeStyleEvents(agent: "codex"))
    }

    private static var devin: HookConfigFile {
        HookConfigFile(url: home.appendingPathComponent(".config/devin/config.json"), events: claudeStyleEvents(agent: "devin"))
    }
}
