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
    @Published var artwork: NSImage?
    @Published var hasTrack = false
    @Published var sourceLabel = ""
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var shuffleOn = false
    @Published var repeatOn = false
    @Published var canShuffle = false
    @Published var queueTracks: [QueueTrack] = []
    @Published var queueSupported = false
    @Published var isFavorite = false

    private var likedSpotifyTracks: Set<String> = {
        let list = UserDefaults.standard.stringArray(forKey: "notchy.likedTracks") ?? []
        return Set(list)
    }()

    private func saveLikedTracks() {
        UserDefaults.standard.set(Array(likedSpotifyTracks), forKey: "notchy.likedTracks")
    }

    private var spotifyLikedTracks: Set<String> = []
    private var lastSpotifyLikedScan: Date = .distantPast

    private func reloadSpotifyLikedTracks(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastSpotifyLikedScan) > 15.0 else { return }
        lastSpotifyLikedScan = Date()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let tracks = Self.scanSpotifyLikedTracks()
            guard !tracks.isEmpty else { return }
            DispatchQueue.main.async {
                self?.spotifyLikedTracks.formUnion(tracks)
                self?.recompute()
            }
        }
    }

    nonisolated private static func scanSpotifyLikedTracks() -> Set<String> {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let baseDir = home.appendingPathComponent("Library/Application Support/Spotify/PersistentCache/Users")
        guard let userDirs = try? fileManager.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil) else { return [] }
        var result = Set<String>()
        guard let target = "Liked Songs".data(using: .utf8),
              let trackPrefix = "track:".data(using: .utf8) else { return [] }

        for userDir in userDirs {
            let ldbDir = userDir.appendingPathComponent("primary.ldb")
            guard let files = try? fileManager.contentsOfDirectory(at: ldbDir, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.pathExtension == "ldb" || file.pathExtension == "log" {
                guard let data = try? Data(contentsOf: file, options: .mappedIfSafe) else { continue }
                var searchRange = 0..<data.count
                while let found = data.range(of: target, options: [], in: searchRange) {
                    let chunkEnd = min(data.count, found.upperBound + 30000)
                    let chunk = data.subdata(in: found.upperBound..<chunkEnd)
                    var trackSearch = 0..<chunk.count
                    while let tFound = chunk.range(of: trackPrefix, options: [], in: trackSearch) {
                        let idStart = tFound.upperBound
                        let idEnd = idStart + 22
                        if idEnd <= chunk.count {
                            let idData = chunk.subdata(in: idStart..<idEnd)
                            if let idStr = String(data: idData, encoding: .ascii),
                               idStr.count == 22,
                               idStr.allSatisfy({ $0.isLetter || $0.isNumber }) {
                                result.insert(idStr)
                            }
                        }
                        trackSearch = tFound.upperBound..<chunk.count
                    }
                    searchRange = found.upperBound..<data.count
                }
            }
        }
        return result
    }

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

        reloadSpotifyLikedTracks(force: true)
    }


    private func refreshNative() {
        guard Pref.bool(Pref.media) else { return }
        reloadSpotifyLikedTracks()
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
        guard Pref.bool(Pref.media), Pref.bool(Pref.browserMedia), !browserBusy else {
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
            title = ""; artist = ""; isPlaying = false; artwork = nil
            hasTrack = false; sourceLabel = ""; artworkURL = nil
            position = 0; duration = 0; positionDate = Date()
            isFavorite = false
        }
    }

    private static func number(_ parts: [String], _ i: Int) -> Double {
        guard parts.count > i else { return 0 }
        return Double(parts[i].replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func applyNative(_ n: (app: String, parts: [String])) {
        let p = n.parts
        hasTrack = true
        sourceLabel = n.app
        let newIsPlaying = p[0] == "playing"
        let newTitle = p[1]
        let newArtist = p[2]
        let trackChanged = newTitle != title || newArtist != artist

        setIfChanged(\.title, newTitle)
        setIfChanged(\.artist, newArtist)
        loadArtwork(p.count > 3 ? p[3] : "")

        let polledPos = Self.number(p, 4)
        duration = n.app == "Spotify" ? Self.number(p, 5) / 1000 : Self.number(p, 5)
        canShuffle = true
        shuffleOn = p.count > 6 && p[6] == "true"
        repeatOn = p.count > 7 && p[7] != "false" && p[7] != "off"

        if n.app == "Spotify" {
            let rawID = p.count > 8 ? p[8] : ""
            let cleanID = rawID.replacingOccurrences(of: "spotify:track:", with: "")
            let isLiked = (!cleanID.isEmpty && (spotifyLikedTracks.contains(cleanID) || likedSpotifyTracks.contains(cleanID)))
                || (!rawID.isEmpty && likedSpotifyTracks.contains(rawID))
                || likedSpotifyTracks.contains("\(newTitle)::\(newArtist)")
            isFavorite = isLiked
        } else if n.app == "Music" {
            isFavorite = p.count > 8 && p[8] == "true"
        }

        if trackChanged || queueTracks.isEmpty || lastFetchedTrack.isEmpty {
            fetchUpcomingQueue(title: newTitle, artist: newArtist, app: n.app)
        }

        updatePosition(polled: polledPos, isPlaying: newIsPlaying, trackChanged: trackChanged)
    }

    private func applyBrowser(_ b: BrowserTrack) {
        let trackChanged = b.title != title || b.artist != artist
        hasTrack = true
        sourceLabel = b.service
        setIfChanged(\.title, b.title)
        setIfChanged(\.artist, b.artist)
        loadArtwork(b.artworkURL)
        duration = b.duration
        canShuffle = false
        shuffleOn = false
        repeatOn = b.loop
        isFavorite = b.isFavorite

        if trackChanged || queueTracks.isEmpty || lastFetchedTrack.isEmpty {
            fetchUpcomingQueue(title: b.title, artist: b.artist, app: b.service)
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

    nonisolated private static func query(_ app: String) -> [String]? {
        let source: String
        if app == "Spotify" {
            source = """
            tell application "Spotify"
                if player state is stopped then return "stopped||||"
                return (player state as string) & "||" & (name of current track) & "||" & (artist of current track) & "||" & (artwork url of current track) & "||" & (player position as string) & "||" & ((duration of current track) as string) & "||" & (shuffling as string) & "||" & (repeating as string) & "||" & (id of current track as string)
            end tell
            """
        } else {
            source = """
            tell application "Music"
                if player state is stopped then return "stopped||||"
                set isFav to "false"
                try
                    set isFav to (favorited of current track as string)
                on error
                    try
                        set isFav to (loved of current track as string)
                    end try
                end try
                return (player state as string) & "||" & (name of current track) & "||" & (artist of current track) & "||" & "" & "||" & (player position as string) & "||" & ((duration of current track) as string) & "||" & (shuffle enabled as string) & "||" & (song repeat as string) & "||" & isFav
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

    func toggleLike() {
        isFavorite.toggle()
        let targetFav = isFavorite
        if activeIsBrowser, var b = browserTrack {
            b.isFavorite = targetFav
            browserTrack = b
            controlQueue.async {
                BrowserMedia.command(.toggleLike, on: b)
            }
        } else if let n = native {
            if n.app == "Spotify" {
                let rawID = n.parts.count > 8 ? n.parts[8] : ""
                let cleanID = rawID.replacingOccurrences(of: "spotify:track:", with: "")
                if targetFav {
                    if !cleanID.isEmpty {
                        spotifyLikedTracks.insert(cleanID)
                        likedSpotifyTracks.insert(cleanID)
                    }
                    likedSpotifyTracks.insert("\(title)::\(artist)")
                } else {
                    if !cleanID.isEmpty {
                        spotifyLikedTracks.remove(cleanID)
                        likedSpotifyTracks.remove(cleanID)
                    }
                    likedSpotifyTracks.remove("\(title)::\(artist)")
                }
                saveLikedTracks()
                controlQueue.async {
                    var error: NSDictionary?
                    NSAppleScript(source: "tell application \"System Events\" to tell process \"Spotify\" to key code 11 using {option down, shift down}")?
                        .executeAndReturnError(&error)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    self?.reloadSpotifyLikedTracks(force: true)
                }
            } else if n.app == "Music" {
                controlQueue.async {
                    var error: NSDictionary?
                    NSAppleScript(source: """
                    tell application "Music"
                        try
                            set favorited of current track to not (favorited of current track)
                        on error
                            try
                                set loved of current track to not (loved of current track)
                            end try
                        end try
                    end tell
                    """)?.executeAndReturnError(&error)
                }
            }
        }
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
