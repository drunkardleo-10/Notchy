import SwiftUI

struct ToolsView: View {
    @ObservedObject var highAlert: HighAlertModel

    private var statusText: String {
        if highAlert.active, let end = highAlert.endsAt {
            return "Awake until \(end.formatted(date: .omitted, time: .shortened))"
        }
        return highAlert.active ? "Mac stays awake" : "Keep Mac and display awake"
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                toggleButton

                VStack(alignment: .leading, spacing: 2) {
                    Text("High Alert")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(highAlert.active ? Color.orange : .white.opacity(0.5))
                        .contentTransition(.opacity)
                }
                .lineLimit(1)

                Spacer(minLength: 12)

                actionPill
            }
            .padding(.horizontal, 4)

            HighAlertDurationPicker(selection: highAlert.minutes, tint: .orange) { value in
                highAlert.minutes = value
                if highAlert.active { highAlert.start() }
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: highAlert.active)
    }

    private var toggleButton: some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.94)) { highAlert.toggle() }
        } label: {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(highAlert.active ? Color.orange : .white.opacity(0.85))
                .symbolEffect(.pulse, isActive: highAlert.active)
                .frame(width: 40, height: 40)
                .background((highAlert.active ? Color.orange.opacity(0.28) : Color.white.opacity(0.16)), in: Circle())
        }
        .buttonStyle(PressScaleStyle())
    }

    private var actionPill: some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.94)) { highAlert.toggle() }
        } label: {
            Text(highAlert.active ? "Turn Off" : "Turn On")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(highAlert.active ? .white.opacity(0.85) : Color.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background((highAlert.active ? Color.white.opacity(0.14) : Color.orange.opacity(0.18)), in: Capsule())
                .contentTransition(.interpolate)
        }
        .buttonStyle(PressScaleStyle())
    }
}
