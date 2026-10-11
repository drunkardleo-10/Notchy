import Foundation

struct AgentActivity: Equatable {
    static let doneLinger: TimeInterval = 3
    static let headlineDuration: TimeInterval = 3
    static let staleWorking: TimeInterval = 30 * 60

    let sessionID: String
    let state: AgentSession.State
    let project: String
    let species: MascotSpecies
    let pose: MascotPose
    let activeCount: Int

    var headline: String {
        switch state {
        case .done: "Session done"
        case .attention: "Needs your input"
        case .working: project
        }
    }

    init?(sessions: [AgentSession], now: Date = Date()) {
        let active = sessions.filter {
            $0.state != .done && now.timeIntervalSince($0.updated) < Self.staleWorking
        }
        let recentDone = sessions.first { $0.state == .done && now.timeIntervalSince($0.updated) < Self.doneLinger }
        guard let session = active.first(where: { $0.state == .attention }) ?? recentDone ?? active.first else { return nil }
        sessionID = session.id
        state = session.state
        project = session.project
        species = MascotSpecies(agent: session.agent)
        activeCount = active.count
        pose = MascotPose(state: session.state, tool: session.tool)
    }
}

enum MascotPose: String, Equatable {
    case thinking, coding, reading, browsing, building, planning, delegating, serving, celebrating, alert

    init(state: AgentSession.State, tool: String) {
        switch state {
        case .done: self = .celebrating
        case .attention: self = .alert
        case .working: self = Self.pose(for: tool)
        }
    }

    private static func pose(for tool: String) -> MascotPose {
        switch tool {
        case "Edit", "MultiEdit", "Write", "NotebookEdit": .coding
        case "Read", "Grep", "Glob", "LS", "NotebookRead": .reading
        case "WebSearch", "WebFetch": .browsing
        case "Bash", "BashOutput", "KillShell", "KillBash": .building
        case "TodoWrite", "TaskCreate", "TaskUpdate", "TaskList", "ExitPlanMode": .planning
        case "Task", "Agent": .delegating
        case "": .thinking
        default: tool.hasPrefix("mcp__") ? .serving : guess(tool.lowercased())
        }
    }

    private static func guess(_ tool: String) -> MascotPose {
        let rules: [(MascotPose, [String])] = [
            (.serving, ["mcp"]),
            (.delegating, ["task", "agent", "invoke"]),
            (.planning, ["todo", "plan"]),
            (.browsing, ["web", "url", "fetch", "browser"]),
            (.coding, ["edit", "write", "patch", "replace", "create"]),
            (.reading, ["read", "view", "grep", "glob", "list", "find", "search"]),
            (.building, ["bash", "shell", "exec", "command", "terminal", "run"])
        ]
        return rules.first { _, keys in keys.contains { tool.contains($0) } }?.0 ?? .thinking
    }
}
