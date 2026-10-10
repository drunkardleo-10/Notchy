import SwiftUI

struct PermissionPayoff: View {
    let kind: PermissionKind
    @ObservedObject var model: OnboardingModel
    @ObservedObject var media: MediaController
    @ObservedObject var calendar: CalendarModel

    var body: some View {
        switch kind {
        case .accessibility: keys
        case .automation: nowPlaying
        case .calendar: nextEvent
        case .location: weather
        case .camera: CameraPayoff()
        }
    }

    @ViewBuilder
    private var keys: some View {
        switch model.hudEvent {
        case .volume(let level, let muted):
            meter(symbol: muted ? "speaker.slash.fill" : "speaker.wave.2.fill", level: muted ? 0 : level)
        case .brightness(let level):
            meter(symbol: "sun.max.fill", level: level)
        default:
            line(symbol: "keyboard", text: "Now press a volume key to try it.", pulse: true)
        }
    }

    private func meter(symbol: String, level: Float) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 18)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule().fill(Color.white).frame(width: proxy.size.width * CGFloat(max(0, min(1, level))))
                }
            }
            .frame(width: 180, height: 6)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: level)
        }
    }

    @ViewBuilder
    private var nowPlaying: some View {
        if media.hasTrack {
            HStack(spacing: 10) {
                ArtworkView(image: media.artwork, size: 34, cornerRadius: 7)
                VStack(alignment: .leading, spacing: 1) {
                    Text(media.title).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                    Text(media.artist).font(.system(size: 11)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                }
            }
            .transition(.opacity)
        } else {
            line(symbol: "play.fill", text: "Play something in Music or Spotify to see it here.", pulse: true)
        }
    }

    @ViewBuilder
    private var nextEvent: some View {
        if let event = calendar.events.first(where: { $0.end > Date() && !$0.isAllDay }) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(Color(nsColor: event.color)).frame(width: 4, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                    Text(event.start, format: .relative(presentation: .named))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        } else {
            line(symbol: "checkmark", text: "Your calendar is clear for now.", pulse: false)
        }
    }

    @ViewBuilder
    private var weather: some View {
        if let temperature = model.temperature {
            HStack(spacing: 8) {
                Image(systemName: "cloud.sun.fill").symbolRenderingMode(.multicolor).font(.system(size: 18))
                Text("\(temperature)°").font(.system(size: 20, weight: .semibold).monospacedDigit())
                Text("right now").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
            }
        } else {
            line(symbol: "location.fill", text: "Checking the weather near you.", pulse: true)
        }
    }

    private func line(symbol: String, text: String, pulse: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OnboardingTheme.success)
                .symbolEffect(.pulse, isActive: pulse)
            Text(text).font(.system(size: 12)).foregroundStyle(.white.opacity(0.75))
        }
    }
}

private struct CameraPayoff: View {
    @StateObject private var camera = CameraController()

    var body: some View {
        HStack(spacing: 10) {
            CameraPreview(session: camera.session)
                .frame(width: 72, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.white.opacity(0.15)))
            Text("Looking good.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.75))
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }
}
