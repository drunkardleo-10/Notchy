import AppKit
import SwiftUI
import UniformTypeIdentifiers
import QuickLookThumbnailing

struct ShelfItemView: View {
    let item: ShelfItem
    @ObservedObject var shelf: ShelfStore
    let dissolveDelay: Double?
    let onFlash: (String) -> Void
    let onRemove: (ShelfItem) -> Void
    @State private var hovering = false
    @State private var thumbnail: NSImage?

    private let cardWidth: CGFloat = 120
    private let previewHeight: CGFloat = 68

    var body: some View {
        visual(hovering: hovering)
            .dissolving(after: dissolveDelay) { visual(hovering: false) }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            shelf.copy(item)
            onFlash("Copied")
        }
        .simultaneousGesture(DragGesture(minimumDistance: 6).onChanged { _ in startDrag() })
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(item.url) }
            Button("Reveal in Finder") { shelf.reveal(item) }
            Button("Copy") {
                shelf.copy(item)
                onFlash("Copied")
            }
            Menu("Share") { ShelfShareMenuItems(shelf: shelf, targets: [item]) }
            Divider()
            Button("Zip") { shelf.zip([item]) }
            if shelf.isImage(item) {
                Button("Convert to PNG") { shelf.convert(item, to: .png) }
                Button("Convert to JPEG") { shelf.convert(item, to: .jpeg) }
            }
            Divider()
            Button("Remove") { onRemove(item) }
        }
        .task(id: item.url) {
            thumbnail = await Self.loadThumbnail(for: item.url, size: CGSize(width: cardWidth * 2, height: previewHeight * 2))
        }
    }

    private func startDrag() {
        let item = item
        let shelf = shelf
        ShelfDragSource.shared.begin(url: item.url, image: thumbnail ?? item.icon) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { shelf.removeDraggedOut(item) }
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
                .overlay(alignment: .topTrailing) { removeButton(hovering) }

            Text(item.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: cardWidth)
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .scaledToFit()
                .frame(width: cardWidth, height: previewHeight)
        } else {
            Image(nsImage: item.icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 36, height: 36)
        }
    }

    private func removeButton(_ hovering: Bool) -> some View {
        Button {
            onRemove(item)
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
        .opacity(hovering ? 1 : 0)
        .allowsHitTesting(hovering)
        .animation(.easeOut(duration: 0.1), value: hovering)
    }

    private static func loadThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image),
           let image = await ClipThumbnailCache.load(url, key: url.path, maxPixel: Int(size.width)) {
            return image
        }
        let scale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2.0 }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
                if let cgImage = thumbnail?.cgImage {
                    continuation.resume(returning: NSImage(cgImage: cgImage, size: size))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
