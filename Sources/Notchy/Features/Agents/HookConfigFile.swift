import Foundation

struct HookEvent {
    let name: String
    let command: String
    var timeout: Int? = nil
    var matcher: String? = nil
}

struct HookConfigFile {
    let url: URL
    let events: [HookEvent]

    var isInstalled: Bool {
        guard let hooks = read()?["hooks"] as? [String: Any] else { return false }
        return events.allSatisfy { Self.contains(hooks[$0.name], command: $0.command) }
    }

    @discardableResult
    func install() -> Bool {
        guard var object = read() else { return false }
        var hooks = object["hooks"] as? [String: Any] ?? [:]
        for event in events where !Self.contains(hooks[event.name], command: event.command) {
            var groups = hooks[event.name] as? [Any] ?? []
            groups.append(Self.entry(event))
            hooks[event.name] = groups
        }
        object["hooks"] = hooks
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let backup = url.appendingPathExtension("bak-notchy-hooks")
        if !fm.fileExists(atPath: backup.path), let original = try? Data(contentsOf: url) {
            try? original.write(to: backup)
        }
        guard let out = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else { return false }
        return (try? out.write(to: url, options: .atomic)) != nil
    }

    private func read() -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    static func hook(_ event: HookEvent) -> [String: Any] {
        var hook: [String: Any] = ["type": "command", "command": event.command]
        if let timeout = event.timeout { hook["timeout"] = timeout }
        return hook
    }

    private static func entry(_ event: HookEvent) -> [String: Any] {
        var group: [String: Any] = ["hooks": [hook(event)]]
        if let matcher = event.matcher { group["matcher"] = matcher }
        return group
    }

    private static func contains(_ groups: Any?, command: String) -> Bool {
        guard let groups = groups as? [[String: Any]] else { return false }
        return groups.contains { group in
            (group["hooks"] as? [[String: Any]])?.contains { ($0["command"] as? String) == command } ?? false
        }
    }
}
