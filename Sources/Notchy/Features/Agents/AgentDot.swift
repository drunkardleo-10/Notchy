import SwiftUI

struct AgentDotView: View {
    let pose: MascotPose?
    let active: Bool
    let activity: AgentActivity?
    let detailOpen: Bool
    let hovering: Bool
    let anchorWidth: CGFloat
    let notchHeight: CGFloat

    @State private var progress: CGFloat = 0
    @State private var pendingDetach: Task<Void, Never>?
    @State private var detailProgress: CGFloat = 0
    @State private var lastActivity: AgentActivity?
    @State private var lastPose: MascotPose = .thinking

    private var mascot: some View {
        let shown = pose ?? lastPose
        let cell: CGFloat = 0.75
        let box = MascotSprites.bounds(for: shown)
        let dx = (CGFloat(MascotSprites.columns) / 2 - box.midX) * cell
        let dy = (CGFloat(MascotSprites.rows) / 2 - box.midY) * cell
        return PixelMascot(pose: shown, cell: cell)
            .offset(x: dx, y: dy)
    }

    private var diameter: CGFloat { FocusDotLayout.diameter(notchHeight: notchHeight) }

    private var detailOffset: CGSize {
        let dotCenter = -(FocusDotLayout.gap + diameter / 2)
        return CGSize(width: dotCenter - AgentDetailLayout.width / 2, height: notchHeight + 4)
    }

    private var detailTravel: CGFloat {
        (detailOffset.height + AgentDetailLayout.height / 2) - notchHeight / 2
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            dot
            if detailProgress > 0.001, let shown = activity ?? lastActivity {
                AgentDetailCard(
                    activity: shown,
                    progress: detailProgress,
                    dotDiameter: diameter,
                    travel: detailTravel
                )
                .offset(detailOffset)
            }
        }
        .onChange(of: detailOpen) { _, open in
            withAnimation(NotchAnimation.spring(response: 0.42, dampingFraction: 0.82)) {
                detailProgress = open && active ? 1 : 0
            }
        }
        .onChange(of: active) { _, isActive in
            if !isActive { detailProgress = 0 }
        }
        .onChange(of: activity) { _, new in
            if let new { lastActivity = new }
        }
    }

    private var dot: some View {
        Color.clear
            .frame(width: anchorWidth, height: notchHeight)
            .overlay(alignment: .topLeading) {
                FocusDotLayer(
                    progress: progress,
                    hover: hovering ? 1 : 0,
                    anchorWidth: anchorWidth,
                    notchHeight: notchHeight,
                    content: mascot
                        .scaleEffect(x: -1)
                )
                .fixedSize()
            }
            .scaleEffect(x: -1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .animation(NotchAnimation.spring(response: 0.28, dampingFraction: 0.72), value: hovering)
            .onAppear { settle(animated: false) }
            .onChange(of: active) { _, _ in settle(animated: true) }
            .onChange(of: pose) { _, new in
                if let new { lastPose = new }
            }
    }

    private func settle(animated: Bool) {
        pendingDetach?.cancel()
        let target: CGFloat = active ? 1 : 0
        guard animated else {
            progress = target
            return
        }
        guard active else {
            withAnimation(NotchAnimation.spring(response: 0.34, dampingFraction: 0.92)) { progress = 0 }
            return
        }
        pendingDetach = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(520))
            guard !Task.isCancelled else { return }
            withAnimation(NotchAnimation.spring(response: 0.52, dampingFraction: 0.7)) { progress = 1 }
        }
    }
}
