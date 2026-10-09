import Foundation

struct UsageWindow: Equatable, Identifiable {
    let minutes: Int
    let usedFraction: Double
    let resetsAt: Date?

    var id: Int { minutes }

    var label: String {
        switch minutes {
        case 300: "5h"
        case 10080: "Weekly"
        case 43200: "Monthly"
        case 1440: "Daily"
        case ..<1440: "\(max(1, minutes / 60))h"
        default: "\(minutes / 1440)d"
        }
    }

    func leftFraction(at date: Date = Date()) -> Double {
        if let resetsAt, resetsAt < date { return 1 }
        return max(0, min(1, 1 - usedFraction))
    }
}

struct AgentUsage: Equatable {
    var plan: String?
    var windows: [UsageWindow]
}

enum CodexUsageReader {
    private static let root = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex/sessions", isDirectory: true)

    static func read() -> AgentUsage? {
        for file in recentSessionFiles(limit: 6) {
            if let usage = lastUsage(in: file) { return usage }
        }
        return nil
    }

    private static func children(_ url: URL) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        return items.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private static func recentSessionFiles(limit: Int) -> [URL] {
        var files: [URL] = []
        for year in children(root) {
            for month in children(year) {
                for day in children(month) {
                    files += children(day).filter { $0.pathExtension == "jsonl" }
                    if files.count >= limit { return Array(files.prefix(limit)) }
                }
            }
        }
        return files
    }

    private static func lastUsage(in file: URL) -> AgentUsage? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > 524_288 ? size - 524_288 : 0)
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n").reversed() where line.contains("\"rate_limits\"") {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let payload = object["payload"] as? [String: Any],
                  let limits = payload["rate_limits"] as? [String: Any] else { continue }
            let windows = ["primary", "secondary"].compactMap { key -> UsageWindow? in
                guard let window = limits[key] as? [String: Any],
                      let used = window["used_percent"] as? Double,
                      let minutes = window["window_minutes"] as? Int else { return nil }
                let reset = (window["resets_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
                return UsageWindow(minutes: minutes, usedFraction: used / 100, resetsAt: reset)
            }
            guard !windows.isEmpty else { continue }
            let plan = (limits["plan_type"] as? String).map { $0.prefix(1).uppercased() + $0.dropFirst() }
            return AgentUsage(plan: plan, windows: windows.sorted { $0.minutes < $1.minutes })
        }
        return nil
    }
}

enum ClaudeUsageReader {
    static let fileURL = ClaudeStatusline.usageURL

    static func read() -> AgentUsage? {
        guard let data = try? Data(contentsOf: fileURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let limits = object["rate_limits"] as? [String: Any] else { return nil }
        let windows = [("five_hour", 300), ("seven_day", 10080)].compactMap { key, minutes -> UsageWindow? in
            guard let window = limits[key] as? [String: Any],
                  let used = (window["used_percentage"] as? Double) ?? (window["utilization"] as? Double) else { return nil }
            return UsageWindow(minutes: minutes, usedFraction: used / 100, resetsAt: date(window["resets_at"]))
        }
        return windows.isEmpty ? nil : AgentUsage(plan: nil, windows: windows)
    }

    private static func date(_ value: Any?) -> Date? {
        if let number = value as? Double {
            return Date(timeIntervalSince1970: number > 1e12 ? number / 1000 : number)
        }
        if let string = value as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
        }
        return nil
    }
}
