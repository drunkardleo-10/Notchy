import AppKit
import SwiftUI

enum NotchTab: String, CaseIterable, Identifiable {
    case media, shelf, clipboard, calendar, timer, claude, shortcuts, system, mirror, tools
    var id: String { rawValue }

    var title: String {
        switch self {
        case .media: "Media"
        case .shelf: "Shelf"
        case .clipboard: "Clipboard"
        case .calendar: "Calendar"
        case .timer: "Timer"
        case .claude: "Claude"
        case .shortcuts: "Shortcuts"
        case .system: "System"
        case .mirror: "Mirror"
        case .tools: "Tools"
        }
    }

    var icon: String {
        switch self {
        case .media: "music.note"
        case .shelf: "tray.full"
        case .clipboard: "doc.on.clipboard"
        case .calendar: "calendar"
        case .timer: "timer"
        case .claude: "sparkles"
        case .shortcuts: "bolt.fill"
        case .system: "cpu"
        case .mirror: "camera.fill"
        case .tools: "wrench.and.screwdriver"
        }
    }

    var prefKey: String {
        switch self {
        case .media: Pref.media
        case .shelf: Pref.shelf
        case .clipboard: Pref.clipboard
        case .calendar: Pref.calendar
        case .timer: Pref.timer
        case .claude: Pref.claude
        case .shortcuts: Pref.shortcuts
        case .system: Pref.system
        case .mirror: Pref.mirror
        case .tools: Pref.tools
        }
    }
}

@MainActor
final class NotchState: ObservableObject {
    static let compactExpandedSize = CGSize(width: 480, height: 186)
    static let queueExpandedSize = CGSize(width: 780, height: 186)
    static let fullExpandedSize = CGSize(width: 820, height: 235)
    static let panelPadding: CGFloat = 24

    @Published var showQueue = false {
        didSet {
            if !showQueue && oldValue {
                queueClosedAt = Date()
                onQueueClosed?()
            }
        }
    }
    var queueClosedAt: Date = .distantPast
    var onQueueClosed: (() -> Void)?

    var expandedSize: CGSize {
        let active = NotchTab.allCases.filter { UserDefaults.standard.bool(forKey: $0.prefKey) }
        if active.count <= 1 && (active.first == .media || active.isEmpty) {
            return showQueue ? Self.queueExpandedSize : Self.compactExpandedSize
        }
        return Self.fullExpandedSize
    }

    @Published var expanded = false
    @Published var tab: NotchTab = .media
    @Published var dropTargeted = false
    @Published var hud: HUDEvent?
    @Published var notchSize = CGSize(width: 190, height: 32)
}

enum NotchGeometry {
    static func targetScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    static func notchSize(for screen: NSScreen) -> CGSize {
        if !Pref.bool(Pref.islandMode), screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return CGSize(width: screen.frame.width - left.width - right.width,
                          height: screen.safeAreaInsets.top)
        }
        return CGSize(width: 190, height: 32)
    }
}

struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let tx = min(topRadius, w / 4)
        let ty = min(topRadius * 0.75, h / 2)
        let b = min(bottomRadius, min(w / 2 - tx, h / 2))

        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))

        p.addCurve(
            to: CGPoint(x: tx, y: ty),
            control1: CGPoint(x: tx * 0.44, y: 0),
            control2: CGPoint(x: tx, y: ty * 0.56)
        )

        p.addLine(to: CGPoint(x: tx, y: h - b))

        p.addCurve(
            to: CGPoint(x: tx + b, y: h),
            control1: CGPoint(x: tx, y: h - b * 0.44),
            control2: CGPoint(x: tx + b * 0.56, y: h)
        )

        p.addLine(to: CGPoint(x: w - tx - b, y: h))

        p.addCurve(
            to: CGPoint(x: w - tx, y: h - b),
            control1: CGPoint(x: w - tx - b * 0.56, y: h),
            control2: CGPoint(x: w - tx, y: h - b * 0.44)
        )

        p.addLine(to: CGPoint(x: w - tx, y: ty))

        p.addCurve(
            to: CGPoint(x: w, y: 0),
            control1: CGPoint(x: w - tx, y: ty * 0.56),
            control2: CGPoint(x: w - tx * 0.44, y: 0)
        )

        p.closeSubpath()
        return p
    }
}

extension AnyTransition {
    static var notchContent: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.94, anchor: .top)
                .combined(with: .opacity)
                .animation(.easeOut(duration: 0.22).delay(0.06)),
            removal: .opacity.animation(.easeOut(duration: 0.07))
        )
    }
}

