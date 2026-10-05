import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

struct NotchView: View {
    @ObservedObject var state: NotchState
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var clipboard: ClipboardManager
    @ObservedObject var media: MediaController
    @ObservedObject var pomodoro: PomodoroModel
    @ObservedObject var calendar: CalendarModel
    @ObservedObject var agents: AgentMonitor
    @ObservedObject var system: SystemMonitor
    @ObservedObject var shortcuts: ShortcutsModel
    @ObservedObject var highAlert: HighAlertModel

    @Namespace private var tabNamespace
    @Namespace private var albumArtNamespace

    @AppStorage(Pref.shelf) private var shelfOn = true
    @AppStorage(Pref.clipboard) private var clipboardOn = true
    @AppStorage(Pref.media) private var mediaOn = true

    private var tabs: [NotchTab] {
        let active = NotchTab.allCases.filter { UserDefaults.standard.bool(forKey: $0.prefKey) }
        return active.isEmpty ? [.media] : active
    }

    private var activeTab: NotchTab {
        tabs.contains(state.tab) ? state.tab : (tabs.first ?? .media)
    }

    private var hudSize: CGSize? {
        guard !state.expanded, let hud = state.hud else { return nil }
        return HUDLayout.size(for: hud, notch: state.notchSize)
    }
    @AppStorage(Pref.liveActivity) private var liveOn = true
    @AppStorage(Pref.pausedActivityTimeout) private var pausedActivityTimeout = 5.0
    @State private var hidePausedActivity = false
    @State private var pausedActivityWork: DispatchWorkItem?

    private var showMediaActivity: Bool {
        guard liveOn, Pref.bool(Pref.media), media.hasTrack else { return false }
        return media.isPlaying || !hidePausedActivity
    }

    private var liveSize: CGSize? {
        guard !state.expanded else { return nil }
        if pomodoro.started {
            return NotchAccessoryLayout.size(
                notch: state.notchSize,
                leadingWidth: HUDLayout.sideWidth,
                trailingWidth: HUDLayout.sideWidth
            )
        }
        guard showMediaActivity else { return nil }
        return LiveActivityLayout.size(notch: state.notchSize)
    }
    private var collapsedSize: CGSize { hudSize ?? liveSize ?? state.notchSize }
    private var collapsedHorizontalOffset: CGFloat {
        guard !state.expanded, let hud = state.hud, case .volume = hud.kind else { return 0 }
        return NotchAccessoryLayout.centerOffset(
            leadingWidth: HUDLayout.volumeLeadingWidth,
            trailingWidth: HUDLayout.volumeTrailingWidth
        )
    }
    private var isCompact: Bool {
        tabs.count <= 1 && (activeTab == .media)
    }

    private var width: CGFloat { state.expanded ? state.expandedSize.width : collapsedSize.width }
    private var height: CGFloat { state.expanded ? state.expandedSize.height : collapsedSize.height }
    private var contentHorizontalInset: CGFloat {
        isCompact ? (state.showQueue ? 28 : 34) : 52
    }
    private var expansionAnimation: Animation {
        state.expanded
            ? NotchAnimation.notchOpen()
            : NotchAnimation.notchClose()
    }

    private var shape: NotchShape {
        let compact = state.expanded && isCompact
        return NotchShape(
            topRadius: state.expanded ? (compact ? 35 : 19) : 6,
            bottomRadius: state.expanded ? (compact ? 35 : 24) : 14
        )
    }

