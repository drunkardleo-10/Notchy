import Foundation

@MainActor
final class AgentRequestCenter: ObservableObject {
    enum Decision {
        case allow
        case deny
        case answer([String: String])
        case terminal
    }

    @Published private(set) var pending: [AgentRequest] = []
    var onChange: (() -> Void)?

    var current: AgentRequest? { pending.first }

    func poll() {
        touchHeartbeat()
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: ClaudeHooks.requestsDir, includingPropertiesForKeys: nil) else { return }
        var found: [AgentRequest] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let request = AgentRequest(json: json) else { continue }
            guard Self.isAlive(request.pid) else {
                try? fm.removeItem(at: file)
                continue
            }
            found.append(request)
        }
        found.sort { $0.created < $1.created }
        guard found.map(\.id) != pending.map(\.id) else { return }
        pending = found
        onChange?()
    }

    func respond(_ request: AgentRequest, with decision: Decision) {
        var payload: [String: Any]
        switch decision {
        case .allow:
            payload = ["behavior": "allow"]
        case .deny:
            payload = ["behavior": "deny", "message": "Denied from Notchy"]
        case .answer(let answers):
            var input = request.inputObject()
            input["answers"] = answers
            payload = ["behavior": "allow", "updatedInput": input]
        case .terminal:
            payload = ["behavior": "ask"]
        }
        let url = ClaudeHooks.responsesDir.appendingPathComponent(request.id + ".json")
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? data.write(to: url, options: .atomic)
        }
        pending.removeAll { $0.id == request.id }
        onChange?()
    }

    private func touchHeartbeat() {
        let url = ClaudeHooks.heartbeatURL
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        } else {
            try? Data().write(to: url)
        }
    }

    private static func isAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0 || errno == EPERM
    }
}
