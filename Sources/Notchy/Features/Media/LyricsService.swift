import AppKit
import Foundation
import SwiftUI

struct LyricLine: Identifiable, Equatable {
    let id: Int
    let time: Double
    let text: String
}

@MainActor
final class LyricsService: ObservableObject {
    @Published var lines: [LyricLine] = []
    @Published var hasLyrics: Bool = false
    @Published var isFetching: Bool = false
    @Published var plainText: String = ""

    private var currentTask: Task<Void, Never>?
    private var currentKey: String = ""

    private final class CacheEntry {
        let lines: [LyricLine]
        let plain: String
        init(lines: [LyricLine], plain: String) {
            self.lines = lines
            self.plain = plain
        }
    }

    private let cache = NSCache<NSString, CacheEntry>()

    func activeIndex(for position: Double) -> Int {
        guard !lines.isEmpty else { return 0 }
        let hasTimestamps = lines.contains { $0.time > 0 }
        guard hasTimestamps else { return 0 }
        let target = position + 0.15
        for index in stride(from: lines.count - 1, through: 0, by: -1) {
            if target >= lines[index].time {
                return index
            }
        }
        return 0
    }

    func update(title: String, artist: String, isAppleMusic: Bool) {
        let cleanTitle = normalized(title)
        let cleanArtist = normalized(artist)
        guard !cleanTitle.isEmpty else {
            clear()
            return
        }

        let key = "\(cleanTitle)|\(cleanArtist)"
        guard key != currentKey else { return }
        currentKey = key

        currentTask?.cancel()

        if let cached = cache.object(forKey: key as NSString) {
            lines = cached.lines
            plainText = cached.plain
            hasLyrics = !cached.lines.isEmpty || !cached.plain.isEmpty
            isFetching = false
            return
        }

        isFetching = true
        lines = []
        plainText = ""
        hasLyrics = false

        currentTask = Task { [weak self, key, cleanTitle, cleanArtist, isAppleMusic] in
            var fetchedLines: [LyricLine] = []
            var fetchedPlain = ""

            if isAppleMusic {
                if let appleLyrics = await Self.fetchAppleMusicLyrics() {
                    fetchedPlain = appleLyrics
                    fetchedLines = Self.parseLRC(appleLyrics)
                }
            }

            if fetchedLines.isEmpty && fetchedPlain.isEmpty {
                let webResult = await Self.fetchWebLyrics(title: cleanTitle, artist: cleanArtist)
                fetchedLines = webResult.lines
                fetchedPlain = webResult.plain
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard self?.currentKey == key else { return }
                self?.cache.setObject(CacheEntry(lines: fetchedLines, plain: fetchedPlain), forKey: key as NSString)
                self?.lines = fetchedLines
                self?.plainText = fetchedPlain
                self?.hasLyrics = !fetchedLines.isEmpty || !fetchedPlain.isEmpty
                self?.isFetching = false
            }
        }
    }

    func clear() {
        currentTask?.cancel()
        currentTask = nil
        currentKey = ""
        lines = []
        plainText = ""
        hasLyrics = false
        isFetching = false
    }

    private static func fetchAppleMusicLyrics() async -> String? {
        let scriptSource = """
        tell application "Music"
            if it is running then
                if player state is playing or player state is paused then
                    try
                        set l to lyrics of current track
                        if l is not missing value and l is not "" then
                            return l
                        end if
                    end try
                end if
            end if
        end tell
        """
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let script = NSAppleScript(source: scriptSource) {
                    let descriptor = script.executeAndReturnError(&error)
                    if error == nil, let string = descriptor.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
                        continuation.resume(returning: string)
                        return
                    }
                }
                continuation.resume(returning: nil)
            }
        }
    }

    private static func fetchWebLyrics(title: String, artist: String) async -> (lines: [LyricLine], plain: String) {
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return ([], "")
        }

        var searchURLs: [String] = []
        if !artist.isEmpty, let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            searchURLs.append("https://lrclib.net/api/search?track_name=\(encodedTitle)&artist_name=\(encodedArtist)")
        }
        searchURLs.append("https://lrclib.net/api/search?track_name=\(encodedTitle)")

        for urlString in searchURLs {
            guard let url = URL(string: urlString) else { continue }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 6
                request.setValue("Notchy/1.0", forHTTPHeaderField: "User-Agent")

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    continue
                }

                if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let best = findBestMatch(in: jsonArray, title: title, artist: artist) {
                    let synced = (best["syncedLyrics"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let plain = (best["plainLyrics"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    if !synced.isEmpty {
                        let parsed = parseLRC(synced)
                        if !parsed.isEmpty {
                            return (parsed, plain.isEmpty ? synced : plain)
                        }
                    }

                    if !plain.isEmpty {
                        let plainParsed = parsePlainLines(plain)
                        return (plainParsed, plain)
                    }
                }
            } catch {
                continue
            }
        }

        return ([], "")
    }

    private static func findBestMatch(in results: [[String: Any]], title: String, artist: String) -> [String: Any]? {
        guard !results.isEmpty else { return nil }
        if results.count == 1 { return results.first }

        let targetTitle = title.lowercased()
        let targetArtist = artist.lowercased()

        var bestMatch: [String: Any]?
        var bestScore = -1

        for result in results {
            var score = 0
            if let trackName = (result["trackName"] as? String)?.lowercased() {
                if trackName == targetTitle {
                    score += 10
                } else if trackName.contains(targetTitle) || targetTitle.contains(trackName) {
                    score += 5
                }
            }
            if !targetArtist.isEmpty, let artistName = (result["artistName"] as? String)?.lowercased() {
                if artistName == targetArtist {
                    score += 8
                } else if artistName.contains(targetArtist) || targetArtist.contains(artistName) {
                    score += 4
                }
            }
            if let synced = result["syncedLyrics"] as? String, !synced.isEmpty {
                score += 4
            } else if let plain = result["plainLyrics"] as? String, !plain.isEmpty {
                score += 2
            }

            if score > bestScore {
                bestScore = score
                bestMatch = result
            }
        }

        return bestMatch ?? results.first
    }

    static func parseLRC(_ lrc: String) -> [LyricLine] {
        let pattern = #"\[(\d+):(\d{2}(?:\.\d+)?)\](.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return parsePlainLines(lrc)
        }

        var lines: [LyricLine] = []
        var nextId = 0

        for line in lrc.components(separatedBy: .newlines) {
            let ns = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: ns.length))
            guard let match = matches.first else { continue }

            let minStr = ns.substring(with: match.range(at: 1))
            let secStr = ns.substring(with: match.range(at: 2))
            let text = ns.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)

            let minutes = Double(minStr) ?? 0
            let seconds = Double(secStr) ?? 0
            let totalTime = minutes * 60 + seconds

            if !text.isEmpty {
                lines.append(LyricLine(id: nextId, time: totalTime, text: text))
                nextId += 1
            }
        }

        if lines.isEmpty {
            return parsePlainLines(lrc)
        }

        return lines.sorted { $0.time < $1.time }
    }

    private static func parsePlainLines(_ plain: String) -> [LyricLine] {
        plain.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { LyricLine(id: $0.offset, time: 0, text: $0.element) }
    }

    private func normalized(_ str: String) -> String {
        str.folding(options: .diacriticInsensitive, locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