    private var notchBackground: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            LinearGradient(
                stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black, location: 0.22),
                    .init(color: .black.opacity(0.40), location: 0.42),
                    .init(color: .black.opacity(0.10), location: 0.60),
                    .init(color: .clear, location: 0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Color.black
                .opacity(state.expanded ? 0 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            shape.stroke(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.12), location: 0.50),
                        .init(color: .white.opacity(0.35), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.8
            )
            .opacity(state.expanded ? 1 : 0)
        }
        .overlay(alignment: .bottom) {
            if !state.expanded && !shelf.items.isEmpty && liveSize == nil {
                Circle().fill(.blue).frame(width: 5, height: 5).offset(y: -3)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                notchBackground

                if let hud = state.hud, let size = hudSize {
                    HUDView(hud: hud, notch: state.notchSize)
                        .frame(width: size.width, height: size.height)
                        .transition(.opacity.animation(expansionAnimation))
                }

                content
                    .frame(
                        width: state.expandedSize.width - contentHorizontalInset * 2,
                        height: state.expandedSize.height,
                        alignment: .top
                    )
                    .frame(width: width, height: height, alignment: .top)
                    .opacity(state.expanded ? 1 : 0)
                    .blur(radius: state.expanded ? 0 : 20)
            }
            .frame(width: width, height: height, alignment: .top)
            .clipShape(shape)
            .shadow(color: .black.opacity(state.expanded ? 0.35 : 0), radius: 14, y: 6)
            .overlay(alignment: .top) {
                if let volumeHUD {
                    VolumeHUDView(level: volumeHUD.level, muted: volumeHUD.muted, notch: state.notchSize)
                        .transition(.opacity.animation(expansionAnimation))
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .top) {
                if let size = liveSize {
                    Group {
                        if pomodoro.started { PomodoroPillView(pomodoro: pomodoro, notch: state.notchSize) }
                        else { LiveActivityView(media: media, notch: state.notchSize, albumArtNamespace: albumArtNamespace) }
                    }
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity.animation(expansionAnimation))
                    .zIndex(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(expansionAnimation, value: state.expanded)
        .animation(NotchAnimation.state, value: state.showQueue)
        .animation(expansionAnimation, value: state.hud?.id)
        .animation(expansionAnimation, value: liveSize != nil)
        .onChange(of: media.isPlaying) { _, _ in updatePausedActivityTimer() }
        .onChange(of: media.hasTrack) { _, _ in updatePausedActivityTimer() }
        .onChange(of: pausedActivityTimeout) { _, _ in
            guard !media.isPlaying, media.hasTrack else { return }
            schedulePausedActivityHide()
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $state.dropTargeted) { providers in
            guard Pref.bool(Pref.shelf) else { return false }
            state.tab = .shelf
            return shelf.handleDrop(providers)
        }
        .onAppear {
            updatePausedActivityTimer()
        }
    }

    private func updatePausedActivityTimer() {
        guard media.hasTrack && !media.isPlaying else {
            pausedActivityWork?.cancel()
            pausedActivityWork = nil
            hidePausedActivity = false
            return
        }
        schedulePausedActivityHide()
    }

    private func schedulePausedActivityHide() {
        pausedActivityWork?.cancel()
        hidePausedActivity = false
        let work = DispatchWorkItem { hidePausedActivity = true }
        pausedActivityWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, pausedActivityTimeout), execute: work)
    }

    private var content: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: max(state.notchSize.height + 4, 16))
            if tabs.count > 1 {
                tabBar
            }
            Group {
                switch activeTab {
                case .media: MediaView(media: media, state: state, albumArtNamespace: albumArtNamespace)
                case .shelf: ShelfView(shelf: shelf, targeted: state.dropTargeted)
                case .clipboard: ClipboardView(clipboard: clipboard)
                case .calendar: CalendarView(calendar: calendar)
                case .timer: TimerView(pomodoro: pomodoro)
                case .claude: ClaudeView(agents: agents)
                case .shortcuts: ShortcutsView(shortcuts: shortcuts)
                case .system: SystemView(system: system)
                case .mirror: MirrorView()
                case .tools: ToolsView(highAlert: highAlert)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(nil, value: activeTab)
        }
        .padding(.bottom, isCompact ? 22 : 20)
        .foregroundStyle(.white)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        state.tab = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .contentTransition(.symbolEffect)
                        if state.tab == tab {
                            Text(tab.title)
                                .lineLimit(1)
                                .fixedSize()
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background {
                        if state.tab == tab {
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                                .matchedGeometryEffect(id: "activeTabPill", in: tabNamespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(state.tab == tab ? .white : .white.opacity(0.55))
            }
            Spacer()
            Button { NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil) } label: {
                Image(systemName: "gearshape").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundStyle(.white.opacity(0.55))
        }
        .animation(NotchAnimation.tabSelect, value: state.tab)
    }
}

struct ShelfView: View {
    @ObservedObject var shelf: ShelfStore
    let targeted: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(targeted ? Color.blue : .white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                .background(targeted ? Color.blue.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 14))

            if shelf.items.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down.doc").font(.system(size: 22))
                    Text("Drop files here").font(.system(size: 12))
                }
                .foregroundStyle(.white.opacity(0.5))
            } else {
                HStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(shelf.items) { item in ShelfItemView(item: item, shelf: shelf) }
                        }
                        .padding(10)
                    }
                    VStack(spacing: 8) {
                        if let message = shelf.message {
                            Text(message).font(.system(size: 10)).foregroundStyle(.green)
                        }
                        if shelf.items.count > 1 {
                            Button("Zip all") { shelf.zip(shelf.items) }
                                .buttonStyle(.plain).font(.system(size: 11, weight: .medium))
                        }
                        Button("Clear") { shelf.clear() }
                            .buttonStyle(.plain).font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(width: 70).padding(.trailing, 6)
                }
            }
        }
    }
}

