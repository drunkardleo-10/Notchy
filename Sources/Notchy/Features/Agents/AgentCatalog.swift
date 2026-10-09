import AppKit

struct AgentKind: Identifiable, Hashable {
    let id: String
    let name: String
    let binaries: [String]
    let apps: [String]
    var appPath: String? = nil
}

enum AgentCatalog {
    static let all: [AgentKind] = [
        AgentKind(id: "codex", name: "Codex", binaries: ["codex"], apps: ["Codex"]),
        AgentKind(id: "claude", name: "Claude", binaries: ["claude"], apps: ["Claude"]),
        AgentKind(id: "cursor", name: "Cursor", binaries: ["cursor-agent", "cursor"], apps: ["Cursor"]),
        AgentKind(id: "antigravity", name: "Antigravity", binaries: ["antigravity"], apps: ["Antigravity", "Antigravity IDE"]),
        AgentKind(id: "gemini", name: "Gemini", binaries: ["gemini"], apps: []),
        AgentKind(id: "grok", name: "Grok", binaries: ["grok"], apps: ["Grok"]),
        AgentKind(id: "droid", name: "Droid", binaries: ["droid"], apps: []),
        AgentKind(id: "opencode", name: "OpenCode", binaries: ["opencode"], apps: ["OpenCode"]),
        AgentKind(id: "pi", name: "Pi", binaries: ["pi"], apps: []),
        AgentKind(id: "devin", name: "Devin", binaries: ["devin"], apps: ["Devin"])
    ]
}

enum AgentScanner {
    private static let binaryDirectories: [String] = {
        let fixed = [
            "~/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "~/.bun/bin", "~/.cargo/bin",
            "~/.npm-global/bin", "~/.opencode/bin", "~/.factory/bin", "~/.volta/bin"
        ]
        let path = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        return fixed + path
    }()

    static func installed() -> [AgentKind] {
        AgentCatalog.all.compactMap(resolve)
    }

    private static func expand(_ path: String) -> String {
        path.hasPrefix("~") ? NSHomeDirectory() + path.dropFirst() : path
    }

    private static func resolve(_ kind: AgentKind) -> AgentKind? {
        let fm = FileManager.default
        var found = kind
        for app in kind.apps {
            for root in ["/Applications", NSHomeDirectory() + "/Applications"] {
                let path = "\(root)/\(app).app"
                if fm.fileExists(atPath: path) {
                    found.appPath = path
                    return found
                }
            }
        }
        for directory in binaryDirectories {
            for binary in kind.binaries where fm.isExecutableFile(atPath: expand(directory) + "/" + binary) { return found }
        }
        return nil
    }
}
