import SwiftUI

struct ToolsView: View {
    @ObservedObject var highAlert: HighAlertModel
    @State private var category = 0
    @State private var status: String?

    private static let categories: [(icon: String, emojis: String)] = [
        ("😀", "😀😃😄😁😆😅😂🤣😊😇🙂😉😍🥰😘😋😎🤩🥳😏😒😞😔😢😭😤😡🤯😱🤔🤫🙄😴🤮🤒🥵🥶🤗"),
        ("👍", "👍👎👏🙌🙏💪👋🤝✌️🤞👌🤌🫶👀🧠❤️🧡💛💚💙💜🖤💔🔥✨🎉💯"),
        ("🐶", "🐶🐱🐭🐹🐰🦊🐻🐼🐨🐯🦁🐸🐵🐔🐧🦄🐝🦋🌸🌹🌲🌈☀️🌙⭐🌊🍀"),
        ("🍕", "🍎🍌🍇🍓🍕🍔🍟🌮🍣🍩🍪🎂🍫🥑🍿☕🍺🍷🥂🧋"),
        ("💡", "💡📱💻⌨️🖥️📷🎧🎮⚽🏀🚀✈️🚗🏠💰🎁📌✅❌⚠️💬📎🔒🔑"),
    ]

    var body: some View {
        HStack(spacing: 14) {
            highAlertCard.frame(width: 170)
            emojiPicker
        }
    }

    private var highAlertCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cup.and.saucer.fill").foregroundStyle(highAlert.active ? Color.orange : .white.opacity(0.6))
                Text("High Alert").font(.system(size: 12, weight: .semibold))
                Spacer()
                Toggle("", isOn: Binding(get: { highAlert.active }, set: { _ in highAlert.toggle() }))
                    .toggleStyle(.switch).labelsHidden().scaleEffect(0.7)
            }
            HStack(spacing: 4) {
                ForEach([(0, "∞"), (30, "30m"), (60, "1h"), (120, "2h")], id: \.0) { value, label in
                    Button { highAlert.minutes = value; if highAlert.active { highAlert.start() } } label: {
                        Text(label).font(.system(size: 10, weight: .medium))
                            .frame(maxWidth: .infinity).padding(.vertical, 4)
                            .background(highAlert.minutes == value ? Color.white.opacity(0.22) : .white.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 6))
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
            .font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private var emojiPicker: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(Self.categories.indices, id: \.self) { i in
                    Button { category = i } label: {
                        Text(Self.categories[i].icon).font(.system(size: 13))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(category == i ? Color.white.opacity(0.2) : .clear, in: Capsule())
                    }.buttonStyle(.plain)
                }
                Spacer()
                if let status { Text(status).font(.system(size: 10)).foregroundStyle(.green) }
            }
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 2), count: 10), spacing: 2) {
                    ForEach(Array(Self.categories[category].emojis.enumerated()), id: \.offset) { _, e in
                        Button { copy(String(e)) } label: { Text(String(e)).font(.system(size: 20)) }
                            .buttonStyle(.plain).frame(width: 30, height: 28)
                    }
                }
            }
        }
    }

    private func copy(_ emoji: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(emoji, forType: .string)
        status = "Copied \(emoji)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { status = nil }
    }
}
