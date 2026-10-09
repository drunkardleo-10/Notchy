import SwiftUI
import AppKit

struct PointerInput: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void = { _ in }
    var onDragChanged: (CGFloat) -> Void = { _ in }
    var onDragEnded: () -> Void = {}
    var onClick: (CGPoint) -> Void = { _ in }

    func makeNSView(context: Context) -> PointerInputView {
        let view = PointerInputView()
        apply(to: view)
        return view
    }

    func updateNSView(_ nsView: PointerInputView, context: Context) {
        apply(to: nsView)
    }

    private func apply(to view: PointerInputView) {
        view.onScroll = onScroll
        view.onDragChanged = onDragChanged
        view.onDragEnded = onDragEnded
        view.onClick = onClick
    }
}

final class PointerInputView: NSView {
    var onScroll: (CGFloat) -> Void = { _ in }
    var onDragChanged: (CGFloat) -> Void = { _ in }
    var onDragEnded: () -> Void = {}
    var onClick: (CGPoint) -> Void = { _ in }

    private var startX: CGFloat = 0
    private var dragging = false
    private let dragThreshold: CGFloat = 3

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        startX = event.locationInWindow.x
        dragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        let dx = event.locationInWindow.x - startX
        if !dragging && abs(dx) < dragThreshold { return }
        dragging = true
        onDragChanged(dx)
    }

    override func mouseUp(with event: NSEvent) {
        if dragging {
            onDragEnded()
        } else {
            onClick(convert(event.locationInWindow, from: nil))
        }
        dragging = false
    }

    override func scrollWheel(with event: NSEvent) {
        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY
        let delta = abs(dx) >= abs(dy) ? dx : dy
        onScroll(event.hasPreciseScrollingDeltas ? delta : delta * 8)
    }
}
