import SwiftUI
import AppKit
import UniformTypeIdentifiers
import QuickLookThumbnailing

private struct AccessoryTransitionModifier: ViewModifier {
    let blur: CGFloat
    let opacity: Double
    let scale: CGFloat

    func body(content: Content) -> some View {
        content.blur(radius: blur).opacity(opacity).scaleEffect(scale)
    }
}

private extension AnyTransition {
    static var accessoryBlur: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: AccessoryTransitionModifier(blur: 7, opacity: 0, scale: 1),
                identity: AccessoryTransitionModifier(blur: 0, opacity: 1, scale: 1)
            ),
            removal: .modifier(
                active: AccessoryTransitionModifier(blur: 7, opacity: 0, scale: 1),
                identity: AccessoryTransitionModifier(blur: 0, opacity: 1, scale: 1)
            )
        )
    }
}

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

    @Namespace private var albumArtNamespace
    @Namespace private var visualizerNamespace

    @AppStorage(Pref.shelf) private var shelfOn = true
    @AppStorage(Pref.clipboard) private var clipboardOn = true
    @AppStorage(Pref.media) private var mediaOn = true
    @AppStorage(Pref.glassLevel) private var glassLevel = 0.5
    @AppStorage(Pref.volumeHUDStyle) private var volumeHUDStyleRawValue = VolumeHUDStyle.inline.rawValue
    @AppStorage(Pref.notchAnimationSpeed) private var animationSpeedRawValue = NotchAnimationSpeed.normal.rawValue

    private var volumeHUDStyle: VolumeHUDStyle {
        VolumeHUDStyle(rawValue: volumeHUDStyleRawValue) ?? .inline
    }

    private var tabs: [NotchTab] {
        NotchTab.available
    }

    private var activeTab: NotchTab {
        tabs.contains(state.tab) ? state.tab : (tabs.first ?? .media)
    }

    private var hudSize: CGSize? {
        guard !state.expanded, let hud = state.hud else { return nil }
        return HUDLayout.size(for: hud, notch: state.notchSize, volumeStyle: volumeHUDStyle)
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
        guard !state.expanded, let hud = state.hud else { return 0 }
        switch hud.kind {
        case .volume, .brightness:
            guard volumeHUDStyle == .inline else { return 0 }
            return NotchAccessoryLayout.centerOffset(
                leadingWidth: HUDLayout.volumeLeadingWidth(for: volumeHUDStyle),
                trailingWidth: HUDLayout.volumeTrailingWidth(for: volumeHUDStyle)
            )
        case .lock, .capsLock:
            guard volumeHUDStyle == .inline else { return 0 }
            return NotchAccessoryLayout.centerOffset(
                leadingWidth: HUDLayout.inlineSymbolLeadingWidth,
                trailingWidth: HUDLayout.inlineSymbolTrailingWidth
            )
        default:
            return 0
        }
    }
    private var isCompact: Bool {
        !(state.showQueue || state.showLyrics)
    }

    private var width: CGFloat { state.expanded ? state.expandedSize.width : collapsedSize.width }
    private var height: CGFloat { state.expanded ? state.expandedSize.height : collapsedSize.height }
    private var contentHorizontalInset: CGFloat {
        24
    }
    private var expansionAnimation: Animation {
        state.expanded
            ? NotchAnimation.notchOpen()
            : NotchAnimation.notchClose()
    }

    private var shape: NotchShape {
        let compact = state.expanded && isCompact
        return NotchShape(
            topRadius: state.expanded ? (compact ? 35 : 19) : (isPeekHUD ? 8 : 6),
            bottomRadius: state.expanded ? (compact ? 35 : 24) : (isPeekHUD ? 12 : 14)
        )
    }

    private var isPeekHUD: Bool {
        guard !state.expanded, let hud = state.hud else { return false }
        switch hud.kind {
        case .volume, .brightness, .lock, .capsLock:
            return volumeHUDStyle == .peek
        default:
            return false
        }
    }

    private var hidesLiveActivityForHUD: Bool {
        guard state.hud != nil else { return false }
        return !isPeekHUD
    }

    private var notchBackground: some View {
        ZStack {
            if #available(macOS 26.0, *) {
                Color.clear.glassEffect(.clear, in: shape)
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }

            Color.black.opacity(DynamicGlassStyle.blackOpacity(for: glassLevel))

            DynamicGlassGradient(expansion: state.expanded ? 1 : 0)
                .animation(expansionAnimation, value: state.expanded)
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
            if !state.expanded && !shelf.items.isEmpty && liveSize == nil && state.hud == nil {
                Circle().fill(.blue).frame(width: 5, height: 5).offset(y: -3)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                notchBackground

                if let hud = state.hud, let size = hudSize {
                    Group {
                        if case .volume(let level, let muted) = hud.kind {
                            VolumeHUDView(level: level, muted: muted, notch: state.notchSize, style: volumeHUDStyle)
                        } else {
                            HUDView(hud: hud, notch: state.notchSize, volumeStyle: volumeHUDStyle)
                        }
                    }
                    .frame(width: size.width, height: size.height)
                    .transition(.accessoryBlur.animation(expansionAnimation))
                }

                content
                    .frame(
                        width: state.expandedSize.width - contentHorizontalInset * 2,
                        height: state.expandedSize.height,
                        alignment: .top
                    )
                    .opacity(state.expanded ? 1 : 0)
                    .blur(radius: state.expanded ? 0 : 20)
                    .allowsHitTesting(state.expanded)
                    .accessibilityHidden(!state.expanded)

                if let size = liveSize {
                    Group {
                        if pomodoro.started { PomodoroPillView(pomodoro: pomodoro, notch: state.notchSize) }
                        else {
                            LiveActivityView(
                                media: media,
                                notch: state.notchSize,
                                albumArtNamespace: hidesLiveActivityForHUD ? nil : albumArtNamespace,
                                visualizerNamespace: hidesLiveActivityForHUD ? nil : visualizerNamespace,
                                state: state
                            )
                        }
                    }
                    .frame(width: size.width, height: size.height)
                    .blur(radius: (hidesLiveActivityForHUD || state.expanded) ? 7 : 0)
                    .opacity((state.expanded || hidesLiveActivityForHUD) ? 0 : 1)
                    .allowsHitTesting(!state.expanded)
                    .accessibilityHidden(state.expanded)
                    .transition(.opacity.animation(expansionAnimation))
                    .zIndex(1)
                }
            }
            .frame(width: width, height: height, alignment: .top)
            .clipShape(shape)
            .shadow(color: .black.opacity(state.expanded ? 0.35 : 0), radius: 14, y: 6)
            .offset(x: collapsedHorizontalOffset)
            .scaleEffect(!state.expanded && state.hoveringNotch ? 1.05 : 1.0, anchor: .top)
            .overlay(alignment: .trailing) {
                if tabs.count > 1 {
                    ModuleNavigationPill(tabs: tabs, selection: activeTab, onSelect: state.selectTab)
                        .blur(radius: state.expanded ? 0 : 10)
                        .opacity(state.expanded ? 1 : 0)
                        .scaleEffect(state.expanded ? 1 : 0.84)
                        .offset(
                            x: ModuleNavigationMetrics.width
                                + ModuleNavigationMetrics.gap
                                - (state.expanded ? 0 : ModuleNavigationMetrics.openingTravel)
                        )
                        .animation(expansionAnimation, value: state.expanded)
                        .allowsHitTesting(state.expanded)
                        .accessibilityHidden(!state.expanded)
                        .zIndex(2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(expansionAnimation, value: state.expanded)
        .animation(expansionAnimation, value: animationSpeedRawValue)
        .animation(NotchAnimation.state, value: state.showQueue)
        .animation(NotchAnimation.state, value: state.showLyrics)
        .animation(expansionAnimation, value: state.hud?.id)
        .animation(expansionAnimation, value: volumeHUDStyleRawValue)
        .animation(expansionAnimation, value: liveSize != nil)
        .onChange(of: media.isPlaying) { _, _ in updatePausedActivityTimer() }
        .onChange(of: media.hasTrack) { _, _ in updatePausedActivityTimer() }
        .onChange(of: pausedActivityTimeout) { _, _ in
            guard !media.isPlaying, media.hasTrack else { return }
            schedulePausedActivityHide()
        }
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data, .item], isTargeted: $state.dropTargeted) { providers in
            guard Pref.bool(Pref.shelf) else { return false }
            state.tab = .shelf
            return shelf.handleDrop(providers)
        }
        .onChange(of: state.dropTargeted) { _, targeted in
            if targeted && Pref.bool(Pref.shelf) {
                state.tab = .shelf
            }
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
        VStack(spacing: 4) {
            Spacer().frame(height: max(state.notchSize.height + 4, 16))
            Group {
                switch activeTab {
                case .media: MediaView(
                    media: media,
                    state: state,
                    albumArtNamespace: albumArtNamespace,
                    visualizerNamespace: visualizerNamespace
                )
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
            .transition(.asymmetric(
                insertion: .move(edge: state.tabNavigationDirection > 0 ? .bottom : .top).combined(with: .opacity),
                removal: .move(edge: state.tabNavigationDirection > 0 ? .top : .bottom).combined(with: .opacity)
            ))
            .animation(NotchAnimation.tabSelect, value: activeTab)
        }
        .padding(.bottom, isCompact ? 18 : 20)
        .foregroundStyle(.white)
    }
}

struct ShelfView: View {
    @ObservedObject var shelf: ShelfStore
    let targeted: Bool
    @State private var isTargeted = false

    private var activeTargeted: Bool {
        targeted || isTargeted
    }

    var body: some View {
        ZStack {
            if shelf.items.isEmpty {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        activeTargeted ? Color.blue : Color.white.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(activeTargeted ? Color.blue.opacity(0.12) : Color.white.opacity(0.03))
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(activeTargeted ? Color.blue : Color.white.opacity(0.7))

                            Text("Drop files here")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.85))

                            Text("Release to hold on shelf")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }
            } else {
                HStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(shelf.items) { item in
                                ShelfItemView(item: item, shelf: shelf)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                    }

                    VStack(spacing: 8) {
                        if let message = shelf.message {
                            Text(message)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.green)
                        }
                        if shelf.items.count > 1 {
                            Button {
                                shelf.zip(shelf.items)
                            } label: {
                                Image(systemName: "archivebox.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Color.white.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                            .help("Zip all")
                        }
                        Button {
                            shelf.clear()
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                        .help("Clear shelf")
                    }
                    .frame(width: 44)
                    .padding(.trailing, 16)
                }
                .overlay {
                    if activeTargeted {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.blue.opacity(0.08)))
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data, .item], isTargeted: $isTargeted) { providers in
            shelf.handleDrop(providers)
        }
    }
}

struct ShelfItemView: View {
    let item: ShelfItem
    @ObservedObject var shelf: ShelfStore
    @State private var hovering = false
    @State private var thumbnail: NSImage?

    private let thumbWidth: CGFloat = 92
    private let thumbHeight: CGFloat = 60

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.45))

                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: thumbWidth, height: thumbHeight)
                        .clipped()
                } else {
                    Image(nsImage: item.icon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                }
            }
            .frame(width: thumbWidth, height: thumbHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(hovering ? 0.35 : 0.12), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if hovering {
                    Button {
                        shelf.remove(item)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color(white: 0.15).opacity(0.95)))
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: -6)
                }
            }
            .overlay(alignment: .bottom) {
                if hovering {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.blue))
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                        .shadow(color: .blue.opacity(0.4), radius: 3, y: 1)
                        .offset(y: 9)
                }
            }

            Text(item.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: thumbWidth + 10)
        }
        .padding(.top, 6)
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
        .task(id: item.url) {
            if let loaded = await Self.loadThumbnail(for: item.url, size: CGSize(width: thumbWidth * 2, height: thumbHeight * 2)) {
                thumbnail = loaded
            }
        }
    }

    private static func loadThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) {
            if let img = NSImage(contentsOf: url) {
                return img
            }
        }
        let scale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2.0 }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
                if let cgImage = thumbnail?.cgImage {
                    let image = NSImage(cgImage: cgImage, size: size)
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
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
    var isSource: Bool = true
    var showsBorder = false
    var skipAnimationID: Int = 0
    var skipDirection: NotchSwipeDirection? = nil
    var skipArtwork: NSImage? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flipAngle: Double = 0
    @State private var flipBlur: CGFloat = 0
    @State private var activeFlipID = 0
    @State private var showingBackFace = false

    @ViewBuilder
    var body: some View {
        let artwork = ZStack {
            cardFace(image)
                .opacity(showingBackFace ? 0 : 1)
            cardFace(skipArtwork ?? image)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showingBackFace ? 1 : 0)
        }

        Group {
            if let namespace {
                artwork.matchedGeometryEffect(id: "albumArt", in: namespace, isSource: isSource)
            } else {
                artwork
            }
        }
        .frame(width: size, height: size)
        .rotation3DEffect(
            .degrees(flipAngle),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.72
        )
        .blur(radius: flipBlur)
        .onChange(of: skipAnimationID) { _, newID in
            guard newID != 0, activeFlipID != newID, !reduceMotion, let skipDirection else { return }
            activeFlipID = newID
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                flipAngle = 0
                flipBlur = 0
                showingBackFace = false
            }

            let flipTarget: Double = skipDirection == .next ? -180 : 180
            withAnimation(.easeInOut(duration: 0.56)) {
                flipAngle = flipTarget
            }
            withAnimation(.easeOut(duration: 0.14)) {
                flipBlur = 1.25
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                guard activeFlipID == newID else { return }
                showingBackFace = true
                withAnimation(.easeOut(duration: 0.24)) {
                    flipBlur = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
                guard activeFlipID == newID else { return }
                var finish = Transaction()
                finish.disablesAnimations = true
                withTransaction(finish) {
                    flipAngle = 0
                    flipBlur = 0
                    showingBackFace = false
                }
            }
        }
    }

    @ViewBuilder
    private func cardFace(_ faceImage: NSImage?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white.opacity(0.08))

            if let faceImage {
                Image(nsImage: faceImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .id(faceImage)
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
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            if showsBorder {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            }
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
                    Circle()
                        .fill(Color.white.opacity(0.20))
                } else if hovering || configuration.isPressed {
                    Circle()
                        .fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0.10))
                }
            }
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.96 : (hovering ? 1.05 : 1.0))
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

