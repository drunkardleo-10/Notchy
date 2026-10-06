import AppKit
import SwiftUI
import notify

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class NotchSpaceManager {
    static let shared = NotchSpaceManager()
    let notchSpace: CGSSpace

    private init() {
        notchSpace = CGSSpace(level: 2147483647)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = NotchState()
    let shelf = ShelfStore()
    let clipboard = ClipboardManager()
    let media = MediaController()
    let pomodoro = PomodoroModel()
    let highAlert = HighAlertModel()
    let calendar = CalendarModel()
    let agents = AgentMonitor()
    let system = SystemMonitor()
    let shortcuts = ShortcutsModel()

    private var hudMonitor: HUDMonitor?
    private var panel: NotchPanel!
    private var basket: BasketController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var monitors: [Any] = []
    private var expandWork: DispatchWorkItem?
    private var collapseWork: DispatchWorkItem?

    private var dragBaseline = 0
    private var draggingContent = false
    private var lastDir = 0
    private var reversals: [Date] = []
    private var darwinTokens: [Int32] = []
    private var swipeAccumulator: CGFloat = 0
    private var swipeTriggered = false
    private var swipeResetWork: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Pref.registerDefaults()
        basket = BasketController(shelf: shelf)
        setUpPanel()
        setUpStatusItem()
        setUpMonitors()
        hudMonitor = HUDMonitor(state: state)
        pomodoro.onFinish = { [weak self] phase in
            NSSound(named: "Glass")?.play()
            self?.hudMonitor?.showMessage(icon: phase == .focus ? "checkmark.circle.fill" : "cup.and.saucer.fill",
                                          title: phase == .focus ? "Focus complete" : "Break over",
                                          subtitle: phase == .focus ? "Time for a break" : "Back to focus", duration: 5)
        }
        calendar.onMeetingSoon = { [weak self] event, minutes in
            NSSound(named: "Glass")?.play()
            self?.hudMonitor?.showMessage(icon: "calendar", title: event.title,
                                          subtitle: minutes <= 1 ? "Starting now" : "Starts in \(minutes) min", duration: 6)
        }
        agents.onTransition = { [weak self] session in
            let done = session.state == .done
            self?.hudMonitor?.showMessage(icon: done ? "checkmark.circle.fill" : "exclamationmark.bubble.fill",
                                          title: done ? "Claude finished" : "Claude needs you",
                                          subtitle: session.project, duration: 5)
        }
        highAlert.onChange = { [weak self] on in
            self?.hudMonitor?.showMessage(icon: "cup.and.saucer.fill", title: on ? "High Alert on" : "High Alert off",
                                          subtitle: on ? "Your Mac will stay awake" : "Sleep settings restored", duration: 2.5)
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.positionPanel() }
        }
        state.onQueueClosed = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.evaluateHover()
            }
        }
        let notifications: [(String, () -> Void)] = [
            ("com.notchy.playPause", { [weak self] in self?.media.playPause() }),
            ("com.notchy.toggle", { [weak self] in self?.toggleNotch() }),
            ("com.notchy.next", { [weak self] in self?.media.next() }),
            ("com.notchy.previous", { [weak self] in self?.media.previous() }),
        ]
        for (name, action) in notifications {
            var token: Int32 = 0
            notify_register_dispatch(name, &token, .main) { _ in
                action()
            }
            darwinTokens.append(token)
        }
    }


    private func setUpPanel() {
        let pad = NotchState.panelPadding
        let size = CGSize(width: NotchState.fullExpandedSize.width + pad * 2, height: NotchState.fullExpandedSize.height + pad)
        panel = NotchPanel(contentRect: NSRect(origin: .zero, size: size),
                           styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.isMovable = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        panel.ignoresMouseEvents = true

        let root = NotchView(state: state, shelf: shelf, clipboard: clipboard, media: media,
                             pomodoro: pomodoro, calendar: calendar, agents: agents, system: system,
                             shortcuts: shortcuts, highAlert: highAlert)
        let host = NSHostingView(rootView: root)
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        host.sizingOptions = []
        panel.contentView = host
        positionPanel()
        panel.orderFrontRegardless()
        NotchSpaceManager.shared.notchSpace.windows.insert(panel)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let panel {
            NotchSpaceManager.shared.notchSpace.windows.remove(panel)
        }
    }

    private func positionPanel() {
        guard let screen = NotchGeometry.targetScreen() else { return }
        state.notchSize = NotchGeometry.notchSize(for: screen)
        let f = screen.frame
        panel.setFrame(NSRect(x: f.midX - panel.frame.width / 2, y: f.maxY - panel.frame.height,
                              width: panel.frame.width, height: panel.frame.height), display: true)
    }


    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "notchy")
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Notch", action: #selector(toggleNotch), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit notchy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = $0.action == #selector(NSApplication.terminate(_:)) ? NSApp : self }
        statusItem.menu = menu
    }

    @objc private func toggleNotch() { setExpanded(!state.expanded) }

    @objc func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "notchy Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            settingsWindow = w
        }
        setExpanded(false)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }


    private func setExpanded(_ expanded: Bool) {
        guard state.expanded != expanded else { return }
        expandWork?.cancel()
        collapseWork?.cancel()
        collapseWork = nil
        if expanded {
            if let first = NotchTab.allCases.first(where: { Pref.bool($0.prefKey) }), !Pref.bool(state.tab.prefKey) {
                state.tab = first
            }
            if Pref.bool(Pref.media), !draggingContent { state.tab = .media }
            if Pref.bool(Pref.hapticFeedback) {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            state.hud = nil
            panel.ignoresMouseEvents = false
            panel.makeKey()
        } else {
            state.showQueue = false
            panel.ignoresMouseEvents = true
            panel.resignKey()
        }
        state.expanded = expanded
    }


    private func setUpMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let type = event.type, dx = event.deltaX
            MainActor.assumeIsolated { self?.onMouse(type, dx: dx) }
        }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let type = event.type, dx = event.deltaX
            MainActor.assumeIsolated { self?.onMouse(type, dx: dx) }
            return event
        }) { monitors.append(local) }

        let scrollMask: NSEvent.EventTypeMask = [.scrollWheel]
        if let globalScroll = NSEvent.addGlobalMonitorForEvents(matching: scrollMask, handler: { [weak self] event in
            _ = MainActor.assumeIsolated { self?.handleScrollWheel(event) }
        }) { monitors.append(globalScroll) }
        if let localScroll = NSEvent.addLocalMonitorForEvents(matching: scrollMask, handler: { [weak self] event in
            let consumed = MainActor.assumeIsolated { self?.handleScrollWheel(event) ?? false }
            return consumed ? nil : event
        }) { monitors.append(localScroll) }
    }

    private func onMouse(_ type: NSEvent.EventType, dx: CGFloat) {
        switch type {
        case .leftMouseDown:
            dragBaseline = NSPasteboard(name: .drag).changeCount
            draggingContent = false
        case .leftMouseUp:
            draggingContent = false
            reversals.removeAll()
            basket.scheduleHide()
        case .leftMouseDragged:
            if !draggingContent, NSPasteboard(name: .drag).changeCount != dragBaseline { draggingContent = true }
            if draggingContent { trackJiggle(dx: dx) }
        default: break
        }
        evaluateHover()
    }

    private func trackJiggle(dx: CGFloat) {
        guard Pref.bool(Pref.basket), abs(dx) > 3 else { return }
        let dir = dx > 0 ? 1 : -1
        guard dir != lastDir else { return }
        lastDir = dir
        let now = Date()
        reversals = reversals.filter { now.timeIntervalSince($0) < 0.8 } + [now]
        if reversals.count >= 5 {
            reversals.removeAll()
            basket.show(near: NSEvent.mouseLocation)
        }
    }

    private func evaluateHover() {
        guard let screen = panel.screen ?? NotchGeometry.targetScreen() else { return }
        let loc = NSEvent.mouseLocation
        let f = screen.frame
        let notch = state.notchSize

        if state.expanded {
            guard NSEvent.pressedMouseButtons & 1 == 0 else { return }
            var s = state.expandedSize
            if Date().timeIntervalSince(state.queueClosedAt) < 2.0 {
                s.width = max(s.width, NotchState.queueExpandedSize.width)
            }
            let inside = loc.x >= f.midX - s.width / 2 - 14 && loc.x <= f.midX + s.width / 2 + 14
                && loc.y >= f.maxY - s.height - 14 && loc.y <= f.maxY + 4
            if !inside {
                guard collapseWork == nil else { return }
                let work = DispatchWorkItem { [weak self] in
                    self?.collapseWork = nil
                    self?.setExpanded(false)
                }
                collapseWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
            } else {
                collapseWork?.cancel()
                collapseWork = nil
            }
            return
        }

        let liveShowing = pomodoro.started || (Pref.bool(Pref.liveActivity) && Pref.bool(Pref.media) && media.hasTrack)
        let slackX: CGFloat = liveShowing ? LiveActivityLayout.sideWidth : draggingContent ? 60 : 8
        let slackY: CGFloat = draggingContent ? 30 : 4
        let hot = abs(loc.x - f.midX) <= notch.width / 2 + slackX && loc.y >= f.maxY - notch.height - slackY && loc.y <= f.maxY + 4
        guard hot, Pref.bool(Pref.hoverOpen) || draggingContent else {
            expandWork?.cancel(); expandWork = nil
            return
        }
        guard expandWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.expandWork = nil
            self?.setExpanded(true)
        }
        expandWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (draggingContent ? 0.05 : 0.15), execute: work)
    }

    private func isMouseInNotch(_ loc: NSPoint) -> Bool {
        guard let screen = panel.screen ?? NotchGeometry.targetScreen() else { return false }
        let f = screen.frame
        let notch = state.notchSize

        if state.expanded {
            var s = state.expandedSize
            if Date().timeIntervalSince(state.queueClosedAt) < 2.0 {
                s.width = max(s.width, NotchState.queueExpandedSize.width)
            }
            return loc.x >= f.midX - s.width / 2 - 14 && loc.x <= f.midX + s.width / 2 + 14
                && loc.y >= f.maxY - s.height - 14 && loc.y <= f.maxY + 4
        } else {
            let liveShowing = pomodoro.started || (Pref.bool(Pref.liveActivity) && Pref.bool(Pref.media) && media.hasTrack)
            let slackX: CGFloat = liveShowing ? LiveActivityLayout.sideWidth : 8
            let slackY: CGFloat = 4
            return abs(loc.x - f.midX) <= notch.width / 2 + slackX && loc.y >= f.maxY - notch.height - slackY && loc.y <= f.maxY + 4
        }
    }

    @discardableResult
    private func handleScrollWheel(_ event: NSEvent) -> Bool {
        guard Pref.bool(Pref.media) else { return false }
        guard media.hasTrack || state.tab == .media else { return false }
        if state.expanded && state.tab != .media { return false }

        let loc = NSEvent.mouseLocation
        guard isMouseInNotch(loc) else {
            resetSwipeGesture()
            return false
        }

        guard event.hasPreciseScrollingDeltas else { return false }

        if event.momentumPhase != [] {
            if state.swipeOffset != 0 || state.activeSwipeDirection != nil {
                withAnimation(NotchAnimation.pressSettle) {
                    state.swipeOffset = 0
                    state.activeSwipeDirection = nil
                }
            }
            return false
        }

        let rawDx = event.scrollingDeltaX
        let rawDy = event.scrollingDeltaY

        if event.phase == .began {
            swipeAccumulator = 0
            swipeTriggered = false
            swipeResetWork?.cancel()
            swipeResetWork = nil
        }

        guard abs(rawDx) > abs(rawDy) || abs(swipeAccumulator) > 5 else {
            return false
        }

        expandWork?.cancel()
        expandWork = nil

        let physicalDx = event.isDirectionInvertedFromDevice ? rawDx : -rawDx
        swipeAccumulator += physicalDx

        let offset = min(max(swipeAccumulator * 0.35, -24), 24)
        withAnimation(NotchAnimation.drag) {
            state.swipeOffset = offset
        }

        if swipeAccumulator < -15 {
            withAnimation(NotchAnimation.hover) {
                state.activeSwipeDirection = .previous
            }
        } else if swipeAccumulator > 15 {
            withAnimation(NotchAnimation.hover) {
                state.activeSwipeDirection = .next
            }
        } else {
            withAnimation(NotchAnimation.hover) {
                state.activeSwipeDirection = nil
            }
        }

        let threshold: CGFloat = 36
        if !swipeTriggered {
            if swipeAccumulator <= -threshold {
                swipeTriggered = true
                triggerSwipe(.previous)
            } else if swipeAccumulator >= threshold {
                swipeTriggered = true
                triggerSwipe(.next)
            }
        }

        if event.phase == .ended || event.phase == .cancelled {
            resetSwipeGesture()
        } else {
            swipeResetWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.resetSwipeGesture()
            }
            swipeResetWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
        }

        return true
    }

    private func triggerSwipe(_ direction: NotchSwipeDirection) {
        if Pref.bool(Pref.hapticFeedback) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        switch direction {
        case .previous:
            media.previous()
            state.flashSwipe(.previous)
        case .next:
            media.next()
            state.flashSwipe(.next)
        }
    }

    private func resetSwipeGesture() {
        swipeResetWork?.cancel()
        swipeResetWork = nil
        swipeAccumulator = 0
        swipeTriggered = false
        if state.swipeOffset != 0 || state.activeSwipeDirection != nil {
            withAnimation(NotchAnimation.pressSettle) {
                state.swipeOffset = 0
                state.activeSwipeDirection = nil
            }
        }
    }
}
