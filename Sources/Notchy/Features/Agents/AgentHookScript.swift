import Foundation

enum AgentHookScript {
    static let url = ClaudeHooks.baseDir.appendingPathComponent("agent-hook.sh")

    private static let script = """
    #!/bin/sh
    DIR="$HOME/.notchy/agents"
    mkdir -p "$DIR"
    /usr/bin/python3 -c '
    import json, sys, os, time
    agent, state, d = sys.argv[1], sys.argv[2], sys.argv[3]
    names = {"codex": "Codex", "devin": "Devin", "opencode": "OpenCode", "antigravity": "Antigravity"}
    try:
        data = json.loads(sys.stdin.read() or "{}")
    except Exception:
        data = {}
    if not isinstance(data, dict):
        data = {}
    def pick(*keys):
        for key in keys:
            value = data.get(key)
            if isinstance(value, (str, int)) and str(value):
                return str(value)
        return ""
    sid = pick("session_id", "sessionId", "conversation_id", "conversationId", "thread_id", "threadId") or "unknown"
    safe = "".join(ch for ch in sid if ch.isalnum() or ch in "-_") or "unknown"
    key = agent + "-" + safe
    path = os.path.join(d, key + ".json")
    try:
        with open(path) as f:
            prev = json.load(f)
    except Exception:
        prev = {}
    if state == "ended":
        if prev.get("state") != "done":
            try:
                os.remove(path)
            except OSError:
                pass
        sys.exit(0)
    roots = data.get("workspacePaths") or data.get("workspace_roots") or []
    root = str(roots[0]) if isinstance(roots, list) and roots else ""
    cwd = pick("cwd", "workspace", "directory") or root or prev.get("cwd") or os.environ.get("PWD", "")
    tool = ""
    if state == "working":
        tool = pick("tool_name", "toolName")
        call = data.get("toolCall") or data.get("tool")
        if not tool and isinstance(call, dict):
            tool = str(call.get("name") or "")
    out = {"id": key, "agent": agent, "cwd": cwd, "project": os.path.basename(cwd.rstrip("/")) or names.get(agent, agent), "state": state, "tool": tool, "message": pick("message"), "updated": time.time()}
    with open(path + ".tmp", "w") as f:
        json.dump(out, f)
    os.rename(path + ".tmp", path)
    ' "$1" "$2" "$DIR" 2>/dev/null
    [ -n "$3" ] && echo "$3"
    exit 0
    """

    static func install() {
        try? FileManager.default.createDirectory(at: ClaudeHooks.agentsDir, withIntermediateDirectories: true)
        try? script.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    static func command(agent: String, state: String, reply: String? = nil) -> String {
        var parts = ["'\(url.path)'", agent, state]
        if let reply { parts.append("'\(reply)'") }
        return parts.joined(separator: " ")
    }
}