struct LiveLyricsView: View {
    @ObservedObject var lyrics: LyricsService
    @ObservedObject var media: MediaController
    @ObservedObject var state: NotchState
    @State private var hoveredLineId: Int?

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: !media.isPlaying)) { context in
            lyricsBody(position: media.currentPosition(at: context.date))
        }
        .onDisappear { state.hoveringLyrics = false }
    }

    private func lyricsBody(position: Double) -> some View {
        let activeIdx = lyrics.activeIndex(for: position)
        return ZStack(alignment: .topTrailing) {
            if lyrics.isFetching {
                VStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading lyrics…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if lyrics.lines.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.35))
                    Text("No lyrics available")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 14) {
                            ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                                let dist = index - activeIdx
                                let isHovered = hoveredLineId == index

                                let opacity: Double = {
                                    if isHovered { return 1.0 }
                                    if dist == 0 { return 1.0 }
                                    if dist < 0 { return 0.16 }
                                    switch dist {
                                    case 1: return 0.58
                                    case 2: return 0.40
                                    case 3: return 0.26
                                    case 4: return 0.16
                                    default: return 0.10
                                    }
                                }()

                                let blurRadius: CGFloat = {
                                    if isHovered { return 0 }
                                    if dist == 0 { return 0 }
                                    if dist < 0 { return 3.5 }
                                    switch dist {
                                    case 1: return 1.5
                                    case 2: return 3.0
                                    case 3: return 4.5
                                    case 4: return 6.0
                                    default: return 8.0
                                    }
                                }()

                                let scale: CGFloat = {
                                    if dist == 0 { return 1.0 }
                                    if dist < 0 { return 0.96 }
                                    if dist == 1 { return 0.985 }
                                    return 0.97
                                }()

                                let fontSize: CGFloat = dist == 0 ? 18.5 : (dist == 1 ? 15 : 14)
                                let fontWeight: Font.Weight = dist == 0 ? .bold : (dist == 1 ? .semibold : .medium)

                                Button {
                                    if line.time > 0 {
                                        media.seek(to: line.time)
                                    }
                                } label: {
                                    Text(line.text)
                                        .font(.system(size: fontSize, weight: fontWeight))
                                        .tracking(-0.35)
                                        .foregroundStyle(Color.white.opacity(opacity))
                                        .scaleEffect(scale, anchor: .center)
                                        .blur(radius: blurRadius)
                                        .shadow(color: dist == 0 ? .black.opacity(0.55) : .clear, radius: 8, y: 2)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    hoveredLineId = hovering ? index : nil
                                }
                                .id(index)
                            }
                        }
                        .padding(.vertical, 50)
                        .padding(.horizontal, 10)
                        .animation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.65), value: activeIdx)
                    }
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 0.18),
                                .init(color: .black, location: 0.82),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .onChange(of: activeIdx) { _, newIdx in
                        guard !state.hoveringLyrics else { return }
                        withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.72)) {
                            proxy.scrollTo(newIdx, anchor: .center)
                        }
                    }
                    .onHover { hovering in
                        state.hoveringLyrics = hovering
                        if !hovering {
                            withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.72)) {
                                proxy.scrollTo(activeIdx, anchor: .center)
                            }
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(activeIdx, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MediaView: View {
    @ObservedObject var media: MediaController
    @ObservedObject var state: NotchState
    var albumArtNamespace: Namespace.ID? = nil
    var visualizerNamespace: Namespace.ID? = nil
    @State private var favorite = false
    @State private var hoveringLyricsButton = false

    var body: some View {
        if !media.hasTrack {
            EmptyMediaView()
        } else {
            HStack(spacing: 0) {
                playerSection
                    .frame(width: state.showQueue ? 412 : 428)

                if state.showQueue {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))

                    PlayingNextView(media: media)
                        .padding(.trailing, 24)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else if state.showLyrics {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))

                    LiveLyricsView(lyrics: media.lyrics, media: media, state: state)
                        .padding(.trailing, 24)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .animation(NotchAnimation.state, value: state.showQueue || state.showLyrics)
        }
    }

    private var playerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ArtworkView(
                    image: media.artwork,
                    size: 52,
                    cornerRadius: 13,
                    namespace: albumArtNamespace,
                    isSource: state.expanded,
                    showsBorder: true,
                    skipAnimationID: media.artworkSkipAnimationID,
                    skipDirection: media.artworkSkipDirection,
                    skipArtwork: media.artworkSkipArtwork
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(media.title)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if media.lyrics.hasLyrics || media.lyrics.isFetching {
                            lyricsButton
                        }
                    }

                    Text(media.artist.isEmpty ? media.sourceLabel : media.artist)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                EqualizerBars(
                    active: media.isPlaying,
                    useGradient: true,
                    tint: media.artworkTint,
                    namespace: visualizerNamespace,
                    isSource: state.expanded
                )
            }

            SeekBar(media: media)

            controls
        }
        .padding(.horizontal, 24)
    }

    private var lyricsButton: some View {
        Button {
            withAnimation(NotchAnimation.spring(response: 0.38, dampingFraction: 0.78)) {
                state.showLyrics.toggle()
            }
        } label: {
            Image(systemName: "quote.bubble")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(state.showLyrics || hoveringLyricsButton ? 1 : 0.78))
                .frame(width: 22, height: 22)
                .background {
                    if state.showLyrics || hoveringLyricsButton {
                        Circle()
                            .fill(Color.white.opacity(state.showLyrics ? 0.20 : 0.10))
                    }
                }
        }
        .buttonStyle(.plain)
        .layoutPriority(1)
        .onHover { hoveringLyricsButton = $0 }
        .accessibilityLabel(state.showLyrics ? "Hide lyrics" : "Show lyrics")
    }

    private var controls: some View {
        ZStack {
            HStack {
                HStack(spacing: 6) {
                    Button {
                        withAnimation(NotchAnimation.spring(response: 0.38, dampingFraction: 0.78)) {
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
                Button {
                    media.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 19, weight: .bold))
                        .symbolEffect(.bounce, options: .nonRepeating, value: state.previousSkipAnimationID)
                }
                .buttonStyle(MediaControlButtonStyle())

                Button { media.playPause() } label: {
                    Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect)
                        .font(.system(size: 26, weight: .bold))
                }
                .buttonStyle(MediaControlButtonStyle())

                Button {
                    media.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 19, weight: .bold))
                        .symbolEffect(.bounce, options: .nonRepeating, value: state.nextSkipAnimationID)
                }
                .buttonStyle(MediaControlButtonStyle())
            }
        }
    }
}

struct EmptyMediaView: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "music.note").font(.system(size: 20))
            Text("Nothing playing").font(.system(size: 12, weight: .medium))
            Text("Play something in Music, Spotify or a browser tab").font(.system(size: 10))
        }
        .foregroundStyle(.white.opacity(0.5))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
