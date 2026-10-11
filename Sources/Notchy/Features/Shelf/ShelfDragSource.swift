import AppKit

@MainActor
final class ShelfDragSource: NSObject, NSDraggingSource {
    static let shared = ShelfDragSource()
    private var onCompleted: (() -> Void)?
    private var active = false

    func begin(url: URL, image: NSImage, onCompleted: @escaping () -> Void) {
        guard !active,
              let event = NSApp.currentEvent,
              event.type == .leftMouseDragged,
              let view = event.window?.contentView else { return }
        let side: CGFloat = 56
        let point = view.convert(event.locationInWindow, from: nil)
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        item.setDraggingFrame(NSRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side), contents: image)
        active = true
        self.onCompleted = onCompleted
        view.beginDraggingSession(with: [item], event: event, source: self)
    }

    nonisolated func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move] : .copy
    }

    nonisolated func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        MainActor.assumeIsolated {
            let completion = onCompleted
            onCompleted = nil
            active = false
            if !operation.isEmpty { completion?() }
        }
    }
}
