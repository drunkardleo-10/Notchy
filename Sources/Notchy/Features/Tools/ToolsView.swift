import SwiftUI

struct ToolsView: View {
    @ObservedObject var highAlert: HighAlertModel

    private static let durations: [(minutes: Int, label: String)] = [(0, "∞"), (30, "30m"), (60, "1h"), (120, "2h")]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundStyle(highAlert.active ? Color.orange : .white.opacity(0.6))
                Text("High Alert").font(.system(size: 13, weight: .semibold))
                Spacer()
                Toggle("", isOn: Binding(get: { highAlert.active }, set: { _ in highAlert.toggle() }))
                    .toggleStyle(.switch).labelsHidden().scaleEffect(0.8)
            }
            HStack(spacing: 6) {
                ForEach(Self.durations, id: \.minutes) { value, label in
                    Button {
                        highAlert.minutes = value
                        if highAlert.active { highAlert.start() }
                    } label: {
                        Text(label).font(.system(size: 11, weight: .medium))
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                            .background(highAlert.minutes == value ? Color.white.opacity(0.22) : .white.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
            Group {
                if highAlert.active, let end = highAlert.endsAt {
                    Text("Awake until \(end.formatted(date: .omitted, time: .shortened))")
                } else if highAlert.active {
                    Text("Mac stays awake until turned off")
                } else {
                    Text("Keep your Mac and display from sleeping")
                }
            }
            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}
