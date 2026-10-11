import Foundation

enum AntigravityPlugin {
    private static let home = FileManager.default.homeDirectoryForCurrentUser
    private static let directories = [
        home.appendingPathComponent(".gemini/antigravity-cli/plugins/notchy", isDirectory: true),
        home.appendingPathComponent(".gemini/config/plugins/notchy", isDirectory: true)
    ]

    private static var hooks: [String: Any] {
        let start = HookEvent(name: "PreInvocation", command: AgentHookScript.command(agent: "antigravity", state: "working", reply: #"{"decision":"allow"}"#), timeout: 5)
        let tool = HookEvent(name: "PostToolUse", command: AgentHookScript.command(agent: "antigravity", state: "working", reply: "{}"), timeout: 5)
        let stop = HookEvent(name: "Stop", command: AgentHookScript.command(agent: "antigravity", state: "done", reply: "{}"), timeout: 5)
        return ["notchy": [
            "enabled": true,
            start.name: [HookConfigFile.hook(start)],
            tool.name: [["matcher": "*", "hooks": [HookConfigFile.hook(tool)]]],
            stop.name: [HookConfigFile.hook(stop)]
        ]]
    }

    private static let manifest: [String: Any] = [
        "name": "notchy",
        "displayName": "Notchy",
        "description": "Shows Antigravity session status in the Notchy notch.",
        "version": "1.0.0"
    ]

    static var isInstalled: Bool {
        directories.contains { dir in
            guard let data = try? Data(contentsOf: dir.appendingPathComponent("hooks.json")),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
            return NSDictionary(dictionary: object).isEqual(to: hooks)
        }
    }

    @discardableResult
    static func install() -> Bool {
        AgentHookScript.install()
        var wrote = false
        for dir in directories {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for (name, object) in [("hooks.json", hooks), ("plugin.json", manifest)] {
                guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else { continue }
                if (try? data.write(to: dir.appendingPathComponent(name), options: .atomic)) != nil, name == "hooks.json" { wrote = true }
            }
        }
        return wrote
    }
}
