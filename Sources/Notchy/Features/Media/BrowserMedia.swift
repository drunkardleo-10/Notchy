import AppKit
import CoreAudio

struct BrowserTrack: Equatable {
    var app: String
    var url: String
    var title: String
    var artist: String
    var playing: Bool
    var artworkURL: String
    var service: String
    var preciseState = true
    var position: Double = 0
    var duration: Double = 0
    var loop = false
    var isFavorite = false
}

enum BrowserAction {
    case playPause, play, pause, next, previous, toggleLoop, toggleLike
    case seek(Double)

    var js: String {
        switch self {
        case .toggleLoop: "var v=document.querySelector('video,audio');if(v){v.loop=!v.loop}"
        case .toggleLike: "var ytl=document.querySelector('ytmusic-like-button-renderer #button-shape-like button');if(ytl){ytl.click()}else{var ytb=document.querySelector('like-button-view-model button,#segmented-like-button button');if(ytb){ytb.click()}else{var sc=document.querySelector('.playControls__like,.playbackSoundBadge__like');if(sc){sc.click()}else{var sp=document.querySelector('button[data-testid=\"add-button\"],button[aria-label=\"Save to Your Library\"],button[aria-label=\"Remove from Your Library\"]');if(sp){sp.click()}}}}"
        case .seek(let t): "var v=document.querySelector('video,audio');if(v){v.currentTime=\(t)}"
        case .playPause: "var b=document.querySelector('.ytp-play-button,.play-pause-button,.playControls__play,button[data-testid=\"control-button-playpause\"]');if(b){b.click()}else{var v=document.querySelector('video,audio');if(v){v.paused?v.play():v.pause()}}"
        case .play: "var v=document.querySelector('video,audio');if(v&&v.paused){v.play()}else{var b=document.querySelector('.ytp-play-button,.play-pause-button,.playControls__play,button[data-testid=\"control-button-playpause\"]');if(b)b.click()}"
        case .pause: "var v=document.querySelector('video,audio');if(v&&!v.paused){v.pause()}else{var b=document.querySelector('.ytp-play-button,.play-pause-button,.playControls__play,button[data-testid=\"control-button-playpause\"]');if(b)b.click()}"
        case .next: "var b=document.querySelector('.ytp-next-button,.next-button,.playControls__next,button.skipControl__next,button[data-testid=\"control-button-skip-forward\"],button[aria-label=\"Next\"]');if(b){b.click()}"
        case .previous: "var b=document.querySelector('.ytp-prev-button,.previous-button,.playControls__prev,button.skipControl__previous,button[data-testid=\"control-button-skip-back\"],button[aria-label=\"Previous\"]');if(b){b.click()}else{var v=document.querySelector('video,audio');if(v){v.currentTime=0}}"
        }
    }
}

enum BrowserMedia {
    private struct Browser { let name: String; let bundleID: String; let safari: Bool }

    private static let browsers = [
        Browser(name: "Google Chrome", bundleID: "com.google.Chrome", safari: false),
        Browser(name: "Brave Browser", bundleID: "com.brave.Browser", safari: false),
        Browser(name: "Arc", bundleID: "company.thebrowser.Browser", safari: false),
        Browser(name: "Microsoft Edge", bundleID: "com.microsoft.edgemac", safari: false),
        Browser(name: "Comet", bundleID: "ai.perplexity.comet", safari: false),
        Browser(name: "Dia", bundleID: "company.thebrowser.dia", safari: false),
        Browser(name: "Vivaldi", bundleID: "com.vivaldi.Vivaldi", safari: false),
        Browser(name: "Opera", bundleID: "com.operasoftware.Opera", safari: false),
        Browser(name: "Chromium", bundleID: "org.chromium.Chromium", safari: false),
        Browser(name: "Safari", bundleID: "com.apple.Safari", safari: true),
    ]

    private static let urlCondition = ["youtube.com/watch", "music.youtube.com", "youtube.com/shorts", "soundcloud.com", "open.spotify.com"]
        .map { "(u contains \"\($0)\")" }.joined(separator: " or ")

    private static let probeJS = "(function(){var v=document.querySelector('video,audio');var ms=navigator.mediaSession;var p=ms&&ms.playbackState==='playing'?true:(ms&&ms.playbackState==='paused'?false:(v?!v.paused:false));var m=ms&&ms.metadata;var a='';if(m&&m.artwork&&m.artwork.length){a=m.artwork[m.artwork.length-1].src}var fav=false;var ytl=document.querySelector('ytmusic-like-button-renderer');if(ytl){fav=ytl.getAttribute('like-status')==='LIKE'}if(!fav){var ytb=document.querySelector('like-button-view-model button,#segmented-like-button button');if(ytb){fav=ytb.getAttribute('aria-pressed')==='true'}}if(!fav){var sc=document.querySelector('.playControls__like,.playbackSoundBadge__like');if(sc){fav=sc.classList.contains('sc-button-selected')||sc.getAttribute('aria-label')==='Unlike'||sc.title==='Unlike'}}if(!fav){var sp=document.querySelector('button[data-testid=\"add-button\"],button[aria-label=\"Save to Your Library\"],button[aria-label=\"Remove from Your Library\"]');if(sp){fav=sp.getAttribute('aria-checked')==='true'||sp.getAttribute('aria-label')==='Remove from Your Library'}}return JSON.stringify({p:p,t:m?m.title:'',a:m?m.artist:'',i:a,c:v?v.currentTime:0,d:(v&&isFinite(v.duration))?v.duration:0,l:v?v.loop:false,f:fav})})()"

    static func bundleID(forApp name: String) -> String? { browsers.first { $0.name == name }?.bundleID }

