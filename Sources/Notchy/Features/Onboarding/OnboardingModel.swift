import AVFoundation
import SwiftUI

extension Notification.Name {
    static let replayOnboarding = Notification.Name("NotchyReplayOnboarding")
}

@MainActor
final class OnboardingModel: ObservableObject {
    nonisolated static let version = 1

    @Published private(set) var step: OnboardingStep = .welcome
    @Published private(set) var direction = 1
    @Published private(set) var permissionStatus: PermissionStatus = .undetermined
    @Published private(set) var hudEvent: HUDKind?
    @Published private(set) var temperature: Int?
    @Published var playgroundAnswer: Bool?
    @Published private(set) var waitingForSettings: PermissionKind?

    let radar: AgentRadarModel
    let intro = OnboardingIntro()
    let media: MediaController
    let calendar: CalendarModel

    var onPresent: (() -> Void)?
    var onYield: (() -> Void)?
    var onStepChange: ((OnboardingStep) -> Void)?
    var onFinish: (() -> Void)?
    var onOutro: (() -> Void)?

    private(set) var isActive = false
    private(set) var introPlaying = false
    private(set) var outroPlaying = false
    private var yielded = false
    private(set) var permissionPlan: [PermissionKind] = []
    private(set) var resolved: [PermissionKind: Bool] = [:]
    private var pollTimer: Timer?
    private var advanceWork: DispatchWorkItem?
    private let weather = WeatherService()

    private(set) static var isPresenting = false

    static var holdsPermissionPrompts: Bool { isNeeded || isPresenting }

    nonisolated static var isNeeded: Bool {
        UserDefaults.standard.integer(forKey: Pref.onboardingVersion) < version
    }

    init(agents: AgentMonitor, media: MediaController, calendar: CalendarModel) {
        radar = AgentRadarModel(agents: agents)
        self.media = media
        self.calendar = calendar
        weather.onUpdate = { [weak self] in
            guard let self, let snapshot = self.weather.snapshot else { return }
            withAnimation(NotchAnimation.state) { self.temperature = snapshot.temperature }
        }
    }

    var steps: [OnboardingStep] {
        var list: [OnboardingStep] = [.welcome, .modules, .appearance, .agents]
        list += permissionPlan.map { .permission($0) }
        if Pref.bool(Pref.claude) { list.append(.playground) }
        list.append(.finish)
        return list
    }

    var progress: (index: Int, total: Int) {
        let middle = steps.filter(\.showsFooter)
        return (middle.firstIndex(of: step) ?? 0, middle.count)
    }

    var canGoBack: Bool { progress.index > 0 }

    var continueTitle: String {
        switch step {
        case .permission: permissionStatus == .granted ? "Continue" : "Not now"
        case .playground: playgroundAnswer == nil ? "Skip" : "Continue"
        default: "Continue"
        }
    }

    var continueProminent: Bool {
        switch step {
        case .permission: permissionStatus == .granted
        case .playground: playgroundAnswer != nil
        default: true
        }
    }

    func start(resuming: Bool = false) {
        stopPolling()
        radar.reset()
        intro.reset()
        resolved = [:]
        playgroundAnswer = nil
        hudEvent = nil
        waitingForSettings = nil
        permissionPlan = pendingPermissions()
        direction = 1
        let saved = resuming ? UserDefaults.standard.string(forKey: Pref.onboardingResume).flatMap(OnboardingStep.init(key:)) : nil
        let first = saved ?? .welcome
        if case .permission(let kind) = first, !permissionPlan.contains(kind) {
            permissionPlan.insert(kind, at: 0)
        }
        step = first
        save(first)
        onStepChange?(first)
        isActive = true
        Self.isPresenting = true
        introPlaying = saved == nil
        if case .permission(let kind) = first { startPolling(kind) }
        onPresent?()
    }

    func beginOutro() {
        guard isActive, !outroPlaying else { return }
        outroPlaying = true
        stopPolling()
        advanceWork?.cancel()
        advanceWork = nil
        onOutro?()
    }

