import Combine
import SwiftUI

@MainActor
final class AgentRadarModel: ObservableObject {
    enum Phase { case idle, scanning, done }
    enum Link: Equatable { case unavailable, disconnected, waiting, live(agent: String, project: String), failed(agents: [String]) }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var found: [AgentKind] = []
    @Published private(set) var link: Link = .unavailable

    private let agents: AgentMonitor
    private var watchSince = Date()
    private var watcher: AnyCancellable?

    init(agents: AgentMonitor) {
        self.agents = agents
    }

    var connectable: [AgentKind] { found.filter { AgentIntegration.forAgent($0.id) != nil } }

    var connectableNames: String {
        let names = connectable.map(\.name)
        guard names.count > 1, let last = names.last else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }

    var needsCodexTrust: Bool { connectable.contains { $0.id == "codex" } }

    func start() {
        guard phase == .idle else { return }
        phase = .scanning
        Task {
            let result = await Task.detached { AgentScanner.installed() }.value
            try? await Task.sleep(for: .seconds(1.4))
            for kind in result {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { found.append(kind) }
                OnboardingFeedback.blip()
                try? await Task.sleep(for: .milliseconds(360))
            }
            withAnimation(NotchAnimation.state) {
                phase = .done
                refreshLink()
                if link == .disconnected { connect() }
            }
        }
    }

    func reset() {
        watcher = nil
        phase = .idle
        found = []
        link = .unavailable
    }

    func connect() {
        let failed = connectable.filter { !(AgentIntegration.forAgent($0.id)?.install() ?? false) }
        guard failed.count < connectable.count else {
            link = .failed(agents: failed.map(\.name))
            return
        }
        UserDefaults.standard.set(true, forKey: Pref.claude)
        OnboardingFeedback.tick()
        if failed.isEmpty {
            watch(since: Date())
        } else {
            link = .failed(agents: failed.map(\.name))
        }
    }

    private func refreshLink() {
        let integrations = connectable.compactMap { AgentIntegration.forAgent($0.id) }
        if integrations.isEmpty {
            link = .unavailable
        } else if integrations.allSatisfy({ $0.isInstalled() }) && Pref.bool(Pref.claude) {
            watch(since: Date().addingTimeInterval(-600))
        } else {
            link = .disconnected
        }
    }

    private func watch(since: Date) {
        watchSince = since
        link = .waiting
        watcher = agents.$sessions.receive(on: RunLoop.main).sink { [weak self] sessions in
            guard let self, case .waiting = self.link,
                  let session = sessions.first(where: { $0.updated > self.watchSince }) else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                self.link = .live(agent: MascotSpecies(agent: session.agent).displayName, project: session.project)
            }
            OnboardingFeedback.success()
        }
    }
}
