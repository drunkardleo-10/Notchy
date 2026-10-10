import Foundation

struct AgentQuestion: Equatable {
    struct Option: Equatable {
        let label: String
        let detail: String
    }

    let header: String
    let text: String
    let options: [Option]
    let multiSelect: Bool
}

struct AgentDiffLine: Equatable, Identifiable {
    enum Kind { case context, removed, added }
    let id: Int
    let kind: Kind
    let number: Int?
    let text: String
}

struct AgentRequest: Identifiable, Equatable {
    enum Content: Equatable {
        case questions([AgentQuestion])
        case diff(lines: [AgentDiffLine], added: Int, removed: Int)
        case command(String, detail: String)
        case summary(String)
    }

    let id: String
    let pid: Int32
    let project: String
    let tool: String
    let target: String
    let content: Content
    let rawInput: Data
    let created: Date

    var isQuestion: Bool {
        if case .questions = content { return true }
        return false
    }

    var verb: String {
        switch tool {
        case "Edit", "MultiEdit", "NotebookEdit": "Edit"
        case "Write": "Write"
        case "Bash": "Run"
        case "WebFetch": "Fetch"
        case "WebSearch": "Search"
        case "Read": "Read"
        default: tool.hasPrefix("mcp__") ? (tool.split(separator: "__").last.map(String.init) ?? tool) : tool
        }
    }

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String, let tool = json["tool"] as? String else { return nil }
        let input = json["input"] as? [String: Any] ?? [:]
        let cwd = json["cwd"] as? String ?? ""
        self.id = id
        self.pid = Int32(json["pid"] as? Int ?? 0)
        self.project = json["project"] as? String ?? "Claude Code"
        self.tool = tool
        self.created = Date(timeIntervalSince1970: json["created"] as? Double ?? 0)
        self.rawInput = (try? JSONSerialization.data(withJSONObject: input)) ?? Data()
        self.target = Self.target(tool: tool, input: input, cwd: cwd)
        self.content = Self.content(tool: tool, input: input)
    }

    func inputObject() -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: rawInput) as? [String: Any]) ?? [:]
    }

    private static func target(tool: String, input: [String: Any], cwd: String) -> String {
        let raw = (input["file_path"] ?? input["notebook_path"] ?? input["url"] ?? input["query"] ?? input["pattern"]) as? String ?? ""
        guard !cwd.isEmpty, raw.hasPrefix(cwd + "/") else { return raw }
        return String(raw.dropFirst(cwd.count + 1))
    }

    private static func content(tool: String, input: [String: Any]) -> Content {
        switch tool {
        case "AskUserQuestion":
            return .questions(questions(from: input))
        case "Edit":
            return editDiff(path: input["file_path"] as? String,
                            old: input["old_string"] as? String ?? "",
                            new: input["new_string"] as? String ?? "")
        case "MultiEdit":
            let first = (input["edits"] as? [[String: Any]])?.first ?? [:]
            return editDiff(path: input["file_path"] as? String,
                            old: first["old_string"] as? String ?? "",
                            new: first["new_string"] as? String ?? "")
        case "Write":
            let lines = (input["content"] as? String ?? "").components(separatedBy: "\n")
            let shown = lines.prefix(40).enumerated().map { AgentDiffLine(id: $0.offset, kind: .added, number: $0.offset + 1, text: $0.element) }
            return .diff(lines: shown, added: lines.count, removed: 0)
        case "Bash":
            return .command(input["command"] as? String ?? "", detail: input["description"] as? String ?? "")
        default:
            let pairs = input.sorted { $0.key < $1.key }.compactMap { key, value -> String? in
                guard let text = value as? String ?? (value as? NSNumber)?.stringValue else { return nil }
                return "\(key): \(text)"
            }
            return .summary(pairs.joined(separator: "\n"))
        }
    }

    private static func questions(from input: [String: Any]) -> [AgentQuestion] {
        (input["questions"] as? [[String: Any]] ?? []).map { item in
            let options = (item["options"] as? [[String: Any]] ?? []).map {
                AgentQuestion.Option(label: $0["label"] as? String ?? "", detail: $0["description"] as? String ?? "")
            }
            return AgentQuestion(header: item["header"] as? String ?? "",
                                 text: item["question"] as? String ?? "",
                                 options: options,
                                 multiSelect: item["multiSelect"] as? Bool ?? false)
        }
    }

    private static func editDiff(path: String?, old: String, new: String) -> Content {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")
        var start = 1
        var context: String?
        if let path, let file = try? String(contentsOfFile: path, encoding: .utf8), let range = file.range(of: old), !old.isEmpty {
            let before = file[..<range.lowerBound]
            start = before.filter { $0 == "\n" }.count + 1
            let preceding = before.components(separatedBy: "\n").dropLast()
            context = preceding.last
        }
        var lines: [AgentDiffLine] = []
        if let context, start > 1 {
            lines.append(AgentDiffLine(id: lines.count, kind: .context, number: start - 1, text: context))
        }
        for (offset, text) in oldLines.enumerated() where !old.isEmpty {
            lines.append(AgentDiffLine(id: lines.count, kind: .removed, number: start + offset, text: text))
        }
        for (offset, text) in newLines.enumerated() where !new.isEmpty {
            lines.append(AgentDiffLine(id: lines.count, kind: .added, number: start + offset, text: text))
        }
        return .diff(lines: lines, added: new.isEmpty ? 0 : newLines.count, removed: old.isEmpty ? 0 : oldLines.count)
    }
}
