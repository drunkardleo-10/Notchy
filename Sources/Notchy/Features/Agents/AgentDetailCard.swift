import SwiftUI

enum AgentDetailLayout {
    static let width: CGFloat = 168
    static let height: CGFloat = 78
    static let cornerRadius: CGFloat = 22
}

struct AgentDetailCard: View, Animatable {
    let activity: AgentActivity
    var progress: CGFloat
    let dotDiameter: CGFloat
    let travel: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private var tint: Color {
        switch activity.state {
        case .done: Color(red: 0.45, green: 0.9, blue: 0.55)
        case .attention: Color(red: 1, green: 0.66, blue: 0.3)
        case .working: MascotSprites.claudeOrange
        }
    }

    private var statusText: String {
        switch activity.state {
        case .done: "Done"
        case .attention: "Needs input"
        case .working: "Working"
        }
    }

    private var countText: String {
        activity.activeCount == 1 ? "1 session" : "\(activity.activeCount) sessions"
    }

    private func lerp(_ from: CGFloat, _ to: CGFloat) -> CGFloat { from + (to - from) * progress }

    private var contentOpacity: Double { Double(max(0, min(1, (progress - 0.45) / 0.45))) }

    var body: some View {
        content
            .frame(width: AgentDetailLayout.width, height: AgentDetailLayout.height)
            .opacity(contentOpacity)
            .blur(radius: (1 - min(1, progress)) * 4)
            .frame(width: lerp(dotDiameter, AgentDetailLayout.width), height: lerp(dotDiameter, AgentDetailLayout.height))
            .background { DetailGlass(cornerRadius: lerp(dotDiameter / 2, AgentDetailLayout.cornerRadius)) }
            .clipped()
            .frame(width: AgentDetailLayout.width, height: AgentDetailLayout.height)
            .offset(y: -(1 - progress) * travel)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                PixelMascot(pose: activity.pose, cell: 1)
                Spacer(minLength: 0)
                Text(statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(activity.project)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
            Text(countText)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
