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
    static let lyricsExpandedSize = CGSize(width: 590, height: 186)
    static let queueExpandedSize = CGSize(width: 820, height: 186)
    static let fullExpandedSize = CGSize(width: 820, height: 235)
    static let panelPadding: CGFloat = 24

    @Published var showQueue = false {
        didSet {
            if !showQueue && oldValue {
                queueClosedAt = Date()
                onQueueClosed?()
            }
            if showQueue && showLyrics {
                showLyrics = false
            }
        }
    }
    @Published var showLyrics = false {
        didSet {
            if !showLyrics && oldValue {
                lyricsClosedAt = Date()
                onLyricsClosed?()
            }
            if showLyrics && showQueue {
                showQueue = false
            }
        }
    }
    var queueClosedAt: Date = .distantPast
    var onQueueClosed: (() -> Void)?
    var lyricsClosedAt: Date = .distantPast
    var onLyricsClosed: (() -> Void)?

    var expandedSize: CGSize {
        if showLyrics {
            return Self.lyricsExpandedSize
        }
        if showQueue {
            return Self.queueExpandedSize
        }
        return Self.compactExpandedSize
    }

    @Published var expanded = false
    @Published var hoveringNotch = false
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

enum NotchDisplayMode: String, CaseIterable, Identifiable {
    case main
    case external
    case all
    case followPointer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main: "Main display"
        case .external: "Another display"
        case .all: "All displays"
        case .followPointer: "Follow pointer"
        }
    }

    var detail: String {
        switch self {
        case .main: "Show one notch on your Mac display."
        case .external: "Show one notch on a selected external display."
        case .all: "Show an independent notch on every connected display."
        case .followPointer: "Move one notch to the display under your pointer."
        }
    }

    static var current: Self {
        let rawValue = UserDefaults.standard.string(forKey: Pref.notchDisplayMode) ?? Self.main.rawValue
        return Self(rawValue: rawValue) ?? .main
    }
}

enum NotchGeometry {
    static var hasExternalDisplays: Bool {
        NSScreen.screens.count > 1
    }

    static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    static func allowsHoverExpansion(on screen: NSScreen) -> Bool {
        switch NotchDisplayMode.current {
        case .main:
            return sameDisplay(screen, mainDisplay)
        case .external:
            let target = Self.screen(id: UserDefaults.standard.string(forKey: Pref.externalDisplayID))
                ?? externalDisplays.first
                ?? mainDisplay
            return sameDisplay(screen, target)
        case .all, .followPointer:
            return true
        }
    }

    static var mainDisplay: NSScreen {
        NSScreen.screens.first(where: isBuiltIn) ?? NSScreen.main ?? NSScreen.screens.first!
    }

    static var externalDisplays: [NSScreen] {
        NSScreen.screens.filter { !sameDisplay($0, mainDisplay) }
    }

    static func screen(id: String?) -> NSScreen? {
        guard let id else { return nil }
        return NSScreen.screens.first { screenID($0) == id }
    }

    static func screenID(_ screen: NSScreen) -> String? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue
    }

    static func targetScreen() -> NSScreen? {
        switch NotchDisplayMode.current {
        case .main:
            return mainDisplay
        case .external:
            return screen(id: UserDefaults.standard.string(forKey: Pref.externalDisplayID)) ?? externalDisplays.first ?? mainDisplay
        case .all, .followPointer:
            return screen(containing: NSEvent.mouseLocation) ?? mainDisplay
        }
    }

    static func notchSize(for screen: NSScreen) -> CGSize {
        if !Pref.bool(Pref.islandMode), screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return CGSize(width: screen.frame.width - left.width - right.width,
                          height: screen.safeAreaInsets.top)
        }
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        return CGSize(width: 190, height: max(0, menuBarHeight))
    }

    private static func isBuiltIn(_ screen: NSScreen) -> Bool {
        guard let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return screen.safeAreaInsets.top > 0
        }
        return CGDisplayIsBuiltin(CGDirectDisplayID(displayNumber.uint32Value)) != 0
    }

    private static func sameDisplay(_ lhs: NSScreen, _ rhs: NSScreen?) -> Bool {
        guard let rhs else { return false }
        guard
            let leftNumber = lhs.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
            let rightNumber = rhs.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            return lhs === rhs
        }
        return leftNumber.uint32Value == rightNumber.uint32Value
    }
}

extension Notification.Name {
    static let notchDisplayConfigurationDidChange = Notification.Name("NotchyDisplayConfigurationDidChange")
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
