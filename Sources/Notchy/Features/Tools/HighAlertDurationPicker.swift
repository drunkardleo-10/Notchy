import SwiftUI

struct HighAlertDurationPicker: View {
    let selection: Int
    let tint: Color
    let onSelect: (Int) -> Void
    @Namespace private var namespace

    private static let durations: [(minutes: Int, label: String)] = [(0, "∞"), (30, "30m"), (60, "1h"), (120, "2h")]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Self.durations, id: \.minutes) { value, label in
                Button {
                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.94)) { onSelect(value) }
                } label: {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection == value ? tint : .white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background {
                            if selection == value {
                                Capsule()
                                    .fill(tint.opacity(0.18))
                                    .matchedGeometryEffect(id: "alertDuration", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(PressScaleStyle())
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.08), in: Capsule())
    }
}
