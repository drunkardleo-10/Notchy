import SwiftUI

struct ShortcutsView: View {
    @ObservedObject var shortcuts: ShortcutsModel

    var body: some View {
        Group {
            if shortcuts.loaded && shortcuts.names.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "bolt.slash").font(.system(size: 22))
                    Text("No Shortcuts found").font(.system(size: 12))
                    Text("Create one in the Shortcuts app").font(.system(size: 10))
                }
                .foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 4) {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], spacing: 6) {
                            ForEach(shortcuts.names, id: \.self) { name in
                                Button { shortcuts.run(name) } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundStyle(.yellow)
                                        Text(name).font(.system(size: 11)).lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 6)
                                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if let status = shortcuts.status {
                        Text(status).font(.system(size: 10)).foregroundStyle(.green)
                    }
                }
            }
        }
        .onAppear { shortcuts.load() }
    }
}
