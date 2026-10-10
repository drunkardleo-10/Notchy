import SwiftUI

struct LockWidgetsView: View {
    @ObservedObject var model: LockWidgetsModel
    @State private var shown = false

    var body: some View {
        LockWidgetsRow(items: model.items)
            .opacity(shown ? 1 : 0)
            .blur(radius: shown ? 0 : 6)
            .offset(y: shown ? 0 : 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.25)) { shown = true }
            }
    }
}

struct LockWidgetsRow: View {
    let items: [LockWidgetItem]
    var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: 30 * scale) {
            ForEach(items) { item in
                LockWidgetChip(item: item, scale: scale)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .shadow(color: .black.opacity(0.22), radius: 8 * scale, y: 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: items)
    }
}

struct LockWidgetChip: View {
    let item: LockWidgetItem
    var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: 8 * scale) {
            Image(systemName: item.icon)
                .font(.system(size: 17 * scale, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 6 * scale) {
                Text(item.value)
                    .foregroundStyle(.white.opacity(0.96))
                if let label = item.label {
                    Text(label)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .font(.system(size: 19 * scale, weight: .semibold))
            .lineLimit(1)
        }
        .fixedSize()
    }
}
