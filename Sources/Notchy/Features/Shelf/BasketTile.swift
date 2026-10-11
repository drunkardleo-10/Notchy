import SwiftUI

struct BasketTile: View {
    let item: ShelfItem
    let onSpawn: () -> Void
    @State private var spawned = false
    @State private var puff: Date?

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
    }

    var body: some View {
        Image(nsImage: item.icon)
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40)
            .padding(9)
            .background(shape.fill(Color.white.opacity(0.1)))
            .overlay(shape.strokeBorder(Color.white.opacity(0.22), lineWidth: 0.7))
            .scaleEffect(spawned ? 1 : 0.2)
            .offset(y: spawned ? 0 : 8)
            .opacity(spawned ? 1 : 0)
            .blur(radius: spawned ? 0 : 6)
            .overlay {
                if let puff {
                    SmokePuff(start: puff)
                }
            }
            .onAppear {
                puff = Date()
                onSpawn()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.58).delay(0.07)) { spawned = true }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64((SmokePuff.duration + 0.1) * 1_000_000_000))
                    puff = nil
                }
            }
    }
}
