import Foundation

enum ClaudeStatusline {
    static let baseDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".notchy", isDirectory: true)
    static let scriptURL = baseDir.appendingPathComponent("claude-statusline.sh")
    static let nextURL = baseDir.appendingPathComponent("statusline-next")
    static let usageURL = baseDir.appendingPathComponent("usage/claude.json")
    private static let settingsURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")

    private static let script = """
    #!/bin/sh
    IN=$(cat)
    DIR="$HOME/.notchy/usage"
    mkdir -p "$DIR"
    printf '%s' "$IN" | /usr/bin/python3 -c '
    import json, sys, time
    try:
        d = json.load(sys.stdin)
    except Exception:
        d = {}
    r = d.get("rate_limits")
    if r:
        with open(sys.argv[1], "w") as f:
            json.dump({"rate_limits": r, "updated": time.time()}, f)
    ' "$DIR/claude.json"
    NEXT="$HOME/.notchy/statusline-next"
    if [ -s "$NEXT" ]; then
        printf '%s' "$IN" | /bin/sh -c "$(cat "$NEXT")"
    fi
    exit 0
    """

    static func install() {
        let fm = FileManager.default
        try? fm.createDirectory(at: usageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    static var isEnabled: Bool {
        guard let data = try? Data(contentsOf: settingsURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let line = object["statusLine"] as? [String: Any] else { return false }
        return (line["command"] as? String) == scriptURL.path
    }

    @discardableResult
    static func enable() -> Bool {
        install()
        let fm = FileManager.default
        guard let data = try? Data(contentsOf: settingsURL),
              var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        var line = object["statusLine"] as? [String: Any] ?? [:]
        if let current = line["command"] as? String, current != scriptURL.path {
            try? current.write(to: nextURL, atomically: true, encoding: .utf8)
        }
        let backup = settingsURL.appendingPathExtension("bak-notchy-statusline")
        if !fm.fileExists(atPath: backup.path) { try? data.write(to: backup) }
        line["type"] = "command"
        line["command"] = scriptURL.path
        object["statusLine"] = line
        guard let out = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else { return false }
        return (try? out.write(to: settingsURL, options: .atomic)) != nil
    }
}
