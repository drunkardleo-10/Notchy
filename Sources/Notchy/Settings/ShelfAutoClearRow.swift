import SwiftUI

struct ShelfAutoClearRow: View {
    @AppStorage(Pref.shelfAutoClear) private var minutes = 0

    private static let options: [(label: String, minutes: Int)] = [
        ("Never", 0), ("After 5 minutes", 5), ("After 15 minutes", 15),
        ("After 30 minutes", 30), ("After 1 hour", 60), ("After 4 hours", 240), ("After 24 hours", 1440)
    ]

    private var currentLabel: String {
        Self.options.first { $0.minutes == minutes }?.label ?? "Never"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.mint.gradient)
                    .frame(width: 30, height: 30)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Auto-clear")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                Text("Remove shelf items after a set time")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Menu {
                ForEach(Self.options, id: \.minutes) { option in
                    Button(option.label) { minutes = option.minutes }
                }
            } label: {
                Text(currentLabel)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .fixedSize()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .padding(.leading, 22)
        .background(Color.white.opacity(0.03))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
