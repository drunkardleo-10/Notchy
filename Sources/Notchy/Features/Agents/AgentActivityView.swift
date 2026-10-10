import SwiftUI

enum AgentActivityLayout {
    static let sideWidth: CGFloat = 64
    static let rowHeight: CGFloat = 26

    static func size(notch: CGSize) -> CGSize {
        let base = NotchAccessoryLayout.size(notch: notch, leadingWidth: sideWidth, trailingWidth: sideWidth)
        return CGSize(width: base.width, height: base.height + rowHeight)
    }
}

struct AgentActivityView: View {
    let activity: AgentActivity
    let notch: CGSize

    private var headlineColor: Color {
        switch activity.state {
        case .done: Color(red: 0.45, green: 0.9, blue: 0.55)
        case .attention: Color(red: 1, green: 0.66, blue: 0.3)
        case .working: .white.opacity(0.78)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            NotchAccessory(
                notch: notch,
                leadingWidth: AgentActivityLayout.sideWidth,
                trailingWidth: AgentActivityLayout.sideWidth,
                leadingAlignment: .leading,
                trailingAlignment: .trailing
            ) {
                PixelMascot(pose: activity.pose, cell: 1.75)
                    .padding(.leading, 14)
                    .id(activity.pose)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            } trailing: {
                if activity.state == .done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(headlineColor)
                        .padding(.trailing, 28)
                } else if activity.activeCount > 0 {
                    Text("\(activity.activeCount)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(minWidth: 20, minHeight: 18)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                        .padding(.trailing, 28)
                }
            }

            HStack(spacing: 6) {
                Text(activity.headline)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(headlineColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: AgentActivityLayout.rowHeight - 4)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: activity)
    }
}

struct ClaudeSpark: View {
    var spinning = false
    var size: CGFloat = 16

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if spinning && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                AgentGlyph(id: "claude", size: size)
                    .rotationEffect(.degrees(t.truncatingRemainder(dividingBy: 6) * 60))
                    .scaleEffect(1 + 0.06 * sin(t * 3))
            }
        } else {
            AgentGlyph(id: "claude", size: size)
        }
    }
}
