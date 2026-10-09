import AppKit
import Vision

struct ClipItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var date = Date()
    var text: String?
    var imageFile: String?
    var favorite = false
    var sourceApp: String?
}

@MainActor
final class ClipboardManager: ObservableObject {
    @Published private(set) var items: [ClipItem] = []

    private let pasteboard = NSPasteboard.general
    private var lastChange: Int
    private var timer: Timer?
    private let storeURL: URL
    private let imageDir: URL

    private static let blockedSources = ["1password", "bitwarden", "keychain", "lastpass", "dashlane"]

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let base = appSupport.appendingPathComponent("notchy", isDirectory: true)
        imageDir = base.appendingPathComponent("clips", isDirectory: true)
        try? FileManager.default.createDirectory(at: imageDir, withIntermediateDirectories: true)
        storeURL = base.appendingPathComponent("clipboard.json")
        lastChange = pasteboard.changeCount
        if let data = try? Data(contentsOf: storeURL),
           let saved = try? JSONDecoder().decode([ClipItem].self, from: data) {
            items = saved
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    private func poll() {
        guard pasteboard.changeCount != lastChange else { return }
        lastChange = pasteboard.changeCount
        guard Pref.bool(Pref.clipboard) else { return }

        let types = pasteboard.types?.map(\.rawValue) ?? []
        if types.contains("org.nspasteboard.ConcealedType") || types.contains("org.nspasteboard.TransientType") { return }
        let front = NSWorkspace.shared.frontmostApplication
        let frontID = front?.bundleIdentifier?.lowercased() ?? ""
        if Self.blockedSources.contains(where: frontID.contains) { return }

        if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            insert(ClipItem(text: text, sourceApp: front?.localizedName))
        } else if let image = NSImage(pasteboard: pasteboard), let png = Self.pngData(image) {
            let name = UUID().uuidString + ".png"
            try? png.write(to: imageDir.appendingPathComponent(name))
            insert(ClipItem(imageFile: name, sourceApp: front?.localizedName))
        }
    }

    private func insert(_ item: ClipItem) {
        if let text = item.text, let idx = items.firstIndex(where: { $0.text == text }) {
            var existing = items.remove(at: idx)
            existing.date = Date()
            items.insert(existing, at: 0)
        } else {
            items.insert(item, at: 0)
        }
        trim()
        save()
    }

    private func trim() {
        let limit = max(5, UserDefaults.standard.integer(forKey: Pref.clipboardLimit))
        var kept = 0
        items = items.filter { item in
            if item.favorite { return true }
            kept += 1
            if kept > limit { removeImage(item); return false }
            return true
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: storeURL) }
    }

    private func removeImage(_ item: ClipItem) {
        if let f = item.imageFile { try? FileManager.default.removeItem(at: imageDir.appendingPathComponent(f)) }
    }

    func imageURL(for item: ClipItem) -> URL? {
        item.imageFile.map { imageDir.appendingPathComponent($0) }
    }

    func image(for item: ClipItem) -> NSImage? {
        item.imageFile.flatMap { NSImage(contentsOf: imageDir.appendingPathComponent($0)) }
    }

    func copy(_ item: ClipItem) {
        pasteboard.clearContents()
        if let text = item.text { pasteboard.setString(text, forType: .string) }
        else if let img = image(for: item) { pasteboard.writeObjects([img]) }
        lastChange = pasteboard.changeCount
    }

    func toggleFavorite(_ item: ClipItem) {
        guard let i = items.firstIndex(of: item) else { return }
        items[i].favorite.toggle()
        save()
    }

    func delete(_ item: ClipItem) {
        removeImage(item)
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearUnfavorited() {
        items.filter { !$0.favorite }.forEach(removeImage)
        items.removeAll { !$0.favorite }
        save()
    }

    func ocr(_ item: ClipItem, completion: @escaping (Bool) -> Void) {
        guard let cg = image(for: item)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(false); return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try? VNImageRequestHandler(cgImage: cg).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            DispatchQueue.main.async {
                if text.isEmpty { completion(false); return }
                self.pasteboard.clearContents()
                self.pasteboard.setString(text, forType: .string)
                completion(true)
            }
        }
    }

    private static func pngData(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
