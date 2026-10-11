import AppKit
import SwiftUI

@MainActor
final class StatusItemIcon: NSObject {
    private weak var button: NSStatusBarButton?
    private var timer: Timer?
    private var monitor: Any?
    private var frame = 0
    private let idle: NSImage?
    private let wave: [NSImage?]

    init(button: NSStatusBarButton) {
        self.button = button
        idle = Self.render(pose: .idle, frame: 0)
        wave = (0..<NotchyMascotSprites.frameCount(for: .wave)).map { Self.render(pose: .wave, frame: $0) }
        super.init()
        button.image = idle
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluateHover() }
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    var hasIcon: Bool { idle != nil }

    private func evaluateHover() {
        guard let frame = button?.window?.frame else { return }
        let inside = frame.contains(NSEvent.mouseLocation)
        if inside && timer == nil {
            startWaving()
        } else if !inside && timer != nil {
            stopWaving()
        }
    }

    private func startWaving() {
        frame = 0
        step()
        timer = Timer.scheduledTimer(withTimeInterval: NotchyMascotSprites.frameDuration(for: .wave), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
    }

    private func stopWaving() {
        timer?.invalidate()
        timer = nil
        button?.image = idle
    }

    private func step() {
        button?.image = wave[frame % wave.count]
        frame += 1
    }

    private static func render(pose: NotchyPose, frame: Int) -> NSImage? {
        let side = CGFloat(NotchyMascotSprites.columns)
        let renderer = ImageRenderer(content: NotchyMascot(pose: pose, cell: 1, animated: false, frame: frame))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.size = NSSize(width: side, height: side)
        image.isTemplate = false
        image.accessibilityDescription = "notchy"
        return image
    }
}
