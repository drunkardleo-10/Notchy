import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var name: String { url.lastPathComponent }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
}

@MainActor
final class ShelfStore: ObservableObject {
    @Published var items: [ShelfItem] = []
    @Published var message: String?

    func add(_ urls: [URL]) {
        for url in urls where !items.contains(where: { $0.url == url }) {
            items.insert(ShelfItem(url: url), at: 0)
        }
    }

    func remove(_ item: ShelfItem) { items.removeAll { $0 == item } }
    func clear() { items.removeAll() }

    @discardableResult
    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                accepted = true
                _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                    guard let url else { return }
                    Task { @MainActor in self?.add([url]) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ||
                      provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) ||
                      provider.hasItemConformingToTypeIdentifier(UTType.item.identifier) ||
                      provider.hasItemConformingToTypeIdentifier("NSFilenamesPboardType") {
                let typeId = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ? UTType.fileURL.identifier :
                             (provider.hasItemConformingToTypeIdentifier("NSFilenamesPboardType") ? "NSFilenamesPboardType" :
                             (provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) ? UTType.url.identifier : UTType.item.identifier))
                accepted = true
                provider.loadItem(forTypeIdentifier: typeId, options: nil) { [weak self] item, _ in
                    if let paths = item as? [String] {
                        let urls = paths.map { URL(fileURLWithPath: $0) }
                        Task { @MainActor in self?.add(urls) }
                        return
                    } else if let paths = item as? NSArray as? [String] {
                        let urls = paths.map { URL(fileURLWithPath: $0) }
                        Task { @MainActor in self?.add(urls) }
                        return
                    }
                    let url: URL?
                    if let u = item as? URL {
                        url = u
                    } else if let u = item as? NSURL {
                        url = u as URL
                    } else if let d = item as? Data {
                        url = URL(dataRepresentation: d, relativeTo: nil) ?? URL(string: String(data: d, encoding: .utf8) ?? "")
                    } else if let s = item as? String {
                        url = URL(string: s) ?? URL(fileURLWithPath: s)
                    } else {
                        url = nil
                    }
                    guard let url else { return }
                    Task { @MainActor in self?.add([url]) }
                }
            }
        }
        return accepted
    }


    private func flash(_ text: String) {
        message = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if self.message == text { self.message = nil } }
    }

    nonisolated private static func freshOutputDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("notchy-out", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func isImage(_ item: ShelfItem) -> Bool {
        UTType(filenameExtension: item.url.pathExtension)?.conforms(to: .image) ?? false
    }

    func zip(_ targets: [ShelfItem]) {
        guard !targets.isEmpty else { return }
        let urls = targets.map(\.url)
        flash("Zipping…")
        DispatchQueue.global(qos: .userInitiated).async {
            let out = Self.freshOutputDir()
            var source = urls[0]
            var name = urls[0].lastPathComponent
            if urls.count > 1 {
                let stage = out.appendingPathComponent("Archive", isDirectory: true)
                try? FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
                for url in urls { try? FileManager.default.copyItem(at: url, to: stage.appendingPathComponent(url.lastPathComponent)) }
                source = stage
                name = "Archive"
            }
            let zip = out.appendingPathComponent(name + ".zip")
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            proc.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", source.path, zip.path]
            try? proc.run()
            proc.waitUntilExit()
            DispatchQueue.main.async {
                if proc.terminationStatus == 0 { self.add([zip]); self.flash("Zipped") } else { self.flash("Zip failed") }
            }
        }
    }

    func convert(_ item: ShelfItem, to type: UTType) {
        flash("Converting…")
        let url = item.url
        DispatchQueue.global(qos: .userInitiated).async {
            let ext = type == .png ? "png" : "jpg"
            let out = Self.freshOutputDir().appendingPathComponent(url.deletingPathExtension().lastPathComponent + "." + ext)
            var ok = false
            if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
               let dest = CGImageDestinationCreateWithURL(out as CFURL, type.identifier as CFString, 1, nil) {
                CGImageDestinationAddImageFromSource(dest, src, 0, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
                ok = CGImageDestinationFinalize(dest)
            }
            DispatchQueue.main.async {
                if ok { self.add([out]); self.flash("Converted to \(ext.uppercased())") } else { self.flash("Conversion failed") }
            }
        }
    }

    func reveal(_ item: ShelfItem) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }

    func copy(_ item: ShelfItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([item.url as NSURL])
    }

    func airDrop(_ item: ShelfItem) {
        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: [item.url])
    }
}
