import AppKit
import SwiftUI

struct QueueTrack: Identifiable, Equatable {
    let id: String
    var title: String
    var artist: String
    var artwork: NSImage?
    var artworkURL: String?
    var symbol: String
    var accent: Color
}

@MainActor
final class MediaController: ObservableObject {
    @Published var title = ""
    @Published var artist = ""
    @Published var isPlaying = false
    @Published var artwork: NSImage? {
        didSet { artworkTint = artwork.map(Self.sampleArtworkColor) ?? Color(white: 0.82) }
    }
    @Published private(set) var artworkTint = Color(white: 0.82)
    @Published var hasTrack = false
    @Published var sourceLabel = ""
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var shuffleOn = false
    @Published var repeatOn = false
    @Published var canShuffle = false
    @Published var queueTracks: [QueueTrack] = []
    @Published var queueSupported = false
    @Published var lyrics = LyricsService()

    private var lastFetchedTrack = ""

    private(set) var positionDate = Date()

    func currentPosition(at date: Date = Date()) -> Double {
        guard isPlaying, duration > 0 else { return position }
        let elapsed = max(0, date.timeIntervalSince(positionDate))
        return min(duration, position + elapsed)
    }

    private var native: (app: String, parts: [String])?
    private var browserTrack: BrowserTrack?
    private var activeIsBrowser = false
    private var browserBusy = false
    private var artworkURL: String?
    private var artworkTask: URLSessionDataTask?
    private var requestedMusicArtworkTrack: String?
    private var timers: [Timer] = []
    private let controlQueue = DispatchQueue(label: "com.notchy.mediaControl", qos: .userInitiated)
    private var pendingPlayPauseWorkItem: DispatchWorkItem?
    private var lastActionTime: Date = .distantPast
    private var refreshWorkItem: DispatchWorkItem?
    private var nativeBusy = false
    private var nativePending = false
    private var queryEpoch: Int = 0
    private var desiredPlayingState: Bool = false
    private var lastDispatchedState: Bool?
    private var lastDispatchedTime: Date = .distantPast
    private var pendingPlayPauseDispatch: DispatchWorkItem?

