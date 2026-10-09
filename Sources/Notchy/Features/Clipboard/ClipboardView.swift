import AppKit
import SwiftUI

struct ClipboardView: View {
    @ObservedObject var clipboard: ClipboardManager
    @State private var status: String?
    @State private var dissolving: [UUID: Double] = [:]

    private var sorted: [ClipItem] {
        clipboard.items.sorted { $0.favorite && !$1.favorite }
    }

    var body: some View {
        Group {
            if clipboard.items.isEmpty {
                emptyState
            } else {
                tray
                    .overlay(alignment: .trailing) { actions }
            }
        }
        .padding(.top, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
            Text("Nothing copied yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            Text("Copied text and images will appear here")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(sorted) { item in
                    ClipboardCardView(
                        item: item,
                        clipboard: clipboard,
                        dissolveDelay: dissolving[item.id],
                        onFlash: flash,
                        onDelete: { dissolve([$0], stagger: 0) }
                    )
                    .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity), removal: .opacity))
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 96)
            .padding(.vertical, 10)
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: sorted.map(\.id))
        }
        .scrollClipDisabled()
        .frame(maxHeight: .infinity)
        .mask(edgeFade)
    }

    private var edgeFade: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: 12)
            Rectangle().fill(.black)
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 90)
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            if let status {
                Text(status)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            Button {
                let doomed = sorted.filter { !$0.favorite }
                dissolve(doomed, stagger: min(0.06, 0.5 / Double(max(doomed.count, 1))))
                flash("Cleared")
            } label: {
                Text("Clear")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
                    .contentShape(Capsule())
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(.trailing, 20)
    }

    private func dissolve(_ items: [ClipItem], stagger: Double) {
        let fresh = items.filter { dissolving[$0.id] == nil }
        guard !fresh.isEmpty else { return }
        for (index, item) in fresh.enumerated() { dissolving[item.id] = Double(index) * stagger }
        let total = Double(fresh.count - 1) * stagger + Dissolve.duration
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                fresh.forEach { clipboard.delete($0) }
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

struct ClipboardCardView: View {
    let item: ClipItem
    @ObservedObject var clipboard: ClipboardManager
    let dissolveDelay: Double?
    let onFlash: (String) -> Void
    let onDelete: (ClipItem) -> Void
    @State private var hovering = false

    private let cardWidth: CGFloat = 120
    private let previewHeight: CGFloat = 68

    var body: some View {
        visual(hovering: hovering)
            .dissolving(after: dissolveDelay) { visual(hovering: false) }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            clipboard.copy(item)
            onFlash("Copied")
        }
        .onDrag { dragProvider }
        .contextMenu {
            Button("Copy") {
                clipboard.copy(item)
                onFlash("Copied")
            }
            Button(item.favorite ? "Unfavorite" : "Favorite") { clipboard.toggleFavorite(item) }
            Divider()
            Button("Delete") { onDelete(item) }
        }
    }

    private func visual(hovering: Bool) -> some View {
        VStack(spacing: 6) {
            preview
                .frame(width: cardWidth, height: previewHeight)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.45)))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(hovering ? 0.35 : 0.12), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) { favoriteBadge(hovering) }
                .overlay(alignment: .topTrailing) { deleteButton(hovering) }
                .overlay(alignment: .bottomTrailing) { ocrButton(hovering) }

            Text(caption)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: cardWidth)
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let text = item.text {
            Text(text)
                .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
        } else if let url = clipboard.imageURL(for: item) {
            ClipThumbnailView(url: url, key: item.id.uuidString)
                .frame(width: cardWidth, height: previewHeight)
        }
    }

    private var caption: String {
        if let app = item.sourceApp, !app.isEmpty { return app }
        return item.text != nil ? "Text" : "Image"
    }

    private var dragProvider: NSItemProvider {
        if let text = item.text { return NSItemProvider(object: text as NSString) }
        if let url = clipboard.imageURL(for: item), let provider = NSItemProvider(contentsOf: url) { return provider }
        return NSItemProvider()
    }

    @ViewBuilder
    private func favoriteBadge(_ hovering: Bool) -> some View {
        if item.favorite || hovering {
            Button {
                clipboard.toggleFavorite(item)
            } label: {
                Image(systemName: item.favorite ? "star.fill" : "star")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(item.favorite ? Color.yellow : Color.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color(white: 0.15).opacity(0.95)))
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .offset(x: -6, y: -6)
        }
    }

    @ViewBuilder
    private func deleteButton(_ hovering: Bool) -> some View {
        if hovering {
            Button {
                onDelete(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color(white: 0.15).opacity(0.95)))
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
        }
    }

    @ViewBuilder
    private func ocrButton(_ hovering: Bool) -> some View {
        if item.imageFile != nil && hovering {
            Button {
                clipboard.ocr(item) { onFlash($0 ? "Text copied" : "No text found") }
            } label: {
                Text("OCR")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
            }
            .buttonStyle(.plain)
            .padding(5)
        }
    }
}
