import AppKit

struct AgentSession: Identifiable, Equatable {
    enum State: String { case working, attention, done }
    let id: String
    let project: String
    let state: State
    let message: String
    let updated: Date
}

@MainActor
final class AgentMonitor: ObservableObject {
    @Published private(set) var sessions: [AgentSession] = []
    var onTransition: ((AgentSession) -> Void)?
    let inventory = AgentInventory()

    static let baseDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".notchy", isDirectory: true)
    static let agentsDir = baseDir.appendingPathComponent("agents", isDirectory: true)
    static let scriptURL = baseDir.appendingPathComponent("claude-hook.sh")

    private var timer: Timer?
    private var lastStates: [String: AgentSession.State] = [:]
    private var firstScan = true

    private static let script = """
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
    else:
        cwd = data.get("cwd") or ""
        with open(path, "w") as f:
            json.dump({"id": sid, "cwd": cwd, "project": os.path.basename(cwd) or "Claude Code", "state": state, "message": data.get("message") or "", "updated": time.time()}, f)
    ' "$1" "$DIR"
    exit 0
    """

    static var hookConfig: String {
        let cmd = scriptURL.path
        func entry(_ state: String) -> String {
            "[{\"hooks\": [{\"type\": \"command\", \"command\": \"\(cmd) \(state)\"}]}]"
        }
        return """
        {
          "hooks": {
            "UserPromptSubmit": \(entry("working")),
            "PreToolUse": \(entry("working")),
            "Notification": \(entry("attention")),
            "Stop": \(entry("done")),
            "SessionEnd": \(entry("ended"))
          }
        }
        """
    }

    init() {
        installScript()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    private func installScript() {
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.agentsDir, withIntermediateDirectories: true)
        try? Self.script.write(to: Self.scriptURL, atomically: true, encoding: .utf8)
        ClaudeStatusline.install()
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: Self.scriptURL.path)
    }

    func copyHookConfig() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.hookConfig, forType: .string)
    }

    private func poll() {
        guard Pref.bool(Pref.claude) else { return }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: Self.agentsDir, includingPropertiesForKeys: nil) else { return }
        var found: [AgentSession] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = obj["id"] as? String, let raw = obj["state"] as? String,
                  let state = AgentSession.State(rawValue: raw) else { continue }
            let updated = Date(timeIntervalSince1970: obj["updated"] as? Double ?? 0)
            if Date().timeIntervalSince(updated) > 3 * 3600 { try? fm.removeItem(at: file); continue }
            found.append(AgentSession(id: id, project: obj["project"] as? String ?? "Claude Code", state: state,
                                      message: obj["message"] as? String ?? "", updated: updated))
        }
        found.sort { $0.updated > $1.updated }
        if found != sessions { sessions = found }

        for s in found where lastStates[s.id] != s.state {
            if !firstScan, s.state != .working { onTransition?(s) }
            lastStates[s.id] = s.state
        }
        lastStates = lastStates.filter { key, _ in found.contains { $0.id == key } }
        firstScan = false
    }
}