    @MainActor
    static func runningBrowserNames() -> [String] {
        browsers.filter { !NSRunningApplication.runningApplications(withBundleIdentifier: $0.bundleID).isEmpty }.map(\.name)
    }

    private static func escaped(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func run(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil ? result?.stringValue : nil
    }

    nonisolated static func isOutputtingAudio(bundlePrefix: String) -> Bool {
        var listAddr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                                  mScope: kAudioObjectPropertyScopeGlobal,
                                                  mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &listAddr, 0, nil, &size) == noErr, size > 0 else { return false }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &listAddr, 0, nil, &size, &ids) == noErr else { return false }

        for id in ids {
            var idAddr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyBundleID,
                                                    mScope: kAudioObjectPropertyScopeGlobal,
                                                    mElement: kAudioObjectPropertyElementMain)
            var bundle: Unmanaged<CFString>?
            var bundleSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &idAddr, 0, nil, &bundleSize, &bundle) == noErr,
                  let name = bundle?.takeRetainedValue() as String?, name.hasPrefix(bundlePrefix) else { continue }

            var runAddr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyIsRunningOutput,
                                                     mScope: kAudioObjectPropertyScopeGlobal,
                                                     mElement: kAudioObjectPropertyElementMain)
            var running: UInt32 = 0
            var runSize = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(id, &runAddr, 0, nil, &runSize, &running) == noErr, running != 0 { return true }
        }
        return false
    }

    nonisolated static func scan(browserNames: [String], preferredURL: String? = nil) -> BrowserTrack? {
        var found: [BrowserTrack] = []
        for browser in browsers where browserNames.contains(browser.name) {
            let titleExpr = browser.safari ? "name of t" : "title of t"
            let jsCall = browser.safari ? "do JavaScript \"\(escaped(probeJS))\" in t" : "execute t javascript \"\(escaped(probeJS))\""
            let source = """
            tell application "\(browser.name)"
                set out to ""
                repeat with w in windows
                    repeat with t in tabs of w
                        set u to URL of t
                        if \(urlCondition) then
                            set r to ""
                            try
                                set r to \(jsCall)
                            end try
                            set out to out & u & "|||" & (\(titleExpr)) & "|||" & r & linefeed
                        end if
                    end repeat
                end repeat
                return out
            end tell
            """
            guard let output = run(source) else { continue }
            let audioPlaying = isOutputtingAudio(bundlePrefix: browser.bundleID)
            for line in output.components(separatedBy: "\n") {
                let parts = line.components(separatedBy: "|||")
                guard parts.count >= 3, let track = parse(app: browser.name, url: parts[0], tabTitle: parts[1], json: parts[2],
                                                          audioPlaying: audioPlaying) else { continue }
                found.append(track)
            }
        }
        if let pref = preferredURL, let match = found.first(where: { $0.url == pref && $0.playing }) {
            return match
        }
        if let pref = preferredURL, let match = found.first(where: { $0.url == pref }) {
            return match
        }
        return found.first(where: \.playing) ?? found.first
    }

    nonisolated static func command(_ action: BrowserAction, on track: BrowserTrack) {
        guard let browser = browsers.first(where: { $0.name == track.app }) else { return }
        let jsCall = browser.safari ? "do JavaScript \"\(escaped(action.js))\" in t" : "execute t javascript \"\(escaped(action.js))\""
        _ = run("""
        tell application "\(browser.name)"
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t) is "\(escaped(track.url))" then
                        try
                            \(jsCall)
                        end try
                        return
                    end if
                end repeat
            end repeat
        end tell
        """)
    }

    private nonisolated static func parse(app: String, url: String, tabTitle: String, json: String, audioPlaying: Bool) -> BrowserTrack? {
        let service = serviceName(for: url)
        var meta: [String: Any] = [:]
        if let data = json.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            meta = obj
        }
        let jsWorked = !meta.isEmpty
        let metaTitle = (meta["t"] as? String) ?? ""
        let title = metaTitle.isEmpty ? cleanTitle(tabTitle) : metaTitle
        guard !title.isEmpty else { return nil }

        var artwork = (meta["i"] as? String) ?? ""
        if artwork.isEmpty, let id = youtubeID(from: url) { artwork = "https://i.ytimg.com/vi/\(id)/hqdefault.jpg" }

        return BrowserTrack(app: app, url: url, title: title,
                            artist: (meta["a"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? service,
                            playing: jsWorked ? (meta["p"] as? Bool ?? false) : audioPlaying,
                            artworkURL: artwork, service: service, preciseState: jsWorked,
                            position: (meta["c"] as? Double) ?? 0, duration: (meta["d"] as? Double) ?? 0,
                            loop: (meta["l"] as? Bool) ?? false,
                            isFavorite: (meta["f"] as? Bool) ?? false)
    }

    private nonisolated static func serviceName(for url: String) -> String {
        if url.contains("music.youtube.com") { return "YouTube Music" }
        if url.contains("youtube.com") { return "YouTube" }
        if url.contains("soundcloud.com") { return "SoundCloud" }
        if url.contains("spotify.com") { return "Spotify" }
        return "Browser"
    }

    private nonisolated static func cleanTitle(_ raw: String) -> String {
        var t = raw
        for suffix in [" - YouTube Music", " - YouTube", " | SoundCloud", " | Spotify", " • Spotify"] where t.hasSuffix(suffix) {
            t = String(t.dropLast(suffix.count))
        }
        if t.hasPrefix("("), let close = t.firstIndex(of: ")"), t[t.index(after: t.startIndex)..<close].allSatisfy(\.isNumber) {
            t = String(t[t.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        }
        return t
    }

    private nonisolated static func youtubeID(from url: String) -> String? {
        guard url.contains("youtube.com/watch"), let comps = URLComponents(string: url) else { return nil }
        return comps.queryItems?.first(where: { $0.name == "v" })?.value
    }
}
