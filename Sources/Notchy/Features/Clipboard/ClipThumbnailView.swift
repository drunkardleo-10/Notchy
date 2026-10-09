import AppKit
import ImageIO
import SwiftUI

enum ClipThumbnailCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func cached(_ key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }

    static func load(_ url: URL, key: String, maxPixel: Int) async -> NSImage? {
        if let hit = cached(key) { return hit }
        let cgImage = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }.value
        guard let cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cache.setObject(image, forKey: key as NSString)
        return image
    }
}

struct ClipThumbnailView: View {
    let url: URL
    let key: String
    @State private var image: NSImage?

    init(url: URL, key: String) {
        self.url = url
        self.key = key
        _image = State(initialValue: ClipThumbnailCache.cached(key))
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Color.clear
            }
        }
        .task(id: key) {
            if image == nil { image = await ClipThumbnailCache.load(url, key: key, maxPixel: 120) }
        }
    }
}
