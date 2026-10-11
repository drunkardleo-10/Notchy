import SwiftUI

struct BasketView: View {
    static let glassSize = CGSize(width: 240, height: 130)
    static let inset = EdgeInsets(top: 50, leading: 20, bottom: 20, trailing: 20)
    static var panelSize: CGSize {
        CGSize(width: glassSize.width + inset.leading + inset.trailing,
               height: glassSize.height + inset.top + inset.bottom)
    }

    @ObservedObject var shelf: ShelfStore
    let onSpawn: () -> Void
    @State private var targeted = false

    var body: some View {
        ZStack {
            BasketSurface(targeted: targeted)
            content
        }
        .frame(width: Self.glassSize.width, height: Self.glassSize.height)
        .onDrop(of: [.fileURL], isTargeted: $targeted) { shelf.handleDrop($0) }
        .scaleEffect(targeted ? 1.03 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: targeted)
        .padding(Self.inset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        if shelf.items.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 28, weight: .light))
                    .scaleEffect(targeted ? 1.3 : 1)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: targeted)
                caption
            }
            .foregroundStyle(.white)
        } else {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    ForEach(Array(shelf.items.prefix(3))) { item in
                        BasketTile(item: item, onSpawn: onSpawn)
                            .transition(.asymmetric(insertion: .identity, removal: .opacity))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: shelf.items.map(\.id))
                caption
            }
            .foregroundStyle(.white)
        }
    }

    private var caption: some View {
        Text(targeted ? "Release to add" : shelf.items.isEmpty ? "Drop to add to shelf" : "\(shelf.items.count) on shelf")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(targeted ? 0.95 : 0.6))
            .contentTransition(.opacity)
            .animation(.easeOut(duration: 0.15), value: targeted)
    }
}