    private typealias MRMediaRemoteSendCommandFunc = @convention(c) (Int, AnyObject?) -> Void
    private static let sendCommandFunc: MRMediaRemoteSendCommandFunc? = {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
              let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) else {
            return nil
        }
        return unsafeBitCast(ptr, to: MRMediaRemoteSendCommandFunc.self)
    }()

    static func sendMediaRemoteCommand(_ command: Int) {
        sendCommandFunc?(command, nil)
    }

    private static let players = [("Spotify", "com.spotify.client"), ("Music", "com.apple.Music")]

    nonisolated(unsafe) private static let imageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 150
        cache.totalCostLimit = 60 * 1024 * 1024
        return cache
    }()

    nonisolated private static let artworkSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 25 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)
        config.timeoutIntervalForRequest = 8
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config)
    }()

    init() {
        let t1 = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshNative() }
        }
        RunLoop.main.add(t1, forMode: .common)
        timers.append(t1)

        let t2 = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshBrowser() }
        }
        RunLoop.main.add(t2, forMode: .common)
        timers.append(t2)

        let t3 = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshBrowserAudioState() }
        }
        RunLoop.main.add(t3, forMode: .common)
        timers.append(t3)

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshNative() }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshNative() }
        }
    }


    private func refreshNative() {
        guard Pref.bool(Pref.media) else {
            AudioVisualizer.shared.follow(bundleIdentifiers: [], isPlaying: false)
            return
        }
        if nativeBusy {
            nativePending = true
            return
        }
        nativeBusy = true
        let epoch = queryEpoch
        let running = Self.players.filter { !NSRunningApplication.runningApplications(withBundleIdentifier: $0.1).isEmpty }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var best: (app: String, parts: [String])?
            for (name, _) in running {
                guard let parts = Self.query(name) else { continue }
                if best == nil || parts[0] == "playing" { best = (name, parts) }
                if parts[0] == "playing" { break }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.nativeBusy = false
                if self.nativePending {
                    self.nativePending = false
                    self.refreshNative()
                }
                guard self.queryEpoch == epoch else { return }

                if Date().timeIntervalSince(self.lastActionTime) < 1.0, var b = best {
                    if !self.activeIsBrowser {
                        b.parts[0] = self.desiredPlayingState ? "playing" : "paused"
                        best = b
                    }
                } else if let b = best {
                    let reported = b.parts[0] == "playing"
                    if !self.activeIsBrowser {
                        self.desiredPlayingState = reported
                        self.lastDispatchedState = reported
                    }
                }

                self.native = best
                self.recompute()
            }
        }
    }

    private func refreshBrowser() {
        guard Pref.bool(Pref.media) else {
            AudioVisualizer.shared.follow(bundleIdentifiers: [], isPlaying: false)
            return
        }
        guard Pref.bool(Pref.browserMedia), !browserBusy else {
            if browserTrack != nil, !Pref.bool(Pref.browserMedia) { browserTrack = nil; recompute() }
            return
        }
        let names = BrowserMedia.runningBrowserNames()
        guard !names.isEmpty else {
            if browserTrack != nil { browserTrack = nil; recompute() }
            return
        }
        browserBusy = true
        let currentURL = browserTrack?.url
        DispatchQueue.global(qos: .utility).async {
            let track = BrowserMedia.scan(browserNames: names, preferredURL: currentURL)
            DispatchQueue.main.async {
                self.browserBusy = false
                self.browserTrack = track
                self.recompute()
            }
        }
    }

    private func refreshBrowserAudioState() {
        guard Pref.bool(Pref.media), var track = browserTrack, !track.preciseState,
              let id = BrowserMedia.bundleID(forApp: track.app) else { return }
        let playing = BrowserMedia.isOutputtingAudio(bundlePrefix: id)
        guard playing != track.playing else { return }
        track.playing = playing
        browserTrack = track
        recompute()
    }


    private func recompute() {
        if let n = native {
            activeIsBrowser = false
            applyNative(n)
        } else if let b = browserTrack {
            activeIsBrowser = true
            applyBrowser(b)
        } else {
            activeIsBrowser = false
            AudioVisualizer.shared.follow(bundleIdentifiers: [], isPlaying: false)
            title = ""; artist = ""; isPlaying = false; artwork = nil
            hasTrack = false; sourceLabel = ""; artworkURL = nil
            requestedMusicArtworkTrack = nil
            position = 0; duration = 0; positionDate = Date()
            lyrics.clear()
        }
    }

    private static func number(_ parts: [String], _ i: Int) -> Double {
        guard parts.count > i else { return 0 }
        return Double(parts[i].replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func applyNative(_ n: (app: String, parts: [String])) {
        let p = n.parts
        hasTrack = true
        let newIsPlaying = p[0] == "playing"
        let newTitle = p[1]
        let newArtist = p[2]
        let trackChanged = n.app != sourceLabel || newTitle != title || newArtist != artist
        let bundleID = n.app == "Spotify" ? "com.spotify.client" : "com.apple.Music"
        AudioVisualizer.shared.follow(bundleIdentifiers: [bundleID], isPlaying: newIsPlaying)

        sourceLabel = n.app
        setIfChanged(\.title, newTitle)
        setIfChanged(\.artist, newArtist)
        if n.app == "Music" {
            loadMusicArtwork(title: newTitle, artist: newArtist)
        } else {
            requestedMusicArtworkTrack = nil
            loadArtwork(p.count > 3 ? p[3] : "")
        }

        let polledPos = Self.number(p, 4)
        duration = n.app == "Spotify" ? Self.number(p, 5) / 1000 : Self.number(p, 5)
        canShuffle = true
        shuffleOn = p.count > 6 && p[6] == "true"
        repeatOn = p.count > 7 && p[7] != "false" && p[7] != "off"

        if trackChanged || queueTracks.isEmpty || lastFetchedTrack.isEmpty {
            fetchUpcomingQueue(title: newTitle, artist: newArtist, app: n.app)
            lyrics.update(title: newTitle, artist: newArtist, isAppleMusic: n.app == "Music")
        }

        updatePosition(polled: polledPos, isPlaying: newIsPlaying, trackChanged: trackChanged)
    }

    private func applyBrowser(_ b: BrowserTrack) {
        let trackChanged = b.service != sourceLabel || b.title != title || b.artist != artist
        AudioVisualizer.shared.follow(
            bundleIdentifiers: BrowserMedia.bundleID(forApp: b.app).map { [$0] } ?? [],
            isPlaying: b.playing
        )
        hasTrack = true
        sourceLabel = b.service
        setIfChanged(\.title, b.title)
        setIfChanged(\.artist, b.artist)
        requestedMusicArtworkTrack = nil
        loadArtwork(b.artworkURL)
        duration = b.duration
        canShuffle = false
        shuffleOn = false
        repeatOn = b.loop

        if trackChanged || queueTracks.isEmpty || lastFetchedTrack.isEmpty {
            fetchUpcomingQueue(title: b.title, artist: b.artist, app: b.service)
            lyrics.update(title: b.title, artist: b.artist, isAppleMusic: false)
        }

        updatePosition(polled: b.position, isPlaying: b.playing, trackChanged: trackChanged)
    }

    private func fetchUpcomingQueue(title: String, artist: String, app: String) {
        let key = "\(app)::\(title)::\(artist)"
        guard key != lastFetchedTrack, !title.isEmpty else { return }
        lastFetchedTrack = key
        queueSupported = app == "Music"
        guard app == "Music" else {
            queueTracks = []
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let tracks = Self.queryMusicQueue() ?? []
            DispatchQueue.main.async {
                guard let self, self.lastFetchedTrack == key else { return }
                self.queueTracks = tracks.map { t in
                    QueueTrack(id: t.id, title: t.title, artist: t.artist, artwork: t.artwork,
                               artworkURL: nil, symbol: "music.note", accent: Color.white.opacity(0.12))
                }
            }
        }
    }

    nonisolated private static func queryMusicQueue() -> [(id: String, title: String, artist: String, artwork: NSImage?)]? {
        let script = """
        tell application "Music"
            if player state is stopped then return {}
            set results to {}
            try
                set pl to current playlist
                set curID to persistent ID of current track
                set allIDs to persistent ID of every track of pl
                set curIdx to 0
                repeat with i from 1 to count of allIDs
                    if item i of allIDs is curID then
                        set curIdx to i
                        exit repeat
                    end if
                end repeat
                if curIdx is 0 then return {}
                set lastIdx to curIdx + 4
                if lastIdx > (count of allIDs) then set lastIdx to count of allIDs
                repeat with i from (curIdx + 1) to lastIdx
                    set trk to track i of pl
                    set art to missing value
                    try
                        set art to raw data of artwork 1 of trk
                    end try
                    set end of results to {persistent ID of trk, name of trk, artist of trk, art}
                end repeat
            end try
            return results
        end tell
        """
        var err: NSDictionary?
        guard let list = NSAppleScript(source: script)?.executeAndReturnError(&err), err == nil,
              list.numberOfItems > 0 else { return nil }
        var out: [(id: String, title: String, artist: String, artwork: NSImage?)] = []
        for i in 1...list.numberOfItems {
            guard let row = list.atIndex(i), row.numberOfItems >= 3,
                  let id = row.atIndex(1)?.stringValue,
                  let name = row.atIndex(2)?.stringValue else { continue }
            let artist = row.atIndex(3)?.stringValue ?? ""
            var image: NSImage?
            if row.numberOfItems >= 4, let d = row.atIndex(4)?.data, !d.isEmpty { image = NSImage(data: d) }
            out.append((id: id, title: name, artist: artist, artwork: image))
        }
        return out
    }

    private func updatePosition(polled: Double, isPlaying newIsPlaying: Bool, trackChanged: Bool) {
        let wasPlaying = self.isPlaying

        if trackChanged {
            self.isPlaying = newIsPlaying
            position = polled
            positionDate = Date()
            return
        }

        if Date().timeIntervalSince(lastActionTime) < 1.0 {
            return
        }

        self.isPlaying = newIsPlaying
        self.desiredPlayingState = newIsPlaying
        self.lastDispatchedState = newIsPlaying

        if !self.isPlaying {
            if abs(polled - position) > 2.0 || polled > position {
                position = polled
            }
            positionDate = Date()
            return
        }

        if !wasPlaying {
            position = polled
            positionDate = Date()
            return
        }

        let interpolated = currentPosition()
        let delta = abs(polled - interpolated)

        if delta > 1.5 {
            position = polled
            positionDate = Date()
        } else if delta > 0.3 {
            position = (interpolated * 0.7) + (polled * 0.3)
            positionDate = Date()
        }
    }

    private func setIfChanged(_ keyPath: ReferenceWritableKeyPath<MediaController, String>, _ value: String) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }

    private static func sampleArtworkColor(_ image: NSImage) -> Color {
        var proposedRect = CGRect(origin: .zero, size: image.size)
        guard let image = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return Color(white: 0.82)
        }

        let width = 24
        let height = 24
        let bytesPerRow = width * 4
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        var pixelBuffer = [UInt8](repeating: 0, count: height * bytesPerRow)
        let pixels = pixelBuffer.withUnsafeMutableBytes { bytes -> [UInt8]? in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return nil
            }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return Array(bytes.bindMemory(to: UInt8.self))
        }
        guard let pixels else { return Color(white: 0.82) }

        var bucketWeights = [Double](repeating: 0, count: 4096)
        var bucketRed = [Double](repeating: 0, count: 4096)
        var bucketGreen = [Double](repeating: 0, count: 4096)
        var bucketBlue = [Double](repeating: 0, count: 4096)
        var totalRed = 0.0
        var totalGreen = 0.0
        var totalBlue = 0.0
        var totalWeight = 0.0

        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[offset + 3]) / 255
            guard alpha > 0.15 else { continue }
            let red = min(1, Double(pixels[offset]) / 255 / alpha)
            let green = min(1, Double(pixels[offset + 1]) / 255 / alpha)
            let blue = min(1, Double(pixels[offset + 2]) / 255 / alpha)
            let brightness = (red + green + blue) / 3
            let saturation = max(red, green, blue) - min(red, green, blue)
            totalRed += red * alpha
            totalGreen += green * alpha
            totalBlue += blue * alpha
            totalWeight += alpha

            let hueWeight = alpha * saturation * max(0.12, 1 - abs(brightness - 0.52))
            guard hueWeight > 0.015 else { continue }
            let bucket = (Int(red * 15) << 8) | (Int(green * 15) << 4) | Int(blue * 15)
            bucketWeights[bucket] += hueWeight
            bucketRed[bucket] += red * hueWeight
            bucketGreen[bucket] += green * hueWeight
            bucketBlue[bucket] += blue * hueWeight
        }

        if let bucket = bucketWeights.indices.max(by: { bucketWeights[$0] < bucketWeights[$1] }),
           bucketWeights[bucket] > 0.02 {
            let weight = bucketWeights[bucket]
            return visibleArtworkColor(red: bucketRed[bucket] / weight,
                                       green: bucketGreen[bucket] / weight,
                                       blue: bucketBlue[bucket] / weight)
        }
        guard totalWeight > 0 else { return Color(white: 0.82) }
        return visibleArtworkColor(red: totalRed / totalWeight,
                                   green: totalGreen / totalWeight,
                                   blue: totalBlue / totalWeight)
    }

    private static func visibleArtworkColor(red: Double, green: Double, blue: Double) -> Color {
        let peak = max(red, green, blue)
        guard peak > 0.02 else { return Color(white: 0.82) }
        let scale = peak < 0.5 ? 0.5 / max(peak, 0.01) : 1
        return Color(.sRGB, red: min(1, red * scale), green: min(1, green * scale),
                     blue: min(1, blue * scale), opacity: 1)
    }

    private static func normalizeArtworkURL(_ raw: String) -> String {
        var url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasPrefix("spotify:image:") {
            let id = url.replacingOccurrences(of: "spotify:image:", with: "")
            url = "https://i.scdn.co/image/\(id)"
        } else if url.hasPrefix("http://") {
            url = "https://" + url.dropFirst(7)
        }
        return url
    }

    private func loadArtwork(_ rawURL: String) {
        let url = Self.normalizeArtworkURL(rawURL)
        guard url != artworkURL else { return }
        artworkURL = url
        artworkTask?.cancel()

        guard !url.isEmpty, let u = URL(string: url) else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                self.artwork = nil
            }
            return
        }

        if let cached = Self.imageCache.object(forKey: url as NSString) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                self.artwork = cached
            }
            return
        }

        var request = URLRequest(url: u)
        request.cachePolicy = .returnCacheDataElseLoad
        let task = Self.artworkSession.dataTask(with: request) { [weak self] data, _, _ in
            guard let data, let img = NSImage(data: data) else {
                DispatchQueue.main.async {
                    guard let self, self.artworkURL == url else { return }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                        self.artwork = nil
                    }
                }
                return
            }
            Self.imageCache.setObject(img, forKey: url as NSString, cost: data.count)
            DispatchQueue.main.async {
                guard let self, self.artworkURL == url else { return }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                    self.artwork = img
                }
            }
        }
        task.priority = URLSessionTask.highPriority
        artworkTask = task
        task.resume()
    }

    private func loadMusicArtwork(title: String, artist: String) {
        let key = "\(title)::\(artist)"
        guard key != requestedMusicArtworkTrack else { return }
        requestedMusicArtworkTrack = key
        artworkTask?.cancel()
        artworkURL = nil
        artwork = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let image = Self.queryMusicArtwork().flatMap { NSImage(data: $0) }
            DispatchQueue.main.async {
                guard let self,
                      self.sourceLabel == "Music",
                      self.requestedMusicArtworkTrack == key,
                      self.title == title,
                      self.artist == artist,
                      let image else { return }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                    self.artwork = image
                }
            }
        }
    }

    nonisolated private static func queryMusicArtwork() -> Data? {
        let source = """
        tell application "Music"
            try
                return raw data of artwork 1 of current track
            on error
                return missing value
            end try
        end tell
        """
        var error: NSDictionary?
        return NSAppleScript(source: source)?.executeAndReturnError(&error).data
    }

    nonisolated private static func query(_ app: String) -> [String]? {
        let source: String
        if app == "Spotify" {
            source = """
            tell application "Spotify"
                if player state is stopped then return "stopped||||"
                return (player state as string) & "||" & (name of current track) & "||" & (artist of current track) & "||" & (artwork url of current track) & "||" & (player position as string) & "||" & ((duration of current track) as string) & "||" & (shuffling as string) & "||" & (repeating as string)
            end tell
            """
        } else {
            source = """
            tell application "Music"
                if player state is stopped then return "stopped||||"
                return (player state as string) & "||" & (name of current track) & "||" & (artist of current track) & "||" & "" & "||" & (player position as string) & "||" & ((duration of current track) as string) & "||" & (shuffle enabled as string) & "||" & (song repeat as string)
            end tell
            """
        }
        var error: NSDictionary?
        guard let out = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue, error == nil else { return nil }
        let parts = out.components(separatedBy: "||")
        guard parts.count >= 3, parts[0] != "stopped" else { return nil }
        return parts
    }


    private func scheduleRefresh(delay: Double = 0.35) {
        refreshWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.refreshNative()
            self?.refreshBrowser()
        }
        refreshWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func control(native script: @escaping (String) -> String, browser action: BrowserAction?) {
        let n = native
        let b = browserTrack
        let useBrowser = activeIsBrowser
        controlQueue.async { [weak self] in
            guard let self else { return }
            if useBrowser, let b, let action {
                BrowserMedia.command(action, on: b)
            } else if let n {
                var error: NSDictionary?
                NSAppleScript(source: script(n.app))?.executeAndReturnError(&error)
            } else if let b, let action {
                BrowserMedia.command(action, on: b)
            }
            DispatchQueue.main.async { self.scheduleRefresh() }
        }
    }

    private func dispatchPlaybackStateIfNeeded() {
        pendingPlayPauseDispatch?.cancel()
        pendingPlayPauseDispatch = nil

        let target = desiredPlayingState
        let elapsed = Date().timeIntervalSince(lastDispatchedTime)
        let minInterval: TimeInterval = 0.28

        if elapsed < minInterval {
            let delay = max(0.05, minInterval - elapsed)
            let item = DispatchWorkItem { [weak self] in
                self?.dispatchPlaybackStateIfNeeded()
            }
            pendingPlayPauseDispatch = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return
        }

        if lastDispatchedState == target {
            return
        }

        lastDispatchedState = target
        lastDispatchedTime = Date()

        if activeIsBrowser, let b = browserTrack {
            pendingPlayPauseWorkItem?.cancel()
            let item = DispatchWorkItem {
                BrowserMedia.command(target ? .play : .pause, on: b)
            }
            pendingPlayPauseWorkItem = item
            controlQueue.async(execute: item)
        } else if let n = native {
            controlQueue.async {
                var error: NSDictionary?
                NSAppleScript(source: "tell application \"\(n.app)\" to \(target ? "play" : "pause")")?.executeAndReturnError(&error)
            }
        } else {
            Self.sendMediaRemoteCommand(target ? 0 : 1)
        }
    }

    func playPause() {
        let nowPos = currentPosition()
        let target = !isPlaying
        isPlaying = target
        desiredPlayingState = target
        lastActionTime = Date()
        queryEpoch += 1

        if activeIsBrowser {
            if var b = browserTrack {
                b.playing = target
                b.position = nowPos
                browserTrack = b
            }
        } else {
            if var n = native {
                n.parts[0] = target ? "playing" : "paused"
                native = n
            }
        }

        position = nowPos
        positionDate = Date()

        dispatchPlaybackStateIfNeeded()
        scheduleRefresh(delay: 0.35)
    }

    func playQueueTrack(_ track: QueueTrack) {
        guard queueSupported else { return }
        position = 0
        positionDate = Date()
        lastActionTime = Date()
        queryEpoch += 1
        let pid = track.id.replacingOccurrences(of: "\"", with: "")
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: "tell application \"Music\" to play (first track of current playlist whose persistent ID is \"\(pid)\")")?
                .executeAndReturnError(&error)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.refreshNative() }
    }

    func next() {
        position = 0
        positionDate = Date()
        lastActionTime = Date()
        queryEpoch += 1
        if activeIsBrowser, let b = browserTrack {
            controlQueue.async { BrowserMedia.command(.next, on: b) }
        } else if let n = native {
            controlQueue.async {
                var error: NSDictionary?
                NSAppleScript(source: "tell application \"\(n.app)\" to next track")?.executeAndReturnError(&error)
            }
        } else {
            Self.sendMediaRemoteCommand(4)
        }
        scheduleRefresh(delay: 0.35)
    }

    func previous() {
        position = 0
        positionDate = Date()
        lastActionTime = Date()
        queryEpoch += 1
        if activeIsBrowser, let b = browserTrack {
            controlQueue.async { BrowserMedia.command(.previous, on: b) }
        } else if let n = native {
            controlQueue.async {
                var error: NSDictionary?
                NSAppleScript(source: "tell application \"\(n.app)\" to previous track")?.executeAndReturnError(&error)
            }
        } else {
            Self.sendMediaRemoteCommand(5)
        }
        scheduleRefresh(delay: 0.35)
    }

    func seek(to seconds: Double) {
        let target = max(0, min(seconds, duration))
        position = target
        positionDate = Date()
        control(native: { "tell application \"\($0)\" to set player position to \(String(format: "%.2f", target))" },
                browser: .seek(target))
    }

    func toggleShuffle() {
        guard canShuffle else { return }
        shuffleOn.toggle()
        control(native: { app in
            app == "Spotify" ? "tell application \"Spotify\" to set shuffling to not shuffling"
                             : "tell application \"Music\" to set shuffle enabled to not shuffle enabled"
        }, browser: nil)
    }

    func toggleRepeat() {
        repeatOn.toggle()
        control(native: { app in
            app == "Spotify" ? "tell application \"Spotify\" to set repeating to not repeating"
                             : "tell application \"Music\"\nif song repeat is off then\nset song repeat to all\nelse\nset song repeat to off\nend if\nend tell"
        }, browser: .toggleLoop)
    }

    func openApp() {
        if let n = native {
            let bundleID = n.app == "Spotify" ? "com.spotify.client" : "com.apple.Music"
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
        }
    }
}
