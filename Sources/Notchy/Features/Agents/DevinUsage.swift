import Foundation

enum DevinUsageReader {
    private static let credentialsURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".local/share/devin/credentials.toml")
    private static let defaultServer = "https://server.codeium.com"
    private static let statusPath = "/exa.seat_management_pb.SeatManagementService/GetUserStatus"

    static func read() async -> AgentUsage? {
        guard let credentials = storedCredentials(),
              let url = endpoint(server: credentials.server) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        let metadata: [String: Any] = [
            "apiKey": credentials.key, "ideName": "devin", "ideVersion": "0.0.0",
            "extensionName": "devin", "extensionVersion": "0.0.0", "locale": "en"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["metadata": metadata])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return parse(json)
    }

    static func parse(_ json: Any) -> AgentUsage? {
        guard let root = json as? [String: Any] else { return nil }
        let status = record(root["userStatus"], root["user_status"]) ?? root
        let plan = record(status["planStatus"], status["plan_status"]) ?? status
        let info = record(plan["planInfo"], plan["plan_info"], status["plan_info"])
        let hideDaily = (info?["hideDailyQuota"] as? Bool ?? info?["hide_daily_quota"] as? Bool) ?? false

        func window(minutes: Int, remaining: [String], reset: [String]) -> UsageWindow? {
            guard let left = number(plan, remaining) else { return nil }
            let date = number(plan, reset).map { Date(timeIntervalSince1970: $0) }
            return UsageWindow(minutes: minutes, usedFraction: max(0, min(1, 1 - left / 100)), resetsAt: date)
        }

        var windows: [UsageWindow] = []
        if !hideDaily, let daily = window(minutes: 1440, remaining: ["dailyQuotaRemainingPercent", "daily_quota_remaining_percent"],
                                          reset: ["dailyQuotaResetAtUnix", "daily_quota_reset_at_unix"]) {
            windows.append(daily)
        }
        if let weekly = window(minutes: 10080, remaining: ["weeklyQuotaRemainingPercent", "weekly_quota_remaining_percent"],
                               reset: ["weeklyQuotaResetAtUnix", "weekly_quota_reset_at_unix"]) {
            windows.append(weekly)
        }
        let name = (info?["planName"] as? String) ?? (info?["plan_name"] as? String)
        guard !windows.isEmpty else { return nil }
        return AgentUsage(plan: name.map { $0.prefix(1).uppercased() + $0.dropFirst() }, windows: windows)
    }

    private static func record(_ values: Any?...) -> [String: Any]? {
        values.lazy.compactMap { $0 as? [String: Any] }.first
    }

    private static func number(_ dictionary: [String: Any], _ keys: [String]) -> Double? {
        for key in keys {
            if let value = dictionary[key] as? Double { return value }
            if let text = dictionary[key] as? String, let value = Double(text) { return value }
        }
        return nil
    }

    private static func storedCredentials() -> (key: String, server: String?)? {
        guard let text = try? String(contentsOf: credentialsURL, encoding: .utf8) else { return nil }
        var key: String?
        var server: String?
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let value = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if parts[0] == "windsurf_api_key" { key = value }
            if parts[0] == "api_server_url" { server = value }
        }
        guard let key, !key.isEmpty else { return nil }
        return (key, server)
    }

    private static func endpoint(server: String?) -> URL? {
        guard let base = URL(string: server?.isEmpty == false ? server! : defaultServer),
              base.scheme == "https", base.host != nil, base.user == nil, base.password == nil else { return nil }
        return URL(string: base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + statusPath)
    }
}
