import SwiftUI
import AppKit
import UniformTypeIdentifiers
import QuickLookThumbnailing

struct ShelfView: View {
    @ObservedObject var shelf: ShelfStore
    let targeted: Bool
    @State private var isTargeted = false
    @State private var dissolving: [UUID: Double] = [:]

    private var activeTargeted: Bool {
        targeted || isTargeted
    }

    var body: some View {
        ZStack {
            if shelf.items.isEmpty {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        activeTargeted ? Color.blue : Color.white.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(activeTargeted ? Color.blue.opacity(0.12) : Color.white.opacity(0.03))
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(activeTargeted ? Color.blue : Color.white.opacity(0.7))

                            Text("Drop files here")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.85))

                            Text("Release to hold on shelf")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }
            } else {
                HStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(shelf.items) { item in
                                ShelfItemView(
                                    item: item,
                                    shelf: shelf,
                                    dissolveDelay: dissolving[item.id],
                                    onRemove: { dissolve([$0], stagger: 0) }
                                )
                                .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity), removal: .opacity))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: shelf.items.map(\.id))
                    }
                    .scrollClipDisabled()

                    VStack(spacing: 8) {
                        if let message = shelf.message {
                            Text(message)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.green)
                        }
                        if shelf.items.count > 1 {
                            Button {
                                shelf.zip(shelf.items)
                            } label: {
                                Image(systemName: "archivebox.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Color.white.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                            .help("Zip all")
                        }
                        Button {
                            dissolve(shelf.items, stagger: min(0.06, 0.5 / Double(max(shelf.items.count, 1))))
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                        .help("Clear shelf")
                    }
                    .frame(width: 44)
                    .padding(.trailing, 16)
                }
                .overlay {
                    if activeTargeted {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.blue.opacity(0.08)))
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data, .item], isTargeted: $isTargeted) { providers in
            shelf.handleDrop(providers)
        }
    }
}

extension ShelfView {
    fileprivate func dissolve(_ items: [ShelfItem], stagger: Double) {
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
}

struct ShelfItemView: View {
    let item: ShelfItem
    @ObservedObject var shelf: ShelfStore
    let dissolveDelay: Double?
    let onRemove: (ShelfItem) -> Void
    @State private var hovering = false
    @State private var thumbnail: NSImage?

    private let thumbWidth: CGFloat = 92
    private let thumbHeight: CGFloat = 60

    var body: some View {
        visual(hovering: hovering)
            .dissolving(after: dissolveDelay) { visual(hovering: false) }
        .padding(.top, 6)
        .onHover { hovering = $0 }
        .onDrag { NSItemProvider(object: item.url as NSURL) }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(item.url) }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(item.url) }
            Button("Reveal in Finder") { shelf.reveal(item) }
            Button("Copy") { shelf.copy(item) }
            Button("AirDrop…") { shelf.airDrop(item) }
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
            if let loaded = await Self.loadThumbnail(for: item.url, size: CGSize(width: thumbWidth * 2, height: thumbHeight * 2)) {
                thumbnail = loaded
            }
        }
    }

    private func visual(hovering: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.45))

                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: thumbWidth, height: thumbHeight)
                        .clipped()
                } else {
                    Image(nsImage: item.icon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                }
            }
            .frame(width: thumbWidth, height: thumbHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(hovering ? 0.35 : 0.12), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if hovering {
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
                }
            }
            .overlay(alignment: .bottom) {
                if hovering {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.blue))
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                        .shadow(color: .blue.opacity(0.4), radius: 3, y: 1)
                        .offset(y: 9)
                }
            }

            Text(item.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: thumbWidth + 10)
        }
    }

    private static func loadThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) {
            if let img = NSImage(contentsOf: url) {
                return img
            }
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
                    let image = NSImage(cgImage: cgImage, size: size)
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