struct ShelfItemView: View {
    let item: ShelfItem
    @ObservedObject var shelf: ShelfStore
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 3) {
            Image(nsImage: item.icon).resizable().frame(width: 44, height: 44)
            Text(item.name).font(.system(size: 10)).lineLimit(1).frame(width: 64)
        }
        .padding(6)
        .background(hovering ? Color.white.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button { shelf.remove(item) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .gray)
                }.buttonStyle(.plain)
            }
        }
        .onHover { hovering = $0 }
        .onDrag { NSItemProvider(object: item.url as NSURL) }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(item.url) }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(item.url) }
            Button("Reveal in Finder") { shelf.reveal(item) }
            Button("Copy") { shelf.copy(item) }
            Button("AirDrop…") { shelf.airDrop(item) }
            Divider()
            Button("Zip") { shelf.zip([item]) }
            if shelf.isImage(item) {
                Button("Convert to PNG") { shelf.convert(item, to: .png) }
                Button("Convert to JPEG") { shelf.convert(item, to: .jpeg) }
            }
            Divider()
            Button("Remove") { shelf.remove(item) }
        }
    }
}

struct ClipboardView: View {
    @ObservedObject var clipboard: ClipboardManager
    @State private var query = ""
    @State private var status: String?

    private var filtered: [ClipItem] {
        let sorted = clipboard.items.sorted { $0.favorite && !$1.favorite }
        guard !query.isEmpty else { return sorted }
        return sorted.filter { $0.text?.localizedCaseInsensitiveContains(query) ?? false }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.5))
                TextField("Search clipboard history", text: $query).textFieldStyle(.plain).font(.system(size: 12))
                if let status { Text(status).font(.system(size: 10)).foregroundStyle(.green) }
                Button("Clear") { clipboard.clearUnfavorited() }
                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            if filtered.isEmpty {
                Spacer()
                Text("Nothing copied yet").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 4) { ForEach(filtered) { row($0) } }
                }
            }
        }
    }

    private func flash(_ message: String) {
        status = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { status = nil }
    }

    private func row(_ item: ClipItem) -> some View {
        HStack(spacing: 8) {
            if let text = item.text {
                Text(text).font(.system(size: 11)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            } else if let img = clipboard.image(for: item) {
                Image(nsImage: img).resizable().scaledToFit().frame(height: 30)
                Spacer()
                Button("OCR") { clipboard.ocr(item) { flash($0 ? "Text copied" : "No text found") } }
                    .buttonStyle(.plain).font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2).background(.white.opacity(0.15), in: Capsule())
            }
            Button { clipboard.toggleFavorite(item) } label: {
                Image(systemName: item.favorite ? "star.fill" : "star").foregroundStyle(item.favorite ? .yellow : .white.opacity(0.4))
            }.buttonStyle(.plain)
            Button { clipboard.delete(item) } label: {
                Image(systemName: "trash").foregroundStyle(.white.opacity(0.4))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { clipboard.copy(item); flash("Copied") }
    }
}

struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat
    let cornerRadius: CGFloat
    var namespace: Namespace.ID? = nil

    @ViewBuilder
    var body: some View {
        let artwork = ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white.opacity(0.08))

            if let image {
                let img = Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                img
                    .id(image)
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 0.90))
                                .animation(NotchAnimation.notchOpen()),
                            removal: .opacity
                                .combined(with: .scale(scale: 1.06))
                                .animation(NotchAnimation.notchClose())
                        )
                    )
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(.white.opacity(0.5))
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

        if let namespace {
            artwork.matchedGeometryEffect(id: "albumArt", in: namespace)
        } else {
            artwork
        }
    }
}

struct MediaControlButtonStyle: ButtonStyle {
    var isActive: Bool = false
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 36, height: 36)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.18))
                } else if hovering || configuration.isPressed {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0.10))
                }
            }
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.85 : (hovering ? 1.05 : 1.0))
            .animation(NotchAnimation.press, value: configuration.isPressed)
            .animation(NotchAnimation.hover, value: hovering)
            .onHover { hovering = $0 }
    }
}

struct PlayingNextView: View {
    @ObservedObject var media: MediaController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Playing Next")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.leading, 6)

