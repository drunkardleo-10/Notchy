import SwiftUI

struct ShelfDropTiles: View {
    let zone: ShelfDropZone?

    var body: some View {
        HStack(spacing: 12) {
            tile("AirDrop", symbol: "dot.radiowaves.left.and.right", active: zone == .airDrop)
            tile("Shelf", symbol: "tray.and.arrow.down", active: zone == .shelf)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.15), value: zone)
    }

    private func tile(_ title: String, symbol: String, active: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
            Text(title)
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundStyle(.white.opacity(active ? 1 : 0.8))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(active ? 0.2 : 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(active ? 0.35 : 0.1), lineWidth: 1)
        )
        .scaleEffect(active ? 1.02 : 1)
    }
}
