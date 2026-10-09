import AppKit
import ImageIO
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

private struct MusicArtworkTrack {
    let id: String
    let title: String
    let artist: String
    let artwork: NSImage?
}

private struct MusicQueueSnapshot {
    let previous: [MusicArtworkTrack]
    let current: MusicArtworkTrack?
    let upcoming: [MusicArtworkTrack]
    let shuffleEnabled: Bool
}

private struct SystemNowPlayingTrack {
    let title: String
    let artist: String
    let bundleIdentifier: String?
    let artwork: NSImage?
    let duration: Double
    let elapsedTime: Double
    let isPlaying: Bool
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
    @Published private(set) var artworkSkipAnimationID = 0
    @Published private(set) var artworkSkipDirection: NotchSwipeDirection?
    @Published private(set) var artworkSkipArtwork: NSImage?
    @Published var shuffleOn = false
    @Published var repeatOn = false
    @Published var canShuffle = false
    @Published var queueTracks: [QueueTrack] = []
    @Published var queueSupported = false
    @Published var lyrics = LyricsService()

    private var lastFetchedTrack = ""
    private var lastQueueFetchDate = Date.distantPast
    private var previousQueueTracks: [MusicArtworkTrack] = []
    private var prefetchedUpcomingTracks: [MusicArtworkTrack] = []
    private var prefetchedMusicArtwork: [String: NSImage] = [:]
    private var prefetchedMusicQueueTrackKey = ""
    private var prefetchedMusicQueueIsShuffled = false
    private var artworkSkipWorkItem: DispatchWorkItem?

    private(set) var positionDate = Date()

    func currentPosition(at date: Date = Date()) -> Double {
        guard isPlaying, duration > 0 else { return position }
        let elapsed = max(0, date.timeIntervalSince(positionDate))
        return min(duration, position + elapsed)
    }

