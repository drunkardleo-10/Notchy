import AppKit
import SwiftUI

@MainActor
final class BasketController {
    private let panel: NSPanel
    private let shelf: ShelfStore
    private var hideWork: DispatchWorkItem?
    private var holdUntil = Date.distantPast

    init(shelf: ShelfStore) {
        self.shelf = shelf
        let size = BasketView.panelSize
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.registerForDraggedTypes([.fileURL, .URL, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        let host = NSHostingView(rootView: BasketView(shelf: shelf, onSpawn: { [weak self] in self?.hold(for: 1.0) }))
        host.sizingOptions = []
        host.registerForDraggedTypes([.fileURL, .URL, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        panel.contentView = host
    }

    func show(near point: NSPoint) {
        hideWork?.cancel()
        guard !panel.isVisible else { return }
        let size = BasketView.panelSize
        let inset = BasketView.inset
        let target = NSRect(x: point.x - size.width / 2,
                            y: point.y - 20 + inset.top - size.height,
                            width: size.width, height: size.height)
        panel.setFrame(target.offsetBy(dx: 0, dy: 10), display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup {
            $0.duration = 0.22
            $0.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(target, display: true)
        }
    }

    func scheduleHide() {
        guard panel.isVisible else { return }
        hideWork?.cancel()
        let delay = max(1.0, holdUntil.timeIntervalSinceNow)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.2; self.panel.animator().alphaValue = 0 },
                                                 completionHandler: { self.panel.orderOut(nil) })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func hold(for seconds: TimeInterval) {
        holdUntil = Date().addingTimeInterval(seconds)
        if hideWork != nil { scheduleHide() }
    }
}
