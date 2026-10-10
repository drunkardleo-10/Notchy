import AppKit

struct AgentSession: Identifiable, Equatable {
    enum State: String { case working, attention, done }
    let id: String
    let project: String
    let state: State
    let tool: String
    let message: String
    let updated: Date
}

@MainActor
final class AgentMonitor: ObservableObject {
    @Published private(set) var sessions: [AgentSession] = []
    var onTransition: ((AgentSession) -> Void)?
    let inventory = AgentInventory()

    let requests = AgentRequestCenter()
    @Published private(set) var activity: AgentActivity?
    @Published private(set) var headlineVisible = false

    private var headlineKey: String?
    private var hideHeadline: DispatchWorkItem?

    private var timer: Timer?
    private var lastStates: [String: AgentSession.State] = [:]
    private var firstScan = true

    init() {
        ClaudeHooks.installScripts()
        ClaudeStatusline.install()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    private func poll() {
        guard Pref.bool(Pref.claude) else { return }
        let fm = FileManager.default
        requests.poll()
        guard let files = try? fm.contentsOfDirectory(at: ClaudeHooks.agentsDir, includingPropertiesForKeys: nil) else { return }
        var found: [AgentSession] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = obj["id"] as? String, let raw = obj["state"] as? String,
                  let state = AgentSession.State(rawValue: raw) else { continue }
            let updated = Date(timeIntervalSince1970: obj["updated"] as? Double ?? 0)
            if Date().timeIntervalSince(updated) > 3 * 3600 { try? fm.removeItem(at: file); continue }
            found.append(AgentSession(id: id, project: obj["project"] as? String ?? "Claude Code", state: state,
                                      tool: obj["tool"] as? String ?? "",
                                      message: obj["message"] as? String ?? "", updated: updated))
        }
        found.sort { $0.updated > $1.updated }
        if found != sessions { sessions = found }
        let nextActivity = AgentActivity(sessions: found)
        if nextActivity != activity { activity = nextActivity }
        revealHeadline(for: nextActivity)

        for s in found where lastStates[s.id] != s.state {
            if !firstScan, s.state != .working { onTransition?(s) }
            lastStates[s.id] = s.state
        }
        lastStates = lastStates.filter { key, _ in found.contains { $0.id == key } }
        firstScan = false
    }

    private func revealHeadline(for activity: AgentActivity?) {
        let key = activity.map { "\($0.sessionID)|\($0.state.rawValue)|\($0.project)" }
        guard key != headlineKey else { return }
        headlineKey = key
        hideHeadline?.cancel()
        hideHeadline = nil
        guard let activity else {
            headlineVisible = false
            return
        }
        headlineVisible = true
        guard activity.state != .attention else { return }
        let work = DispatchWorkItem { [weak self] in self?.headlineVisible = false }
        hideHeadline = work
        DispatchQueue.main.asyncAfter(deadline: .now() + AgentActivity.headlineDuration, execute: work)
    }
}
