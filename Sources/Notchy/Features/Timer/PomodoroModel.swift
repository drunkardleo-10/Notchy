import Foundation

@MainActor
final class PomodoroModel: ObservableObject {
    enum Phase {
        case focus, rest
        var title: String { self == .focus ? "Focus" : "Break" }
        var icon: String { self == .focus ? "brain.head.profile" : "cup.and.saucer.fill" }
    }

    @Published var phase: Phase = .focus
    @Published var remaining: Int
    @Published private(set) var running = false
    @Published private(set) var started = false
    @Published var focusMinutes: Int { didSet { persist(); syncIdle() } }
    @Published var breakMinutes: Int { didSet { persist(); syncIdle() } }

    var onFinish: ((Phase) -> Void)?
    private var timer: Timer?
    private var endDate: Date?

    init() {
        let d = UserDefaults.standard
        let focus = d.object(forKey: "pomodoroFocus") as? Int ?? 25
        focusMinutes = focus
        breakMinutes = d.object(forKey: "pomodoroBreak") as? Int ?? 5
        remaining = focus * 60
    }

    var formatted: String { String(format: "%02d:%02d", remaining / 60, remaining % 60) }
    private func seconds(for phase: Phase) -> Int { (phase == .focus ? focusMinutes : breakMinutes) * 60 }

    private func persist() {
        UserDefaults.standard.set(focusMinutes, forKey: "pomodoroFocus")
        UserDefaults.standard.set(breakMinutes, forKey: "pomodoroBreak")
    }

    private func syncIdle() { if !started { remaining = seconds(for: phase) } }

    func startPause() {
        if running {
            tick()
            timer?.invalidate()
            running = false
        } else {
            started = true
            running = true
            endDate = Date().addingTimeInterval(TimeInterval(remaining))
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
        }
    }

    private func tick() {
        guard let endDate else { return }
        remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
        if remaining == 0 { finish() }
    }

    private func finish() {
        timer?.invalidate()
        running = false
        started = false
        let done = phase
        phase = done == .focus ? .rest : .focus
        remaining = seconds(for: phase)
        onFinish?(done)
    }

    func reset() {
        timer?.invalidate()
        running = false
        started = false
        phase = .focus
        remaining = seconds(for: .focus)
    }

    func skip() {
        timer?.invalidate()
        running = false
        started = false
        phase = phase == .focus ? .rest : .focus
        remaining = seconds(for: phase)
    }
}
