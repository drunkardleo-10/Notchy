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
        notchSpace = CGSSpace(level: 400)
    }
}

@MainActor
private final class NotchDisplayInstance {
    let displayID: String
    let state: NotchState
    let panel: NotchPanel

    init(displayID: String, state: NotchState, panel: NotchPanel) {
        self.displayID = displayID
        self.state = state
        self.panel = panel
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let primaryState = NotchState()
    let shelf = ShelfStore()
    let clipboard = ClipboardManager()
    let media = MediaController()
    let pomodoro = PomodoroModel()
    let highAlert = HighAlertModel()
    let calendar = CalendarModel()
    let agents = AgentMonitor()
    let system = SystemMonitor()

    private var hudMonitor: HUDMonitor?
    private var primaryPanel: NotchPanel!
    private var primaryDisplayID: String?
    private var activeDisplayID: String?
    private var additionalDisplays: [String: NotchDisplayInstance] = [:]
    private var allDisplayCollapseWork: [String: DispatchWorkItem] = [:]
    private var state: NotchState {
        additionalDisplays[activeDisplayID ?? ""]?.state ?? primaryState
    }
    private var panel: NotchPanel! {
        additionalDisplays[activeDisplayID ?? ""]?.panel ?? primaryPanel
    }
    private var basket: BasketController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var monitors: [Any] = []
    private var expandWork: DispatchWorkItem?
    private var collapseWork: DispatchWorkItem?
    private var movingPanel = false
    private var panelDisplayIDs: [ObjectIdentifier: String] = [:]
    private var pendingExpandDisplayID: String?
    private var glassPreviewWasExpanded: Bool?

    private var dragBaseline = 0
    private var draggingContent = false
    private var lastDir = 0
    private var reversals: [Date] = []
    private var darwinTokens: [Int32] = []
    private var swipeAccumulator: CGFloat = 0
    private var swipeTriggered = false
    private var swipeGestureClaimed = false
    private var swipeStartedInNotch = false
    private var swipeResetWork: DispatchWorkItem?
    private var lyricsScrollGestureIgnored = false
    private var moduleSwipeAccumulator: CGFloat = 0
    private var moduleSwipeTriggered = false
    private var moduleSwipeClaimed = false
    private var moduleSwipeResetWork: DispatchWorkItem?
    private var isScreenLocked = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        Pref.registerDefaults()
        basket = BasketController(shelf: shelf)
        setUpPanel()
        setUpStatusItem()
        setUpMonitors()
        hudMonitor = HUDMonitor(states: { [weak self] in self?.allNotchStates ?? [] })
        hudMonitor?.onLockStateChanged = { [weak self] isLocked in
            self?.handleLockStateChanged(isLocked: isLocked)
        }
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
            MainActor.assumeIsolated { self?.configureDisplayMode() }
        }
        NotificationCenter.default.addObserver(forName: .notchDisplayConfigurationDidChange,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.configureDisplayMode() }
        }
        installCallbacks(on: primaryState, displayID: primaryDisplayID)
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


    private var allNotchStates: [NotchState] {
        [primaryState] + additionalDisplays.values.map(\.state)
    }

    private func setUpPanel() {
        let screen = NotchGeometry.mainDisplay
        primaryDisplayID = NotchGeometry.screenID(screen)
        activeDisplayID = primaryDisplayID
        primaryState.notchSize = NotchGeometry.notchSize(for: screen)
        primaryPanel = makePanel(state: primaryState, on: screen)
        panelDisplayIDs[ObjectIdentifier(primaryPanel)] = primaryDisplayID
        configureDisplayMode()
    }

    private func makePanel(state: NotchState, on screen: NSScreen) -> NotchPanel {
        let pad = NotchState.panelPadding
        let size = CGSize(
            width: NotchState.fullExpandedSize.width + pad * 2 + ModuleNavigationMetrics.panelWidthAllowance,
            height: NotchState.fullExpandedSize.height + pad
        )
        let panel = NotchPanel(contentRect: NSRect(origin: .zero, size: size),
                               styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.isMovable = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        panel.canBecomeVisibleWithoutLogin = true
        panel.ignoresMouseEvents = true
        panel.registerForDraggedTypes([.fileURL, .URL, NSPasteboard.PasteboardType("NSFilenamesPboardType")])

        let root = NotchView(state: state, shelf: shelf, clipboard: clipboard, media: media,
                             pomodoro: pomodoro, calendar: calendar, agents: agents, system: system,
                             highAlert: highAlert)
        let host = NSHostingView(rootView: root)
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        host.sizingOptions = []
        host.registerForDraggedTypes([.fileURL, .URL, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        panel.contentView = host
        position(panel, state: state, on: screen)
        panel.orderFrontRegardless()
        NotchSpaceManager.shared.notchSpace.windows.insert(panel)
        return panel
    }

    func applicationWillTerminate(_ notification: Notification) {
        for instance in additionalDisplays.values {
            NotchSpaceManager.shared.notchSpace.windows.remove(instance.panel)
        }
        if let primaryPanel { NotchSpaceManager.shared.notchSpace.windows.remove(primaryPanel) }
    }

    private func positionPanel(on target: NSScreen? = nil, animated: Bool = false) {
        guard let screen = target ?? NotchGeometry.targetScreen(), let panel else { return }
        position(panel, state: state, on: screen, animated: animated)
    }

    private func position(_ panel: NotchPanel, state targetState: NotchState, on screen: NSScreen, animated: Bool = false) {
        targetState.notchSize = NotchGeometry.notchSize(for: screen)
        let f = screen.frame
        let displayID = NotchGeometry.screenID(screen)
        let destination = NSRect(x: f.midX - panel.frame.width / 2, y: f.maxY - panel.frame.height,
                                 width: panel.frame.width, height: panel.frame.height)
        let panelID = ObjectIdentifier(panel)
        guard animated, panel.isVisible, !targetState.expanded, displayID != panelDisplayIDs[panelID] else {
            panelDisplayIDs[panelID] = displayID
            panel.setFrame(destination, display: true)
            return
        }
        guard !movingPanel else { return }

        panelDisplayIDs[panelID] = displayID
        movingPanel = true
        panel.alphaValue = 0
        panel.setFrameOrigin(NSPoint(x: destination.minX, y: f.maxY))
        panel.alphaValue = 1
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(destination, display: true)
        }, completionHandler: { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.movingPanel = false
                self.evaluateHover()
            }
        })
    }

    private func configureDisplayMode() {
        cancelPendingExpansion()
        let mode = NotchDisplayMode.current
        let main = NotchGeometry.mainDisplay
        let mainID = NotchGeometry.screenID(main)
        let target: NSScreen
        switch mode {
        case .main, .all:
            target = main
        case .external:
            target = NotchGeometry.screen(id: UserDefaults.standard.string(forKey: Pref.externalDisplayID))
                ?? NotchGeometry.externalDisplays.first
                ?? main
        case .followPointer:
            target = NotchGeometry.screen(containing: NSEvent.mouseLocation) ?? main
        }

        let targetID = NotchGeometry.screenID(target)
        if mode == .all {
            var wanted: [String: NSScreen] = [:]
            for screen in NSScreen.screens {
                guard let id = NotchGeometry.screenID(screen), id != mainID else { continue }
                wanted[id] = screen
            }
            let removedIDs = additionalDisplays.keys.filter { wanted[$0] == nil }
            for id in removedIDs {
                guard let instance = additionalDisplays[id] else { continue }
                cancelCollapseWork(for: id)
                NotchSpaceManager.shared.notchSpace.windows.remove(instance.panel)
                instance.panel.orderOut(nil)
                additionalDisplays.removeValue(forKey: id)
                panelDisplayIDs.removeValue(forKey: ObjectIdentifier(instance.panel))
            }
            for (id, screen) in wanted where additionalDisplays[id] == nil {
                let state = NotchState()
                state.notchSize = NotchGeometry.notchSize(for: screen)
                let panel = makePanel(state: state, on: screen)
                panelDisplayIDs[ObjectIdentifier(panel)] = id
                additionalDisplays[id] = NotchDisplayInstance(displayID: id, state: state, panel: panel)
                installCallbacks(on: state, displayID: id)
            }
        } else {
            for instance in additionalDisplays.values {
                cancelCollapseWork(for: instance.displayID)
                NotchSpaceManager.shared.notchSpace.windows.remove(instance.panel)
                instance.panel.orderOut(nil)
                panelDisplayIDs.removeValue(forKey: ObjectIdentifier(instance.panel))
            }
            additionalDisplays.removeAll()
        }

        primaryDisplayID = targetID
        if mode == .all { primaryDisplayID = mainID }
        activeDisplayID = primaryDisplayID
        positionPanel(on: target)
        primaryPanel?.orderFrontRegardless()
        if mode == .all {
            for instance in additionalDisplays.values { instance.panel.orderFrontRegardless() }
        }
    }

    private func installCallbacks(on state: NotchState, displayID: String?) {
        state.onQueueClosed = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self else { return }
                if let displayID { self.activeDisplayID = displayID }
                self.evaluateHover()
            }
        }
        state.onLyricsClosed = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self else { return }
                if let displayID { self.activeDisplayID = displayID }
                self.evaluateHover()
            }
        }
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

    @objc private func toggleNotch() {
        activeDisplayID = primaryDisplayID
        setExpanded(!primaryState.expanded, state: primaryState, panel: primaryPanel, displayID: primaryDisplayID)
    }

    private func setGlassPreview(_ active: Bool) {
        if active {
            guard glassPreviewWasExpanded == nil else { return }
            glassPreviewWasExpanded = primaryState.expanded
            if !primaryState.expanded { setExpanded(true, interactive: false, state: primaryState, panel: primaryPanel, displayID: primaryDisplayID) }
        } else {
            guard let wasExpanded = glassPreviewWasExpanded else { return }
            glassPreviewWasExpanded = nil
            if !wasExpanded { setExpanded(false, interactive: false, state: primaryState, panel: primaryPanel, displayID: primaryDisplayID) }
        }
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let settings = SettingsView(onGlassPreviewChanged: { [weak self] editing in
                self?.setGlassPreview(editing)
            }, onDisplayConfigurationChanged: { [weak self] in
                self?.configureDisplayMode()
            })
            let w = NSWindow(contentViewController: NSHostingController(rootView: settings))
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


    private func setExpanded(
        _ expanded: Bool,
        interactive: Bool = true,
        openingHaptic: Bool = true,
        state targetState: NotchState? = nil,
        panel targetPanel: NotchPanel? = nil,
        displayID targetDisplayID: String? = nil
    ) {
        let targetState = targetState ?? state
        let targetPanel: NotchPanel = targetPanel ?? self.panel!
        let targetDisplayID = targetDisplayID ?? activeDisplayID ?? "primary"
        guard targetState.expanded != expanded else { return }
        if expanded || pendingExpandDisplayID == targetDisplayID {
            cancelPendingExpansion()
        }
        allDisplayCollapseWork[targetDisplayID]?.cancel()
        allDisplayCollapseWork[targetDisplayID] = nil
        if expanded {
            if let first = NotchTab.allCases.first(where: { Pref.bool($0.prefKey) }), !Pref.bool(targetState.tab.prefKey) {
                targetState.tab = first
            }
            if draggingContent && Pref.bool(Pref.shelf) {
                targetState.tab = .shelf
            } else if Pref.bool(Pref.media), !draggingContent {
                targetState.tab = .media
            }
            if interactive && openingHaptic && Pref.bool(Pref.hapticFeedback) {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            targetState.hud = nil
            targetPanel.ignoresMouseEvents = !interactive
            if interactive { targetPanel.makeKey() }
        } else {
            targetState.showQueue = false
            targetState.showLyrics = false
            targetPanel.ignoresMouseEvents = true
            if interactive { targetPanel.resignKey() }
        }
        if expanded {
            withAnimation(NotchAnimation.notchOpen(for: targetPanel.screen)) {
                targetState.hoveringNotch = false
                targetState.expanded = true
            }
        } else {
            withAnimation(NotchAnimation.notchClose(for: targetPanel.screen), completionCriteria: .logicallyComplete) {
                targetState.hoveringNotch = false
                targetState.expanded = false
            } completion: { [weak self] in
                guard let self else { return }
                self.evaluateHover()
            }
        }
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

    private func handleLockStateChanged(isLocked: Bool) {
        self.isScreenLocked = isLocked
        if isLocked {
            cancelPendingExpansion()
            cancelAllCollapseWork()
            setExpanded(false, interactive: false, openingHaptic: false)
            primaryPanel?.level = NSWindow.Level(rawValue: Int(Int32.max - 2))
            for instance in additionalDisplays.values {
                instance.panel.level = NSWindow.Level(rawValue: Int(Int32.max - 2))
            }
            if let primaryPanel { NotchSpaceManager.shared.notchSpace.windows.insert(primaryPanel) }
            for instance in additionalDisplays.values {
                NotchSpaceManager.shared.notchSpace.windows.insert(instance.panel)
            }
            NotchSpaceManager.shared.notchSpace.show()
            primaryPanel?.orderFrontRegardless()
            for instance in additionalDisplays.values {
                instance.panel.orderFrontRegardless()
            }
        } else {
            primaryPanel?.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
            for instance in additionalDisplays.values {
                instance.panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
            }
            evaluateHover()
        }
    }

    private func onMouse(_ type: NSEvent.EventType, dx: CGFloat) {
        guard !isScreenLocked else { return }
        switch type {
        case .leftMouseDown:
            dragBaseline = NSPasteboard(name: .drag).changeCount
            draggingContent = false
            let loc = NSEvent.mouseLocation
            if !state.expanded && (state.hoveringNotch || isMouseInNotch(loc)) {
                if state.hoveringNotch && isMouseInTrailingLiveActivity(loc) {
                    if Pref.bool(Pref.hapticFeedback) {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    }
                    media.playPause()
                    return
                }
                setExpanded(true, interactive: true, openingHaptic: true, state: state, panel: panel, displayID: activeDisplayID ?? "primary")
            }
        case .leftMouseUp:
            draggingContent = false
            reversals.removeAll()
            basket.scheduleHide()
        case .leftMouseDragged:
            if !draggingContent {
                let dragPb = NSPasteboard(name: .drag)
                let validTypes: [NSPasteboard.PasteboardType] = [.fileURL, .URL, .string]
                let hasValid = dragPb.types?.contains(where: validTypes.contains) ?? false
                if (hasValid && dragPb.changeCount != dragBaseline) || (hasValid && dragPb.pasteboardItems?.isEmpty == false) {
                    draggingContent = true
                }
            }
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
        guard !isScreenLocked else { return }
        if glassPreviewWasExpanded != nil {
            collapseWork?.cancel()
            collapseWork = nil
            return
        }
        let loc = NSEvent.mouseLocation
        guard let pointerScreen = NotchGeometry.screen(containing: loc) ?? NotchGeometry.targetScreen() else { return }
        let mode = NotchDisplayMode.current
        let screen: NSScreen

        switch mode {
        case .main:
            activeDisplayID = primaryDisplayID
            screen = NotchGeometry.mainDisplay
            guard NotchGeometry.screenID(pointerScreen) == NotchGeometry.screenID(screen) || state.expanded else {
                updateHoveringNotch(false)
                cancelPendingExpansion()
                return
            }
        case .external:
            activeDisplayID = primaryDisplayID
            screen = NotchGeometry.targetScreen() ?? NotchGeometry.mainDisplay
            guard NotchGeometry.screenID(pointerScreen) == NotchGeometry.screenID(screen) || state.expanded else {
                updateHoveringNotch(false)
                cancelPendingExpansion()
                return
            }
        case .followPointer:
            activeDisplayID = primaryDisplayID
            screen = pointerScreen
            if !state.expanded { positionPanel(on: screen, animated: true) }
        case .all:
            screen = pointerScreen
            guard let id = NotchGeometry.screenID(screen) else { return }
            activeDisplayID = id
        }

        let hoveredDisplayID = activeDisplayID ?? "primary"
        if expandWork != nil, pendingExpandDisplayID != hoveredDisplayID {
            cancelPendingExpansion()
        }

        if mode == .all {
            for (id, instance) in displayInstances where id != activeDisplayID {
                instance.state.hoveringNotch = false
            }
            for (id, instance) in displayInstances where instance.state.expanded {
                if pointerIsInsideExpandedNotch(loc, state: instance.state, panel: instance.panel) {
                    cancelCollapseWork(for: id)
                } else {
                    scheduleCollapse(for: instance)
                }
            }
        }

        if state.expanded {
            let id = activeDisplayID ?? "primary"
            if pointerIsInsideExpandedNotch(loc, state: state, panel: panel) {
                collapseWork?.cancel()
                collapseWork = nil
                cancelCollapseWork(for: id)
            } else if mode != .all {
                guard collapseWork == nil else { return }
                let targetState = state
                let targetPanel = panel
                let work = DispatchWorkItem { [weak self] in
                    self?.collapseWork = nil
                    self?.setExpanded(false, state: targetState, panel: targetPanel, displayID: id)
                }
                collapseWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
            }
            return
        }

        let f = screen.frame
        let notch = NotchGeometry.notchSize(for: screen)
        let liveShowing = pomodoro.started || (Pref.bool(Pref.liveActivity) && Pref.bool(Pref.media) && media.hasTrack)
        let slackX: CGFloat = liveShowing ? LiveActivityLayout.sideWidth + 8 : draggingContent ? 60 : (state.hoveringNotch ? 16 : 10)
        let slackY: CGFloat = draggingContent ? 30 : (state.hoveringNotch ? 14 : 8)
        let hot = abs(loc.x - f.midX) <= notch.width / 2 + slackX && loc.y >= f.maxY - notch.height - slackY && loc.y <= f.maxY + 4
        let allowedDisplay = NotchGeometry.allowsHoverExpansion(on: screen)
        let isHovering = hot && allowedDisplay
        updateHoveringNotch(isHovering)
        let canOpenOnHover = Pref.bool(Pref.hoverOpen) || draggingContent
        guard isHovering, canOpenOnHover else {
            cancelPendingExpansion()
            return
        }
        let baseDelay = draggingContent ? 0.05 : Pref.double(Pref.expandDelay)
        let delay = baseDelay + (movingPanel ? 0.32 : 0)
        let targetState = state
        let targetPanel = panel
        let targetID = activeDisplayID ?? "primary"
        guard expandWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.expandWork = nil
            self?.pendingExpandDisplayID = nil
            self?.setExpanded(
                true,
                openingHaptic: baseDelay >= 0.25,
                state: targetState,
                panel: targetPanel,
                displayID: targetID
            )
        }
        expandWork = work
        pendingExpandDisplayID = targetID
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelPendingExpansion() {
        expandWork?.cancel()
        expandWork = nil
        pendingExpandDisplayID = nil
    }

    private var displayInstances: [String: NotchDisplayInstance] {
        var result: [String: NotchDisplayInstance] = [:]
        if let primaryDisplayID {
            result[primaryDisplayID] = NotchDisplayInstance(displayID: primaryDisplayID, state: primaryState, panel: primaryPanel)
        }
        result.merge(additionalDisplays) { _, replica in replica }
        return result
    }

    private func pointerIsInsideExpandedNotch(_ point: NSPoint, state: NotchState, panel: NotchPanel) -> Bool {
        guard let screen = panel.screen else { return false }
        let frame = screen.frame
        var size = state.expandedSize
        if Date().timeIntervalSince(state.queueClosedAt) < 2.0 {
            size.width = max(size.width, NotchState.queueExpandedSize.width)
        } else if Date().timeIntervalSince(state.lyricsClosedAt) < 1.0 {
            size.width = max(size.width, NotchState.lyricsExpandedSize.width)
        }
        let navigationExtension = NotchTab.available.count > 1 ? ModuleNavigationMetrics.trailingHitExtension : 0
        return point.x >= frame.midX - size.width / 2 - 14
            && point.x <= frame.midX + size.width / 2 + 14 + navigationExtension
            && point.y >= frame.maxY - size.height - 14 && point.y <= frame.maxY + 4
    }

    private func scheduleCollapse(for instance: NotchDisplayInstance) {
        let id = instance.displayID
        guard allDisplayCollapseWork[id] == nil else { return }
        let work = DispatchWorkItem { [weak self, weak state = instance.state, weak panel = instance.panel] in
            guard let self, let state, let panel else { return }
            self.allDisplayCollapseWork[id] = nil
            self.setExpanded(false, state: state, panel: panel, displayID: id)
        }
        allDisplayCollapseWork[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func cancelCollapseWork(for id: String) {
        allDisplayCollapseWork[id]?.cancel()
        allDisplayCollapseWork[id] = nil
    }

    private func cancelAllCollapseWork() {
        allDisplayCollapseWork.values.forEach { $0.cancel() }
        allDisplayCollapseWork.removeAll()
    }

    private func updateHoveringNotch(_ hovering: Bool) {
        guard !state.expanded else {
            if state.hoveringNotch { state.hoveringNotch = false }
            return
        }
        let shouldHover = hovering && !Pref.bool(Pref.hoverOpen)
        guard state.hoveringNotch != shouldHover else { return }
        withAnimation(NotchAnimation.spring(response: 0.28, dampingFraction: 0.78)) {
            state.hoveringNotch = shouldHover
        }
        guard shouldHover, Pref.bool(Pref.hapticFeedback) else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    private func isMouseInNotch(_ loc: NSPoint) -> Bool {
        guard let screen = panel.screen ?? NotchGeometry.targetScreen() else { return false }
        let f = screen.frame
        let notch = state.notchSize

        if state.expanded {
            var s = state.expandedSize
            if Date().timeIntervalSince(state.queueClosedAt) < 2.0 {
                s.width = max(s.width, NotchState.queueExpandedSize.width)
            } else if Date().timeIntervalSince(state.lyricsClosedAt) < 1.0 {
                s.width = max(s.width, NotchState.lyricsExpandedSize.width)
            }
            let navigationExtension = NotchTab.available.count > 1 ? ModuleNavigationMetrics.trailingHitExtension : 0
            return loc.x >= f.midX - s.width / 2 - 14
                && loc.x <= f.midX + s.width / 2 + 14 + navigationExtension
                && loc.y >= f.maxY - s.height - 14 && loc.y <= f.maxY + 4
        } else {
            if state.hoveringNotch { return true }
            let liveShowing = pomodoro.started || (Pref.bool(Pref.liveActivity) && Pref.bool(Pref.media) && media.hasTrack)
            let slackX: CGFloat = liveShowing ? LiveActivityLayout.sideWidth + 12 : 20
            let slackY: CGFloat = 14
            return abs(loc.x - f.midX) <= notch.width / 2 + slackX && loc.y >= f.maxY - notch.height - slackY && loc.y <= f.maxY + 4
        }
    }

    private func isMouseInTrailingLiveActivity(_ loc: NSPoint) -> Bool {
        guard let screen = panel.screen ?? NotchGeometry.targetScreen() else { return false }
        let liveShowing = Pref.bool(Pref.liveActivity) && Pref.bool(Pref.media) && media.hasTrack
        guard liveShowing else { return false }
        let f = screen.frame
        let notch = state.notchSize
        let minX = f.midX + notch.width / 2 - 4
        let maxX = minX + LiveActivityLayout.sideWidth + 10
        return loc.x >= minX && loc.x <= maxX && loc.y >= f.maxY - notch.height - 14 && loc.y <= f.maxY + 4
    }

    @discardableResult
    private func handleScrollWheel(_ event: NSEvent) -> Bool {
        guard !isScreenLocked else { return false }
        selectDisplayForPointer()
        let loc = NSEvent.mouseLocation
        let isOverLyricsList = state.expanded && state.showLyrics && state.tab == .media && state.hoveringLyrics

        if event.phase.contains(.began) {
            lyricsScrollGestureIgnored = false
            resetSwipeGesture()
            resetModuleSwipeGesture()
            swipeStartedInNotch = !isOverLyricsList && (state.hoveringNotch || isMouseInNotch(loc))
        }

        if isOverLyricsList {
            if event.phase != [] || event.momentumPhase != [] {
                lyricsScrollGestureIgnored = true
            }
            resetSwipeGesture()
            resetModuleSwipeGesture()
            if !lyricsScrollGestureIgnored { return false }
        }

        if lyricsScrollGestureIgnored {
            if event.phase.contains(.ended) || event.phase.contains(.cancelled)
                || event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled) {
                lyricsScrollGestureIgnored = false
            }
            return false
        }

        if event.momentumPhase != [] {
            if moduleSwipeClaimed {
                if event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled) {
                    resetModuleSwipeGesture()
                } else {
                    scheduleModuleSwipeReset()
                }
                return true
            }
            guard swipeGestureClaimed else { return false }
            if event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled) {
                resetSwipeGesture()
            } else {
                scheduleSwipeReset()
            }
            return true
        }

        let rawDx = event.scrollingDeltaX
        let rawDy = event.scrollingDeltaY
        let physicalDy = event.isDirectionInvertedFromDevice ? rawDy : -rawDy

        if !state.expanded && (state.hoveringNotch || isMouseInNotch(loc)) {
            if event.hasPreciseScrollingDeltas, abs(rawDy) > abs(rawDx), physicalDy <= -20 {
                setExpanded(true, interactive: true, openingHaptic: true, state: state, panel: panel, displayID: activeDisplayID ?? "primary")
                return true
            }
        }

        if state.expanded,
           NotchTab.available.count > 1,
           event.hasPreciseScrollingDeltas,
           (moduleSwipeClaimed || swipeStartedInNotch || isMouseInNotch(loc)),
           (moduleSwipeClaimed || abs(rawDy) > abs(rawDx)) {
            moduleSwipeClaimed = true
            cancelPendingExpansion()

            moduleSwipeAccumulator += physicalDy
            if !moduleSwipeTriggered {
                if moduleSwipeAccumulator <= -36 {
                    moduleSwipeTriggered = true
                    moveModule(by: 1)
                } else if moduleSwipeAccumulator >= 36 {
                    moduleSwipeTriggered = true
                    moveModule(by: -1)
                }
            }
            scheduleModuleSwipeReset()
            return true
        }

        guard Pref.bool(Pref.media) else {
            resetSwipeGesture()
            return false
        }

        guard media.hasTrack || state.tab == .media else {
            resetSwipeGesture()
            return false
        }
        if state.expanded && state.tab != .media {
            resetSwipeGesture()
            return false
        }
        guard event.hasPreciseScrollingDeltas else {
            if swipeGestureClaimed {
                scheduleSwipeReset()
                return true
            }
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                resetSwipeGesture()
            }
            return false
        }
        guard swipeGestureClaimed || swipeStartedInNotch || state.hoveringNotch || isMouseInNotch(loc) else {
            resetSwipeGesture()
            return false
        }

        guard swipeGestureClaimed || abs(rawDx) > abs(rawDy) || abs(swipeAccumulator) > 5 else {
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                resetSwipeGesture()
            }
            return false
        }

        swipeGestureClaimed = true
        cancelPendingExpansion()

        let physicalDx = event.isDirectionInvertedFromDevice ? rawDx : -rawDx
        swipeAccumulator += physicalDx

        let threshold: CGFloat = 36
        if !swipeTriggered {
            if swipeAccumulator >= threshold {
                swipeTriggered = true
                triggerSwipe(.next)
            } else if swipeAccumulator <= -threshold {
                swipeTriggered = true
                triggerSwipe(.previous)
            }
        }

        scheduleSwipeReset()

        return true
    }

    private func moveModule(by offset: Int) {
        guard state.moveToAdjacentTab(by: offset) else { return }
        if Pref.bool(Pref.hapticFeedback) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    private func scheduleModuleSwipeReset() {
        moduleSwipeResetWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.resetModuleSwipeGesture()
        }
        moduleSwipeResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func resetModuleSwipeGesture() {
        moduleSwipeResetWork?.cancel()
        moduleSwipeResetWork = nil
        moduleSwipeAccumulator = 0
        moduleSwipeTriggered = false
        moduleSwipeClaimed = false
    }

    private func scheduleSwipeReset() {
        swipeResetWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.resetSwipeGesture()
        }
        swipeResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func selectDisplayForPointer() {
        let mode = NotchDisplayMode.current
        switch mode {
        case .main, .external:
            activeDisplayID = primaryDisplayID
        case .all:
            if let screen = NotchGeometry.screen(containing: NSEvent.mouseLocation),
               let id = NotchGeometry.screenID(screen) {
                activeDisplayID = id
            }
        case .followPointer:
            activeDisplayID = primaryDisplayID
            if !state.expanded,
               let screen = NotchGeometry.screen(containing: NSEvent.mouseLocation) {
                positionPanel(on: screen, animated: true)
            }
        }
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
        swipeGestureClaimed = false
        swipeStartedInNotch = false
    }
}
