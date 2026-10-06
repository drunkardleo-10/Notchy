import Combine

@MainActor
final class AudioVisualizer: ObservableObject {
    static let shared = AudioVisualizer()

    nonisolated static let barCount = 6
    @Published private(set) var levels = [Float](repeating: 0, count: barCount)

    private let capture = ProcessAudioCapture()

    private init() {}

    func follow(bundleIdentifiers: [String], isPlaying: Bool) {
        let bundleIdentifiers = Array(Set(bundleIdentifiers)).sorted()
        capture.setBundleIdentifiers(isPlaying ? bundleIdentifiers : [])
    }

    func publish(_ values: [Float]) {
        guard values.count == Self.barCount else { return }
        levels = values
    }
}
