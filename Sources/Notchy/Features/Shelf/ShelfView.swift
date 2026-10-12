import AppKit
import SwiftUI

struct ShelfView: View {
    @ObservedObject var shelf: ShelfStore
    let targeted: Bool
    let zone: ShelfDropZone?
    @State private var isTargeted = false
    @State private var status: String?
    @State private var dissolving: [UUID: Double] = [:]

    private var activeTargeted: Bool {
        targeted || isTargeted
    }

    var body: some View {
        Group {
            if targeted {
                ShelfDropTiles(zone: zone)
            } else if shelf.items.isEmpty {
                emptyState
            } else {
                tray
                    .overlay(alignment: .trailing) { actions }
            }
        }
        .padding(.top, 6)
        .overlay { dropHighlight }
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data, .item], isTargeted: $isTargeted) { providers in
            shelf.handleDrop(providers)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(activeTargeted ? Color.blue : Color.white.opacity(0.35))
            Text(activeTargeted ? "Release to hold on shelf" : "Nothing on the shelf")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            Text("Dropped files will wait here")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(shelf.items) { item in
                    ShelfItemView(
                        item: item,
                        shelf: shelf,
                        dissolveDelay: dissolving[item.id],
                        onFlash: flash,
                        onRemove: { dissolve([$0], stagger: 0) }
                    )
                    .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity), removal: .opacity))
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 96)
            .padding(.vertical, 10)
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: shelf.items.map(\.id))
        }
        .scrollClipDisabled()
        .frame(maxHeight: .infinity)
        .mask(TrayEdgeFade())
    }

    private var dropHighlight: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(Color.blue.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.blue.opacity(0.08)))
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .opacity(isTargeted && !targeted && !shelf.items.isEmpty ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: activeTargeted)
            .allowsHitTesting(false)
    }

    private var actions: some View {
        VStack(spacing: 8) {
            if let text = shelf.message ?? status {
                Text(text)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            if shelf.items.count > 1 {
                actionButton("Zip") { shelf.zip(shelf.items) }
            }
            actionButton("Clear") {
                dissolve(shelf.items, stagger: min(0.06, 0.5 / Double(max(shelf.items.count, 1))))
                flash("Cleared")
            }
        }
        .padding(.trailing, 20)
    }

    private func capsuleLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
            .contentShape(Capsule())
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { capsuleLabel(title) }
        .buttonStyle(PressScaleStyle())
    }

    private func dissolve(_ items: [ShelfItem], stagger: Double) {
        let fresh = items.filter { dissolving[$0.id] == nil }
        guard !fresh.isEmpty else { return }
        for (index, item) in fresh.enumerated() { dissolving[item.id] = Double(index) * stagger }
        let total = Double(fresh.count - 1) * stagger + Dissolve.duration
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                fresh.forEach { shelf.remove($0) }
                fresh.forEach { dissolving[$0.id] = nil }
            }
        }
    }

    private func flash(_ message: String) {
        withAnimation(.easeInOut(duration: 0.2)) { status = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.2)) { status = nil }
        }
    }
}
