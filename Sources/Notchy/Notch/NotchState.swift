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
    @Published var swipeOffset: CGFloat = 0
    @Published var activeSwipeDirection: NotchSwipeDirection?
    @Published var flashDirection: NotchSwipeDirection?
    private var flashWork: DispatchWorkItem?

    func flashSwipe(_ direction: NotchSwipeDirection) {
        flashWork?.cancel()
        flashDirection = direction
        withAnimation(.spring(response: 0.22, dampingFraction: 0.60)) {
            swipeOffset = direction == .previous ? -14 : 14
        }
        let work = DispatchWorkItem { [weak self] in
            withAnimation(NotchAnimation.pressSettle) {
                self?.flashDirection = nil
                self?.swipeOffset = 0
            }
        }
        flashWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
}

enum NotchSwipeDirection {
    case previous
    case next
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
        var p = Path()
        let left = rect.minX
        let right = rect.maxX
        let top = rect.minY
        let bottom = rect.maxY
        let topR = min(topRadius, rect.width / 2, rect.height)
        let bottomR = min(bottomRadius, rect.width / 2, rect.height)

        p.move(to: CGPoint(x: left, y: top))
        p.addQuadCurve(to: CGPoint(x: left + topR, y: top + topR),
                       control: CGPoint(x: left + topR, y: top))
        p.addLine(to: CGPoint(x: left + topR, y: bottom - bottomR))
        p.addQuadCurve(to: CGPoint(x: left + topR + bottomR, y: bottom),
                       control: CGPoint(x: left + topR, y: bottom))
        p.addLine(to: CGPoint(x: right - topR - bottomR, y: bottom))
        p.addQuadCurve(to: CGPoint(x: right - topR, y: bottom - bottomR),
                       control: CGPoint(x: right - topR, y: bottom))
        p.addLine(to: CGPoint(x: right - topR, y: top + topR))
        p.addQuadCurve(to: CGPoint(x: right, y: top),
                       control: CGPoint(x: right - topR, y: top))
        p.addLine(to: CGPoint(x: left, y: top))
        return p
    }
}
