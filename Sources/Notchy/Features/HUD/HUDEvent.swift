import Foundation

enum HUDKind: Equatable {
    case volume(Float, muted: Bool)
    case brightness(Float)
    case airpods(name: String, battery: String?)
    case battery(percent: Int, state: BatteryState)
    case lock(unlocked: Bool)
    case capsLock(on: Bool)
    case message(icon: String, title: String, subtitle: String)
}

enum BatteryState: Equatable { case charging, onBattery, low, full }

struct HUDEvent: Equatable {
    let id: UUID
    var kind: HUDKind

    init(id: UUID = UUID(), kind: HUDKind) {
        self.id = id
        self.kind = kind
    }
}
