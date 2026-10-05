import AppKit
import SwiftUI
@MainActor
final class BasketController {
    private let panel: NSPanel
    private let shelf: ShelfStore
    private var hideWork: DispatchWorkItem?

    init(shelf: ShelfStore) {
        self.shelf = shelf
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 240, height: 150),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSHostingView(rootView: BasketView(shelf: shelf))
        host.sizingOptions = []
        panel.contentView = host
    }

    func show(near point: NSPoint) {
        hideWork?.cancel()
        guard !panel.isVisible else { return }
        panel.setFrameOrigin(NSPoint(x: point.x - 120, y: point.y - 170))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 1 }
    }

    func scheduleHide() {
        guard panel.isVisible else { return }
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.2; self.panel.animator().alphaValue = 0 },
                                                 completionHandler: { self.panel.orderOut(nil) })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }
}

struct BasketView: View {
    @ObservedObject var shelf: ShelfStore
    @State private var targeted = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 26))
            Text(targeted ? "Release to add" : "Drop to add to shelf").font(.system(size: 12, weight: .medium))
            Text("\(shelf.items.count) on shelf").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 24).fill(.black.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(targeted ? Color.blue : .white.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [6])))
        .padding(8)
        .onDrop(of: [.fileURL], isTargeted: $targeted) { shelf.handleDrop($0) }
    }
}