    func finishOutro() {
        guard outroPlaying else { return }
        outroPlaying = false
        complete()
    }

    func returnFromSettings() {
        guard yielded else { return }
        yielded = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { waitingForSettings = nil }
        onPresent?()
    }

    private func save(_ step: OnboardingStep) {
        UserDefaults.standard.set(step.key, forKey: Pref.onboardingResume)
    }

    func finishIntro() {
        guard introPlaying else { return }
        introPlaying = false
        onPresent?()
    }

    func advance() {
        if step == .modules { permissionPlan = pendingPermissions() }
        let list = steps
        guard let index = list.firstIndex(of: step), index + 1 < list.count else {
            complete()
            return
        }
        go(to: list[index + 1], direction: 1)
    }

    func back() {
        let list = steps
        guard let index = list.firstIndex(of: step), index > 0 else { return }
        go(to: list[index - 1], direction: -1)
    }

    func complete() {
        guard isActive else { return }
        isActive = false
        Self.isPresenting = false
        UserDefaults.standard.set(Self.version, forKey: Pref.onboardingVersion)
        UserDefaults.standard.removeObject(forKey: Pref.onboardingResume)
        waitingForSettings = nil
        introPlaying = false
        outroPlaying = false
        stopPolling()
        onFinish?()
    }

    func receive(_ kind: HUDKind) {
        guard isActive, step == .permission(.accessibility) else { return }
        switch kind {
        case .volume, .brightness:
            hudEvent = kind
            scheduleAdvance(after: 1.6)
        default:
            break
        }
    }

    func request(_ kind: PermissionKind) {
        switch kind {
        case .accessibility:
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            openSettings(kind)
        case .automation:
            guard let target = PermissionKind.automationTarget else {
                openMusic()
                return
            }
            Task.detached { _ = PermissionKind.automationStatus(target, ask: true) }
        case .calendar:
            calendar.requestAccess()
        case .location:
            weather.prepare()
        case .camera:
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        }
    }

    func openSettings(_ kind: PermissionKind) {
        kind.openSettings()
        yielded = true
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { waitingForSettings = kind }
        onYield?()
    }

    private func openMusic() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, self.step == .permission(.automation) else { return }
                self.request(.automation)
            }
        }
    }

    private func pendingPermissions() -> [PermissionKind] {
        PermissionKind.needed().filter { $0.status != .granted }
    }

    private func go(to next: OnboardingStep, direction: Int) {
        advanceWork?.cancel()
        advanceWork = nil
        if case .permission(let kind) = step { resolved[kind] = permissionStatus == .granted }
        self.direction = direction
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { step = next }
        save(next)
        onStepChange?(next)
        OnboardingFeedback.tick()
        stopPolling()
        if case .permission(let kind) = next { startPolling(kind) }
    }

    private func startPolling(_ kind: PermissionKind) {
        hudEvent = nil
        permissionStatus = kind.status
        if permissionStatus == .granted { reveal(kind) }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll(kind) }
        }
    }

    private func stopPolling() {
        yielded = false
        waitingForSettings = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func poll(_ kind: PermissionKind) {
        let next = kind.status
        guard next != permissionStatus else { return }
        let granted = next == .granted
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { permissionStatus = next }
        guard granted else { return }
        OnboardingFeedback.success()
        reveal(kind)
        if yielded {
            yielded = false
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { waitingForSettings = nil }
            onPresent?()
        }
        switch kind {
        case .accessibility: break
        case .camera: scheduleAdvance(after: 3.4)
        default: scheduleAdvance(after: 2.6)
        }
    }

    private func reveal(_ kind: PermissionKind) {
        switch kind {
        case .calendar: calendar.refresh()
        case .location: weather.prepare()
        default: break
        }
    }

    private func scheduleAdvance(after delay: TimeInterval) {
        guard advanceWork == nil else { return }
        let current = step
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.step == current else { return }
            self.advanceWork = nil
            self.advance()
        }
        advanceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