    private var native: (app: String, parts: [String])?
    private var browserTrack: BrowserTrack?
    private var systemNowPlayingTrack: SystemNowPlayingTrack?
    private var systemNowPlayingBusy = false
    private var activeIsSystemNowPlaying = false
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
    private typealias MRNowPlayingInfoCompletion = @convention(block) (CFDictionary?) -> Void
    private typealias MRGetNowPlayingInfoFunc = @convention(c) (DispatchQueue, @escaping MRNowPlayingInfoCompletion) -> Void
    private typealias MRNowPlayingBundleIDCompletion = @convention(block) (CFString?) -> Void
    private typealias MRGetNowPlayingBundleIDFunc = @convention(c) (DispatchQueue, @escaping MRNowPlayingBundleIDCompletion) -> Void
    private static let sendCommandFunc: MRMediaRemoteSendCommandFunc? = {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
              let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) else {
            return nil
        }
        return unsafeBitCast(ptr, to: MRMediaRemoteSendCommandFunc.self)
    }()

    private static let getNowPlayingInfoFunc: MRGetNowPlayingInfoFunc? = {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
              let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else {
            return nil
        }
        return unsafeBitCast(ptr, to: MRGetNowPlayingInfoFunc.self)
    }()

    private static let getNowPlayingBundleIDFunc: MRGetNowPlayingBundleIDFunc? = {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
              let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationDisplayID" as CFString) else {
            return nil
        }
        return unsafeBitCast(ptr, to: MRGetNowPlayingBundleIDFunc.self)
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

    nonisolated(unsafe) private static let musicArtworkCache: NSCache<NSString, NSImage> = {
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

        let t4 = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshSystemNowPlaying() }
        }
        RunLoop.main.add(t4, forMode: .common)
        timers.append(t4)

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
        refreshSystemNowPlaying()
    }

    private func refreshSystemNowPlaying() {
        guard Pref.bool(Pref.media), !systemNowPlayingBusy,
              Self.getNowPlayingInfoFunc != nil else { return }
        systemNowPlayingBusy = true
        Self.requestSystemNowPlaying { [weak self] track in
            DispatchQueue.main.async {
                guard let self else { return }
                self.systemNowPlayingBusy = false
                self.systemNowPlayingTrack = track
                if self.native?.parts.first != "playing" { self.recompute() }
            }
        }
    }

    private static func requestSystemNowPlaying(completion: @escaping (SystemNowPlayingTrack?) -> Void) {
        guard let getInfo = getNowPlayingInfoFunc else {
            completion(nil)
            return
        }
        let queue = DispatchQueue.global(qos: .userInitiated)
        let readInfo: (String?) -> Void = { bundleIdentifier in
            getInfo(queue) { info in
                completion(parseSystemNowPlaying(info, bundleIdentifier: bundleIdentifier))
            }
        }
        if let getBundleID = getNowPlayingBundleIDFunc {
            getBundleID(queue) { bundleID in
                readInfo(bundleID.map { $0 as String })
            }
        } else {
            readInfo(nil)
        }
    }

    nonisolated private static func parseSystemNowPlaying(
        _ rawInfo: CFDictionary?,
        bundleIdentifier: String?
    ) -> SystemNowPlayingTrack? {
        guard let rawInfo, let info = rawInfo as? [String: Any] else { return nil }

        func value(_ keys: [String]) -> Any? {
            for key in keys {
                if let value = info[key] { return value }
            }
            return nil
        }
        func string(_ keys: [String]) -> String {
            (value(keys) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        func number(_ keys: [String]) -> Double? {
            (value(keys) as? NSNumber)?.doubleValue ?? (value(keys) as? Double)
        }

        let title = string(["kMRMediaRemoteNowPlayingInfoTitle", "title"])
        guard !title.isEmpty else { return nil }
        let artist = string(["kMRMediaRemoteNowPlayingInfoArtist", "artist"])
        let artworkData = value(["kMRMediaRemoteNowPlayingInfoArtworkData", "artworkData"]) as? Data
        let cacheKey = "now-playing::\(bundleIdentifier ?? "")::\(title)::\(artist)" as NSString
        var artwork = imageCache.object(forKey: cacheKey)
        if artwork == nil, let artworkData, let decoded = decodeArtworkImage(artworkData) {
            artwork = decoded
            imageCache.setObject(decoded, forKey: cacheKey, cost: artworkData.count)
        }
        let duration = max(0, number(["kMRMediaRemoteNowPlayingInfoDuration", "duration"]) ?? 0)
        let elapsed = max(0, number(["kMRMediaRemoteNowPlayingInfoElapsedTime", "elapsedTime"]) ?? 0)
        let playbackRate = number(["kMRMediaRemoteNowPlayingInfoPlaybackRate", "playbackRate"])
        let isPlaying = playbackRate.map { $0 > 0 } ?? (value(["isPlaying"]) as? Bool ?? true)

        return SystemNowPlayingTrack(
            title: title,
            artist: artist,
            bundleIdentifier: bundleIdentifier,
            artwork: artwork,
            duration: duration,
            elapsedTime: elapsed,
            isPlaying: isPlaying
        )
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
                    if !self.activeIsBrowser && !self.activeIsSystemNowPlaying {
                        b.parts[0] = self.desiredPlayingState ? "playing" : "paused"
                        best = b
                    }
                } else if let b = best {
                    let reported = b.parts[0] == "playing"
                    if !self.activeIsBrowser && !self.activeIsSystemNowPlaying {
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
        if let nowPlaying = systemNowPlayingTrack,
           nowPlaying.isPlaying,
           native?.parts.first != "playing" {
            let matchingBrowser = browserTrack.flatMap { browser in
                nowPlaying.bundleIdentifier == BrowserMedia.bundleID(forApp: browser.app) ? browser : nil
            }
            applySystemNowPlaying(nowPlaying, browser: matchingBrowser)
        } else if let n = native {
            activeIsBrowser = false
            applyNative(n)
        } else if let b = browserTrack {
            activeIsBrowser = true
            if let nowPlaying = systemNowPlayingTrack,
               !b.hasMediaSessionMetadata,
               (nowPlaying.bundleIdentifier == nil || nowPlaying.bundleIdentifier == BrowserMedia.bundleID(forApp: b.app)) {
                applySystemNowPlaying(nowPlaying, browser: b)
            } else {
                let browserBundleID = BrowserMedia.bundleID(forApp: b.app)
                let matchingNowPlaying = systemNowPlayingTrack.flatMap { track in
                    track.bundleIdentifier == browserBundleID ? track : nil
                }
                applyBrowser(b, artworkFallback: matchingNowPlaying)
            }
        } else if let systemNowPlayingTrack {
            applySystemNowPlaying(systemNowPlayingTrack, browser: nil)
        } else {
            activeIsSystemNowPlaying = false
            activeIsBrowser = false
            AudioVisualizer.shared.follow(bundleIdentifiers: [], isPlaying: false)
            title = ""; artist = ""; isPlaying = false; artwork = nil
            hasTrack = false; sourceLabel = ""; artworkURL = nil
            requestedMusicArtworkTrack = nil
            lastFetchedTrack = ""
            lastQueueFetchDate = .distantPast
            previousQueueTracks = []
            prefetchedUpcomingTracks = []
            prefetchedMusicArtwork = [:]
            prefetchedMusicQueueTrackKey = ""
            prefetchedMusicQueueIsShuffled = false
            artworkSkipArtwork = nil
            queueTracks = []
            position = 0; duration = 0; positionDate = Date()
            lyrics.clear()
        }
    }

    private static func number(_ parts: [String], _ i: Int) -> Double {
        guard parts.count > i else { return 0 }
        return Double(parts[i].replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func applyNative(_ n: (app: String, parts: [String])) {
        activeIsSystemNowPlaying = false
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
        let reportedShuffle = p.count > 6 && p[6] == "true"
        if n.app == "Music", reportedShuffle != shuffleOn {
            prefetchedMusicQueueTrackKey = ""
            lastQueueFetchDate = .distantPast
        }
        shuffleOn = reportedShuffle
        repeatOn = p.count > 7 && p[7] != "false" && p[7] != "off"

        let shouldUpdateLyrics = trackChanged || queueTracks.isEmpty || lastFetchedTrack.isEmpty
        fetchUpcomingQueue(title: newTitle, artist: newArtist, app: n.app)
        if shouldUpdateLyrics {
            lyrics.update(title: newTitle, artist: newArtist, isAppleMusic: n.app == "Music")
        }

        updatePosition(polled: polledPos, isPlaying: newIsPlaying, trackChanged: trackChanged)
    }

    private func applyBrowser(_ b: BrowserTrack, artworkFallback: SystemNowPlayingTrack? = nil) {
        activeIsSystemNowPlaying = false
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
        if b.artworkURL.isEmpty, let fallbackArtwork = artworkFallback?.artwork {
            artworkTask?.cancel()
            artworkURL = nil
            if artwork !== fallbackArtwork {
                withAnimation(.easeOut(duration: 0.12)) { artwork = fallbackArtwork }
            }
        } else {
            loadArtwork(b.artworkURL)
        }
        duration = b.duration
        canShuffle = false
        shuffleOn = false
        repeatOn = b.loop

        let shouldUpdateLyrics = trackChanged || queueTracks.isEmpty || lastFetchedTrack.isEmpty
        fetchUpcomingQueue(title: b.title, artist: b.artist, app: b.service)
        if shouldUpdateLyrics {
            lyrics.update(title: b.title, artist: b.artist, isAppleMusic: false)
        }

        updatePosition(polled: b.position, isPlaying: b.playing, trackChanged: trackChanged)
    }

    private func applySystemNowPlaying(_ track: SystemNowPlayingTrack, browser: BrowserTrack?) {
        activeIsSystemNowPlaying = true
        activeIsBrowser = false
        hasTrack = true

        let source = browser?.service ?? Self.nowPlayingSourceName(track.bundleIdentifier)
        let displayArtist = track.artist.isEmpty ? (browser?.artist ?? "") : track.artist
        let trackChanged = source != sourceLabel || track.title != title || displayArtist != artist
        if trackChanged {
            desiredPlayingState = track.isPlaying
            lastDispatchedState = track.isPlaying
            lastDispatchedTime = Date()
        }
        AudioVisualizer.shared.follow(
            bundleIdentifiers: track.bundleIdentifier.map { [$0] } ?? [],
            isPlaying: track.isPlaying
        )

        sourceLabel = source
        setIfChanged(\.title, track.title)
        setIfChanged(\.artist, displayArtist)
        requestedMusicArtworkTrack = nil
        artworkTask?.cancel()
        artworkTask = nil
        artworkURL = nil
        if let image = track.artwork {
            if artwork !== image {
                withAnimation(.easeOut(duration: 0.12)) { artwork = image }
            }
        } else if let browser, !browser.artworkURL.isEmpty {
            loadArtwork(browser.artworkURL)
        } else if trackChanged {
            artwork = nil
        }

        duration = track.duration
        canShuffle = false
        if track.bundleIdentifier == "com.apple.Music" {
            let queueKey = "Music::\(track.title)::\(displayArtist)"
            if let native, native.app == "Music", native.parts.count > 6 {
                shuffleOn = native.parts[6] == "true"
            } else if prefetchedMusicQueueTrackKey == queueKey {
                shuffleOn = prefetchedMusicQueueIsShuffled
            } else {
                shuffleOn = false
            }
        } else {
            shuffleOn = false
        }
        repeatOn = false
        if track.bundleIdentifier == "com.apple.Music" {
            queueSupported = true
            fetchUpcomingQueue(title: track.title, artist: displayArtist, app: "Music")
        } else {
            queueSupported = false
            queueTracks = []
            lastFetchedTrack = ""
            previousQueueTracks = []
            prefetchedUpcomingTracks = []
            prefetchedMusicArtwork = [:]
            prefetchedMusicQueueTrackKey = ""
            prefetchedMusicQueueIsShuffled = false
        }
        if trackChanged {
            lyrics.update(
                title: track.title,
                artist: displayArtist,
                isAppleMusic: track.bundleIdentifier == "com.apple.Music"
            )
        }
        updatePosition(polled: track.elapsedTime, isPlaying: track.isPlaying, trackChanged: trackChanged)
    }

    private static func nowPlayingSourceName(_ bundleIdentifier: String?) -> String {
        guard let bundleIdentifier else { return "Now Playing" }
        switch bundleIdentifier {
        case "com.apple.Music": return "Music"
        case "com.spotify.client": return "Spotify"
        case "com.apple.Safari": return "Safari"
        case "com.google.Chrome": return "Chrome"
        case "com.brave.Browser": return "Brave"
        case "company.thebrowser.Browser": return "Arc"
        default:
            return bundleIdentifier.split(separator: ".").last.map(String.init)?.capitalized ?? "Now Playing"
        }
    }

    private static func nativePlayerName(for bundleIdentifier: String?) -> String? {
        switch bundleIdentifier {
        case "com.apple.Music": return "Music"
        case "com.spotify.client": return "Spotify"
        default: return nil
        }
    }

    private func fetchUpcomingQueue(title: String, artist: String, app: String) {
        let key = "\(app)::\(title)::\(artist)"
        guard !title.isEmpty else { return }
        let sameTrack = key == lastFetchedTrack
        guard !sameTrack || Date().timeIntervalSince(lastQueueFetchDate) >= 15 else { return }
        lastFetchedTrack = key
        lastQueueFetchDate = Date()
        queueSupported = app == "Music"
        guard app == "Music" else {
            queueTracks = []
            previousQueueTracks = []
            prefetchedUpcomingTracks = []
            prefetchedMusicArtwork = [:]
            prefetchedMusicQueueTrackKey = ""
            prefetchedMusicQueueIsShuffled = false
            return
        }
        prefetchedMusicQueueTrackKey = ""
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let snapshot = Self.queryMusicQueue()
            DispatchQueue.main.async {
                guard let self, self.lastFetchedTrack == key else { return }
                guard let snapshot else {
                    self.queueTracks = []
                    self.previousQueueTracks = []
                    self.prefetchedUpcomingTracks = []
                    self.prefetchedMusicArtwork = [:]
                    self.prefetchedMusicQueueIsShuffled = false
                    return
                }

                self.previousQueueTracks = snapshot.previous
                self.prefetchedUpcomingTracks = snapshot.upcoming
                self.prefetchedMusicQueueTrackKey = key
                self.prefetchedMusicQueueIsShuffled = snapshot.shuffleEnabled
                if self.activeIsSystemNowPlaying,
                   self.systemNowPlayingTrack?.bundleIdentifier == "com.apple.Music" {
                    self.shuffleOn = snapshot.shuffleEnabled
                }
                self.queueTracks = snapshot.upcoming.map { track in
                    QueueTrack(id: track.id, title: track.title, artist: track.artist, artwork: track.artwork,
                               artworkURL: nil, symbol: "music.note", accent: Color.white.opacity(0.12))
                }
                var prefetched: [String: NSImage] = [:]
                var prefetchedTracks = snapshot.previous
                if let current = snapshot.current { prefetchedTracks.append(current) }
                prefetchedTracks.append(contentsOf: snapshot.upcoming)
                for track in prefetchedTracks {
                    if let image = track.artwork {
                        prefetched[Self.musicArtworkKey(track.title, track.artist)] = image
                    }
                }
                self.prefetchedMusicArtwork = prefetched

                if let current = snapshot.current,
                   current.title == self.title,
                   current.artist == self.artist,
                   let image = current.artwork,
                   self.artwork == nil {
                    withAnimation(.easeOut(duration: 0.12)) {
                        self.artwork = image
                    }
                }
            }
        }
    }

    nonisolated private static func queryMusicQueue() -> MusicQueueSnapshot? {
        let script = """
        tell application "Music"
            if player state is stopped then return {}
            set results to {}
            try
                set end of results to {"shuffle", shuffle enabled as string}
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
                set trk to track curIdx of pl
                set art to missing value
                try
                    set art to raw data of artwork 1 of trk
                end try
                set end of results to {"current", persistent ID of trk, name of trk, artist of trk, art}

                set firstPreviousIdx to curIdx - 2
                if firstPreviousIdx < 1 then set firstPreviousIdx to 1
                repeat with i from firstPreviousIdx to (curIdx - 1)
                    set trk to track i of pl
                    set art to missing value
                    try
                        set art to raw data of artwork 1 of trk
                    end try
                    set end of results to {"previous", persistent ID of trk, name of trk, artist of trk, art}
                end repeat
                set lastIdx to curIdx + 2
                if lastIdx > (count of allIDs) then set lastIdx to count of allIDs
                repeat with i from (curIdx + 1) to lastIdx
                    set trk to track i of pl
                    set art to missing value
                    try
                        set art to raw data of artwork 1 of trk
                    end try
                    set end of results to {"upcoming", persistent ID of trk, name of trk, artist of trk, art}
                end repeat
            end try
            return results
        end tell
        """
        var err: NSDictionary?
        guard let list = NSAppleScript(source: script)?.executeAndReturnError(&err), err == nil,
              list.numberOfItems > 0 else { return nil }
        var previous: [MusicArtworkTrack] = []
        var current: MusicArtworkTrack?
        var upcoming: [MusicArtworkTrack] = []
        var shuffleEnabled = false
        for i in 1...list.numberOfItems {
            guard let row = list.atIndex(i),
                  let kind = row.atIndex(1)?.stringValue else { continue }
            if kind == "shuffle" {
                shuffleEnabled = row.atIndex(2)?.stringValue == "true"
                continue
            }
            guard row.numberOfItems >= 4,
                  let id = row.atIndex(2)?.stringValue,
                  let name = row.atIndex(3)?.stringValue else { continue }
            let artist = row.atIndex(4)?.stringValue ?? ""
            var image: NSImage?
            if row.numberOfItems >= 5, let data = row.atIndex(5)?.data, !data.isEmpty {
                image = musicArtworkImage(id: id, data: data)
            }
            let track = MusicArtworkTrack(id: id, title: name, artist: artist, artwork: image)
            if kind == "previous" { previous.append(track) }
            else if kind == "current" { current = track }
            else if kind == "upcoming" { upcoming.append(track) }
        }
        return MusicQueueSnapshot(
            previous: previous,
            current: current,
            upcoming: upcoming,
            shuffleEnabled: shuffleEnabled
        )
    }

    nonisolated private static func decodeArtworkImage(_ data: Data) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return NSImage(data: data)
        }
        let options: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 512,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return NSImage(data: data)
        }
        return NSImage(
            cgImage: image,
            size: NSSize(width: CGFloat(image.width), height: CGFloat(image.height))
        )
    }

    nonisolated private static func musicArtworkImage(id: String, data: Data) -> NSImage? {
        let key = id as NSString
        if let cached = musicArtworkCache.object(forKey: key) { return cached }
        guard let image = decodeArtworkImage(data) else { return nil }
        let cost = Int(image.size.width * image.size.height * 4)
        musicArtworkCache.setObject(image, forKey: key, cost: cost)
        return image
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

    private static func musicArtworkKey(_ title: String, _ artist: String) -> String {
        "\(title)\u{1F}\(artist)"
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
            guard let data, let img = Self.decodeArtworkImage(data) else {
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
        let key = Self.musicArtworkKey(title, artist)
        guard key != requestedMusicArtworkTrack else { return }
        requestedMusicArtworkTrack = key
        artworkTask?.cancel()
        artworkURL = nil

        if let cached = prefetchedMusicArtwork[key] {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                artwork = cached
            }
            return
        }

        artwork = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let image = Self.queryMusicArtwork().flatMap { Self.decodeArtworkImage($0) }
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
            self?.refreshSystemNowPlaying()
        }
        refreshWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func control(native script: @escaping (String) -> String, browser action: BrowserAction?) {
        let n = native
        let b = browserTrack
        let useBrowser = activeIsBrowser
        let useSystemNowPlaying = activeIsSystemNowPlaying
        let systemBundleID = systemNowPlayingTrack?.bundleIdentifier
        let systemNativeApp = Self.nativePlayerName(for: systemBundleID)
        controlQueue.async { [weak self] in
            guard let self else { return }
            if useBrowser, let b, let action {
                BrowserMedia.command(action, on: b)
            } else if useSystemNowPlaying {
                if let b, let action,
                   (systemBundleID == nil || systemBundleID == BrowserMedia.bundleID(forApp: b.app)) {
                    BrowserMedia.command(action, on: b)
                } else if let app = systemNativeApp {
                    var error: NSDictionary?
                    NSAppleScript(source: script(app))?.executeAndReturnError(&error)
                }
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
        } else if activeIsSystemNowPlaying {
            Self.sendMediaRemoteCommand(target ? 0 : 1)
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
        } else if !activeIsSystemNowPlaying {
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
        announceArtworkSkip(.next)
        position = 0
        positionDate = Date()
        lastActionTime = Date()
        queryEpoch += 1
        if activeIsBrowser, let b = browserTrack {
            controlQueue.async { BrowserMedia.command(.next, on: b) }
        } else if !activeIsSystemNowPlaying, let n = native {
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
        announceArtworkSkip(.previous)
        position = 0
        positionDate = Date()
        lastActionTime = Date()
        queryEpoch += 1
        if activeIsBrowser, let b = browserTrack {
            controlQueue.async { BrowserMedia.command(.previous, on: b) }
        } else if !activeIsSystemNowPlaying, let n = native {
            controlQueue.async {
                var error: NSDictionary?
                NSAppleScript(source: "tell application \"\(n.app)\" to previous track")?.executeAndReturnError(&error)
            }
        } else {
            Self.sendMediaRemoteCommand(5)
        }
        scheduleRefresh(delay: 0.35)
    }

    private func announceArtworkSkip(_ direction: NotchSwipeDirection) {
        guard hasTrack else { return }
        artworkSkipWorkItem?.cancel()
        artworkSkipWorkItem = nil

        let adjacentTrack: MusicArtworkTrack?
        let queueKey = "Music::\(title)::\(artist)"
        if sourceLabel == "Music",
           prefetchedMusicQueueTrackKey == queueKey,
           !shuffleOn,
           !prefetchedMusicQueueIsShuffled {
            switch direction {
            case .previous:
                adjacentTrack = previousQueueTracks.last
                if !previousQueueTracks.isEmpty { previousQueueTracks.removeLast() }
            case .next:
                adjacentTrack = prefetchedUpcomingTracks.first
                if !prefetchedUpcomingTracks.isEmpty { prefetchedUpcomingTracks.removeFirst() }
            }
        } else {
            adjacentTrack = nil
        }

        let cachedArtwork = adjacentTrack.flatMap { track in
            track.artwork ?? prefetchedMusicArtwork[Self.musicArtworkKey(track.title, track.artist)]
        }
        var artworkTransaction = Transaction()
        artworkTransaction.disablesAnimations = true
        withTransaction(artworkTransaction) {
            artworkSkipArtwork = cachedArtwork
        }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            artworkSkipDirection = direction
            artworkSkipAnimationID += 1
        }

        guard let cachedArtwork else {
            return
        }

        let skipID = artworkSkipAnimationID
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.artworkSkipAnimationID == skipID,
                  self.hasTrack,
                  self.sourceLabel == "Music" else { return }
            self.artworkTask?.cancel()
            self.artworkTask = nil
            self.artworkURL = nil
            withAnimation(.easeInOut(duration: 0.16)) {
                self.artwork = cachedArtwork
            }
        }
        artworkSkipWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30, execute: work)
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
        if sourceLabel == "Music" {
            prefetchedMusicQueueTrackKey = ""
            lastQueueFetchDate = .distantPast
        }
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
        let bundleID: String?
        if let n = native, !activeIsBrowser, !activeIsSystemNowPlaying {
            bundleID = n.app == "Spotify" ? "com.spotify.client" : "com.apple.Music"
        } else if activeIsSystemNowPlaying, let id = systemNowPlayingTrack?.bundleIdentifier {
            bundleID = id
        } else if activeIsBrowser, let b = browserTrack {
            bundleID = BrowserMedia.bundleID(forApp: b.app)
        } else {
            bundleID = systemNowPlayingTrack?.bundleIdentifier
        }
        guard let bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