            if media.queueTracks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                    Text(media.queueSupported ? "Nothing queued" : "\(media.sourceLabel) doesn't share its queue")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(media.queueSupported ? "Add songs to Up Next in Music" : "Up Next is available for Apple Music")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.leading, 6)
                .padding(.top, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(media.queueTracks.prefix(2)) { track in
                        QueueTrackRow(track: track) {
                            media.playQueueTrack(track)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct QueueTrackRow: View {
    let track: QueueTrack
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    if let img = track.artwork {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        LinearGradient(
                            colors: [track.accent, track.accent.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: track.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(hovering ? 0.75 : 0.35))
                    .padding(.trailing, 6)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background {
                if hovering {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct MediaView: View {
    @ObservedObject var media: MediaController
    @ObservedObject var state: NotchState
    var albumArtNamespace: Namespace.ID? = nil
    @State private var favorite = false

    var body: some View {
        if !media.hasTrack {
            VStack(spacing: 4) {
                Image(systemName: "music.note").font(.system(size: 20))
                Text("Nothing playing").font(.system(size: 12, weight: .medium))
                Text("Play something in Music, Spotify or a browser tab").font(.system(size: 10))
            }
            .foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 0) {
                playerSection
                    .frame(width: state.showQueue ? 412 : nil)

                if state.showQueue {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))

                    PlayingNextView(media: media)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .animation(NotchAnimation.state, value: state.showQueue)
        }
    }

    private var playerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ArtworkView(image: media.artwork, size: 52, cornerRadius: 13, namespace: albumArtNamespace)
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(media.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    Text(media.artist.isEmpty ? media.sourceLabel : media.artist)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                EqualizerBars(active: media.isPlaying, useGradient: true)
            }

            SeekBar(media: media)

            controls
        }
        .padding(.horizontal, 16)
    }

    private var controls: some View {
        ZStack {
            HStack {
                HStack(spacing: 6) {
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                            state.showQueue.toggle()
                        }
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(MediaControlButtonStyle(isActive: state.showQueue))

                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 1, height: 14)

                    Button { favorite.toggle() } label: {
                        Image(systemName: favorite ? "star.fill" : "star")
                            .contentTransition(.symbolEffect)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(favorite ? .yellow : .white)
                    }
                    .buttonStyle(MediaControlButtonStyle())
                }

                Spacer()

                HStack(spacing: 6) {
                    Button { media.toggleShuffle() } label: {
                        Image(systemName: "shuffle")
                            .contentTransition(.symbolEffect)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(media.shuffleOn ? Color.green : (media.canShuffle ? .white : .white.opacity(0.35)))
                    }
                    .buttonStyle(MediaControlButtonStyle())
                    .disabled(!media.canShuffle)

                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 1, height: 14)

                    Button {
                        NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(MediaControlButtonStyle())
                }
            }

            HStack(spacing: 20) {
                Button { media.previous() } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20, weight: .bold))
                }
                .buttonStyle(MediaControlButtonStyle())

                Button { media.playPause() } label: {
                    Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect)
                        .font(.system(size: 28, weight: .bold))
                }
                .buttonStyle(MediaControlButtonStyle())

                Button { media.next() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20, weight: .bold))
                }
                .buttonStyle(MediaControlButtonStyle())
            }
        }
    }
}

struct SeekBar: View {
    @ObservedObject var media: MediaController
    @State private var dragFraction: Double?
    @State private var isDragging = false

    private func format(_ seconds: Double) -> String {
        let s = Int(max(0, seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    var body: some View {
        TimelineView(.animation(paused: !media.isPlaying && dragFraction == nil)) { context in
            let currentPos = dragFraction.map { $0 * media.duration } ?? media.currentPosition(at: context.date)
            let fraction = media.duration > 0 ? min(max(currentPos / media.duration, 0), 1) : 0
            let remaining = max(0, media.duration - currentPos)
            HStack(spacing: 10) {
                Text(format(currentPos))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(minWidth: 28, alignment: .leading)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.20))
                        Capsule().fill(Color.white).frame(width: max(0, geo.size.width * fraction))
                    }
                    .frame(height: 5)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let target = min(max(value.location.x / geo.size.width, 0), 1)
                                if !isDragging {
                                    isDragging = true
                                    withAnimation(.interpolatingSpring(mass: 0.8, stiffness: 350, damping: 28)) {
                                        dragFraction = target
                                    }
                                } else {
                                    withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.82)) {
                                        dragFraction = target
                                    }
                                }
                            }
                            .onEnded { value in
                                let target = min(max(value.location.x / geo.size.width, 0), 1)
                                withAnimation(.interpolatingSpring(mass: 0.8, stiffness: 350, damping: 28)) {
                                    dragFraction = target
                                }
                                isDragging = false
                                media.seek(to: target * media.duration)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    if !isDragging {
                                        dragFraction = nil
                                    }
                                }
                            }
                    )
                }
                .frame(height: 12)

                Text(media.duration > 0 ? "-\(format(remaining))" : "0:00")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(minWidth: 34, alignment: .trailing)
            }
        }
        .opacity(media.duration > 0 ? 1 : 0.35)
        .allowsHitTesting(media.duration > 0)
    }
}
