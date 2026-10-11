import Foundation

enum AgentPrefs {
    static func key(_ id: String) -> String { "agentEnabled.\(id)" }

    static func isEnabled(_ id: String) -> Bool {
        UserDefaults.standard.object(forKey: key(id)) as? Bool ?? true
    }

    static let disabledDir = ClaudeHooks.baseDir.appendingPathComponent("disabled", isDirectory: true)

    static func setEnabled(_ id: String, _ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: key(id))
        let flag = disabledDir.appendingPathComponent(id)
        if enabled {
            try? FileManager.default.removeItem(at: flag)
        } else {
            try? FileManager.default.createDirectory(at: disabledDir, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: flag.path, contents: nil)
        }
    }
}
