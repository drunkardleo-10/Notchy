import AppKit
import Combine
import SwiftUI

private final class LockScreenPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class LockWidgetsController {
    private let model = LockWidgetsModel()
    private let media: MediaController
    private var panels: [NSPanel] = []
    private var trackObserver: AnyCancellable?
    private var timer: Timer?

    init(media: MediaController) {
        self.media = media
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.prepare() }
        }
        model.prepare()
    }

    func setLocked(_ locked: Bool) {
        if locked && Pref.bool(Pref.lockWidgets) {
            show()
        } else {
            hide()
        }
    }

    private func show() {
        guard panels.isEmpty, let screen = NSScreen.screens.first else { return }
        model.refresh()
        model.weather.refreshIfStale()

        let frame = screen.frame
        let rowHeight: CGFloat = 80
        let rowCenter = frame.maxY - frame.height * 0.285 - Pref.double(Pref.lockWidgetsOffset)
        let row = makePanel(NSRect(x: frame.minX, y: rowCenter - rowHeight / 2, width: frame.width, height: rowHeight),
                            content: LockWidgetsView(model: model))
        panels.append(row)

        if Pref.bool(Pref.widgetMedia) {
            let size = NSSize(width: 860, height: 280)
            let center = frame.maxY - frame.height * 0.73
            let card = makePanel(NSRect(x: frame.midX - size.width / 2, y: center - size.height / 2, width: size.width, height: size.height),
                                 content: LockMediaCard(media: media))
            panels.append(card)
            trackObserver = media.$hasTrack.sink { [weak card] hasTrack in
                card?.ignoresMouseEvents = !hasTrack
            }
        }

        NotchSpaceManager.shared.notchSpace.show()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.model.refresh()
                self?.model.weather.refreshIfStale()
            }
        }
    }

    private func makePanel<Content: View>(_ rect: NSRect, content: Content) -> NSPanel {
        let panel = LockScreenPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.level = NSWindow.Level(rawValue: Int(Int32.max - 2))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: content)
        panel.orderFrontRegardless()
        NotchSpaceManager.shared.notchSpace.windows.insert(panel)
        return panel
    }

    private func hide() {
        timer?.invalidate()
        timer = nil
        trackObserver = nil
        let closing = panels
        panels = []
        for panel in closing {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                panel.animator().alphaValue = 0
            } completionHandler: {
                MainActor.assumeIsolated {
                    NotchSpaceManager.shared.notchSpace.windows.remove(panel)
                    panel.orderOut(nil)
                }
            }
        }
    }
}
