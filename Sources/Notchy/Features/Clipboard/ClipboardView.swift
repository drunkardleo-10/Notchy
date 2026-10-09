import AppKit
import SwiftUI

struct ClipboardView: View {
    @ObservedObject var clipboard: ClipboardManager
    @State private var status: String?

    private var sorted: [ClipItem] {
        clipboard.items.sorted { $0.favorite && !$1.favorite }
    }

    var body: some View {
        Group {
            if clipboard.items.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    tray
                    actions
                }
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
                    ClipboardCardView(item: item, clipboard: clipboard, onFlash: flash)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .frame(maxHeight: .infinity)
    }

    private var actions: some View {
        VStack(spacing: 8) {
            if let status {
                Text(status)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
            Button {
                clipboard.clearUnfavorited()
            } label: {
                Text("Clear")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 24)
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
    let onFlash: (String) -> Void
    @State private var hovering = false

    private let cardWidth: CGFloat = 120
    private let previewHeight: CGFloat = 68

    var body: some View {
        VStack(spacing: 6) {
            preview
                .frame(width: cardWidth, height: previewHeight)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.45)))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(hovering ? 0.35 : 0.12), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) { favoriteBadge }
                .overlay(alignment: .topTrailing) { deleteButton }
                .overlay(alignment: .bottomTrailing) { ocrButton }

            Text(caption)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: cardWidth)
        }
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
            Button("Delete") { clipboard.delete(item) }
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
    private var favoriteBadge: some View {
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
    private var deleteButton: some View {
        if hovering {
            Button {
                clipboard.delete(item)
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
    private var ocrButton: some View {
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
