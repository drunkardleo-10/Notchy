import Foundation

enum ClaudeHooks {
    static let baseDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".notchy", isDirectory: true)
    static let agentsDir = baseDir.appendingPathComponent("agents", isDirectory: true)
    static let requestsDir = baseDir.appendingPathComponent("requests", isDirectory: true)
    static let responsesDir = baseDir.appendingPathComponent("responses", isDirectory: true)
    static let heartbeatURL = baseDir.appendingPathComponent("alive")
    static let statusScriptURL = baseDir.appendingPathComponent("claude-hook.sh")
    static let permissionScriptURL = baseDir.appendingPathComponent("claude-permission.sh")
    private static let settingsURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    static let permissionTimeout = 600

    private static let statusScript = """
    #!/bin/sh
    DIR="$HOME/.notchy/agents"
    mkdir -p "$DIR"
    /usr/bin/python3 -c '
    import json, sys, os, time
    state, d = sys.argv[1], sys.argv[2]
    try:
        data = json.load(sys.stdin)
    except Exception:
        data = {}
    sid = str(data.get("session_id") or "unknown")
    path = os.path.join(d, sid + ".json")
    if state == "ended":
        try:
            os.remove(path)
        except OSError:
            pass
        sys.exit(0)
    try:
        with open(path) as f:
            prev = json.load(f)
    except Exception:
        prev = {}
    event = data.get("hook_event_name") or ""
    cwd = data.get("cwd") or prev.get("cwd") or ""
    tool = (data.get("tool_name") or "") if (state == "working" and event != "UserPromptSubmit") else ""
    out = {"id": sid, "cwd": cwd, "project": os.path.basename(cwd) or "Claude Code", "state": state, "tool": tool, "message": data.get("message") or "", "updated": time.time()}
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(out, f)
    os.rename(tmp, path)
    ' "$1" "$DIR"
    exit 0
    """

    private static let permissionScript = """
    #!/bin/sh
    exec /usr/bin/python3 -c '
    import json, sys, os, time, uuid
    base = os.path.expanduser("~/.notchy")
    alive = os.path.join(base, "alive")
    def stale(limit):
        try:
            return time.time() - os.path.getmtime(alive) > limit
        except OSError:
            return True
    if stale(5):
        sys.exit(0)
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    req_dir = os.path.join(base, "requests")
    res_dir = os.path.join(base, "responses")
    os.makedirs(req_dir, exist_ok=True)
    os.makedirs(res_dir, exist_ok=True)
    rid = uuid.uuid4().hex
    cwd = data.get("cwd") or ""
    req = {"id": rid, "pid": os.getpid(), "session": str(data.get("session_id") or ""), "project": os.path.basename(cwd) or "Claude Code", "cwd": cwd, "tool": data.get("tool_name") or "", "input": data.get("tool_input") or {}, "created": time.time()}
    path = os.path.join(req_dir, rid + ".json")
    with open(path + ".tmp", "w") as f:
        json.dump(req, f)
    os.rename(path + ".tmp", path)
    res_path = os.path.join(res_dir, rid + ".json")
    deadline = time.time() + \(permissionTimeout - 10)
    result = None
    while time.time() < deadline and not stale(10):
        if os.path.exists(res_path):
            try:
                with open(res_path) as f:
                    result = json.load(f)
            except Exception:
                result = None
            break
        time.sleep(0.15)
    for p in (path, res_path):
        try:
            os.remove(p)
        except OSError:
            pass
    behavior = (result or {}).get("behavior")
    if behavior not in ("allow", "deny"):
        sys.exit(0)
    decision = {"behavior": behavior}
    if behavior == "allow" and "updatedInput" in result:
        decision["updatedInput"] = result["updatedInput"]
    if behavior == "deny":
        decision["message"] = result.get("message") or "Denied from Notchy"
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": decision}}))
    '
    """

    static var eventNames: [String] { events.map(\.name) }

    private static var events: [(name: String, command: String, timeout: Int?)] {
        let status = statusScriptURL.path
        return [
            ("UserPromptSubmit", "\(status) working", nil),
            ("PreToolUse", "\(status) working", nil),
            ("Notification", "\(status) attention", nil),
            ("Stop", "\(status) done", nil),
            ("SessionEnd", "\(status) ended", nil),
            ("PermissionRequest", permissionScriptURL.path, permissionTimeout)
        ]
    }

    static func installScripts() {
        let fm = FileManager.default
        for dir in [agentsDir, requestsDir, responsesDir] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        for (script, url) in [(statusScript, statusScriptURL), (permissionScript, permissionScriptURL)] {
            try? script.write(to: url, atomically: true, encoding: .utf8)
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }

    static var isInstalled: Bool {
        guard let hooks = settings()?["hooks"] as? [String: Any] else { return false }
        return events.allSatisfy { contains(hooks[$0.name], command: $0.command) }
    }

    @discardableResult
    static func install() -> Bool {
        installScripts()
        guard var object = settings() else { return false }
        var hooks = object["hooks"] as? [String: Any] ?? [:]
        for event in events where !contains(hooks[event.name], command: event.command) {
            var groups = hooks[event.name] as? [Any] ?? []
            groups.append(entry(event.command, timeout: event.timeout))
            hooks[event.name] = groups
        }
        object["hooks"] = hooks
        let backup = settingsURL.appendingPathExtension("bak-notchy-hooks")
        if !FileManager.default.fileExists(atPath: backup.path), let original = try? Data(contentsOf: settingsURL) {
            try? original.write(to: backup)
        }
        guard let out = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else { return false }
        return (try? out.write(to: settingsURL, options: .atomic)) != nil
    }

    private static func settings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: settingsURL) else { return [:] }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func entry(_ command: String, timeout: Int?) -> [String: Any] {
        var hook: [String: Any] = ["type": "command", "command": command]
        if let timeout { hook["timeout"] = timeout }
        return ["hooks": [hook]]
    }

    private static func contains(_ groups: Any?, command: String) -> Bool {
        guard let groups = groups as? [[String: Any]] else { return false }
        return groups.contains { group in
            (group["hooks"] as? [[String: Any]])?.contains { ($0["command"] as? String) == command } ?? false
        }
    }
}
