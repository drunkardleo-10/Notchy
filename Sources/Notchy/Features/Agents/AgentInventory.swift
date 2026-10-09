import Foundation

@MainActor
final class AgentInventory: ObservableObject {
    @Published private(set) var installed: [AgentKind] = []
    @Published private(set) var usage: [String: AgentUsage] = [:]

    private var scanTimer: Timer?
    private var usageTimer: Timer?
    private var lastDevinFetch = Date.distantPast

    init() {
        refresh()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.scan() }
        }
        usageTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.loadUsage() }
        }
    }

    func refresh() {
        scan()
        loadUsage()
    }

    private func scan() {
        guard Pref.bool(Pref.claude) else { return }
        Task.detached { [weak self] in
            let found = AgentScanner.installed()
            await self?.apply(installed: found)
        }
    }

    private func loadUsage() {
        guard Pref.bool(Pref.claude) else { return }
        let fetchDevin = Date().timeIntervalSince(lastDevinFetch) > 300 && installed.contains { $0.id == "devin" }
        if fetchDevin { lastDevinFetch = Date() }
        Task.detached { [weak self] in
            var result: [String: AgentUsage] = [:]
            if let codex = CodexUsageReader.read() { result["codex"] = codex }
            if let claude = ClaudeUsageReader.read() { result["claude"] = claude }
            let devin = fetchDevin ? await DevinUsageReader.read() : nil
            await self?.apply(usage: result, devin: devin, refreshedDevin: fetchDevin)
        }
    }

    private func apply(installed found: [AgentKind]) {
        if found != installed { installed = found }
    }

    private func apply(usage result: [String: AgentUsage], devin: AgentUsage?, refreshedDevin: Bool) {
        var merged = result
        if refreshedDevin {
            if let devin { merged["devin"] = devin }
        } else if let cached = usage["devin"] {
            merged["devin"] = cached
        }
        if merged != usage { usage = merged }
    }
}
