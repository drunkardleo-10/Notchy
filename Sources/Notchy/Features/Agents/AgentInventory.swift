import Foundation

@MainActor
final class AgentInventory: ObservableObject {
    @Published private(set) var installed: [AgentKind] = []
    @Published private(set) var usage: [String: AgentUsage] = [:]

    private var scanTimer: Timer?
    private var usageTimer: Timer?

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
        Task.detached { [weak self] in
            var result: [String: AgentUsage] = [:]
            if let codex = CodexUsageReader.read() { result["codex"] = codex }
            if let claude = ClaudeUsageReader.read() { result["claude"] = claude }
            await self?.apply(usage: result)
        }
    }

    private func apply(installed found: [AgentKind]) {
        if found != installed { installed = found }
    }

    private func apply(usage result: [String: AgentUsage]) {
        if result != usage { usage = result }
    }
}
