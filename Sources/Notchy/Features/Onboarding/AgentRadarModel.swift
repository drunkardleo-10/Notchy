import Combine
import SwiftUI

@MainActor
final class AgentRadarModel: ObservableObject {
    enum Phase { case idle, scanning, done }
    enum Link: Equatable { case unavailable, disconnected, waiting, live(project: String), failed }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var found: [AgentKind] = []
    @Published private(set) var link: Link = .unavailable

    private let agents: AgentMonitor
    private var watchSince = Date()
    private var watcher: AnyCancellable?

    init(agents: AgentMonitor) {
        self.agents = agents
    }

    var claudeFound: Bool { found.contains { $0.id == "claude" } }

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
        guard ClaudeHooks.install() else {
            link = .failed
            return
        }
        UserDefaults.standard.set(true, forKey: Pref.claude)
        OnboardingFeedback.tick()
        watch(since: Date())
    }

    private func refreshLink() {
        if !claudeFound {
            link = .unavailable
        } else if ClaudeHooks.isInstalled && Pref.bool(Pref.claude) {
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
                self.link = .live(project: session.project)
            }
            OnboardingFeedback.success()
        }
    }
}
