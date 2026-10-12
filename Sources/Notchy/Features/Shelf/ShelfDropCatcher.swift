import AppKit

enum ShelfDropZone {
    case airDrop, shelf
}

private final class ShelfDropView: NSView {
    var onTarget: ((Bool) -> Void)?
    var onZone: ((ShelfDropZone?) -> Void)?
    var onDrop: (([URL], ShelfDropZone) -> Void)?

    private func zone(for sender: NSDraggingInfo) -> ShelfDropZone {
        convert(sender.draggingLocation, from: nil).x < bounds.midX ? .airDrop : .shelf
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
    }

    required init?(coder: NSCoder) { nil }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onTarget?(true)
        onZone?(zone(for: sender))
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        onZone?(zone(for: sender))
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTarget?(false)
        onZone?(nil)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onTarget?(false)
        onZone?(nil)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        onDrop?(urls, zone(for: sender))
        return true
    }
}

@MainActor
final class ShelfDropCatcher {
    private let panel: NSPanel
    private var hideWork: DispatchWorkItem?

    init(onTarget: @escaping (Bool) -> Void, onZone: @escaping (ShelfDropZone?) -> Void, onDrop: @escaping ([URL], ShelfDropZone) -> Void) {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.01)
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        let view = ShelfDropView()
        view.onTarget = onTarget
        view.onZone = onZone
        view.onDrop = onDrop
        panel.contentView = view
    }

    func show(frame: NSRect) {
        hideWork?.cancel()
        hideWork = nil
        if panel.frame != frame { panel.setFrame(frame, display: false) }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func hide(after delay: TimeInterval = 0, completion: (() -> Void)? = nil) {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.hideWork = nil
            self?.panel.orderOut(nil)
            completion?()
        }
        hideWork = work
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        } else {
            work.perform()
        }
    }
}
