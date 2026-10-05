import Foundation
import IOKit.pwr_mgt

@MainActor
final class HighAlertModel: ObservableObject {
    @Published private(set) var active = false
    @Published private(set) var endsAt: Date?
    @Published var minutes = 0

    var onChange: ((Bool) -> Void)?
    private var assertionID = IOPMAssertionID(0)
    private var expiry: Timer?

    func toggle() { active ? stop() : start() }

    func start() {
        releaseAssertion()
        let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                                 IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                 "notchy High Alert" as CFString, &assertionID)
        guard result == kIOReturnSuccess else { return }
        active = true
        expiry?.invalidate()
        if minutes > 0 {
            endsAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
            expiry = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.stop() }
            }
        } else {
            endsAt = nil
        }
        onChange?(true)
    }

    func stop() {
        guard active else { return }
        releaseAssertion()
        expiry?.invalidate()
        active = false
        endsAt = nil
        onChange?(false)
    }

    private func releaseAssertion() {
        if assertionID != 0 { IOPMAssertionRelease(assertionID); assertionID = 0 }
    }
}
