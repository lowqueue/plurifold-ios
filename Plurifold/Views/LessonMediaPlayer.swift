import SwiftUI
import AVKit
import Combine
import WebKit

/// Plays only the public HTTPS media URL supplied by the lesson API.
/// Authentication credentials are never attached to media or YouTube requests.
struct LessonMediaPlayer: View {
    let media: MobileMedia
    var showsTitle = true
    var pauseRequest: UUID? = nil
    var onPlaybackStarted: @MainActor () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsTitle { Text(media.title).font(.headline) }
            if media.kind == "youtube", let videoID = LessonMediaURL.youtubeID(media.url) {
                YouTubeLessonPlayer(videoID: videoID, start: media.start, end: media.end,
                                    pauseRequest: pauseRequest, onPlaybackStarted: onPlaybackStarted)
            } else if ["audio", "video"].contains(media.kind),
                      let url = LessonMediaURL.https(media.url) {
                NativeLessonPlayer(url: url, isVideo: media.kind == "video",
                                   start: media.start, end: media.end, pauseRequest: pauseRequest)
                    .id("\(media.id)|\(media.url)|\(media.start ?? -1)|\(media.end ?? -1)")
            } else {
                Label("This lesson's media link is unavailable.", systemImage: "exclamationmark.circle")
                    .font(.subheadline).foregroundStyle(Palette.secondary)
            }
        }
        .foregroundStyle(Palette.ink)
    }
}

private enum LessonMediaURL {
    static func https(_ value: String) -> URL? {
        guard let parts = URLComponents(string: value), parts.scheme?.lowercased() == "https",
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
              let url = parts.url else { return nil }
        return url
    }

    static func youtubeID(_ value: String) -> String? {
        guard let url = https(value), let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = parts.host?.lowercased(), parts.port == nil || parts.port == 443 else { return nil }
        let path = parts.path.split(separator: "/").map(String.init)
        let candidate: String?
        if host == "youtu.be", path.count == 1 {
            candidate = path.first
        } else if ["youtube.com", "www.youtube.com", "m.youtube.com", "youtube-nocookie.com", "www.youtube-nocookie.com"].contains(host) {
            if parts.path == "/watch" {
                candidate = parts.queryItems?.first(where: { $0.name == "v" })?.value
            } else if path.count == 2, ["embed", "shorts", "live"].contains(path[0]) {
                candidate = path[1]
            } else { candidate = nil }
        } else { candidate = nil }
        guard let candidate, candidate.count == 11,
              candidate.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }) else { return nil }
        return candidate
    }

    static func start(_ value: Double?) -> Double {
        guard let value, value.isFinite, value >= 0, value <= 86_400_000 else { return 0 }
        return value
    }

    static func end(_ value: Double?, after start: Double) -> Double? {
        guard let value, value.isFinite, value > start, value <= 86_400_000 else { return nil }
        return value
    }
}

@MainActor
private final class LessonPlayback: ObservableObject {
    let player = AVPlayer()
    @Published var isLoading = true
    @Published var failure: String?
    @Published var isPlaying = false
    @Published var position: Double = 0
    @Published var lowerBound: Double = 0
    @Published var upperBound: Double = 0
    @Published var hasEnded = false

    private var statusObservation: NSKeyValueObservation?
    private var playbackObservation: NSKeyValueObservation?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var requestedStart: Double = 0
    private var requestedEnd: Double?
    private var generation = UUID()
    private let audioOwnerID = UUID()

    func load(url: URL, start: Double?, end: Double?) {
        unload()
        isLoading = true
        failure = nil
        hasEnded = false
        requestedStart = LessonMediaURL.start(start)
        requestedEnd = LessonMediaURL.end(end, after: requestedStart)
        position = requestedStart
        lowerBound = requestedStart
        upperBound = requestedEnd ?? requestedStart
        let loadID = generation
        let item = AVPlayerItem(url: url)
        if let requestedEnd { item.forwardPlaybackEndTime = CMTime(seconds: requestedEnd, preferredTimescale: 600) }
        player.replaceCurrentItem(with: item)
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] _, _ in
            Task { @MainActor [weak self, weak item] in
                guard let self, let item, self.generation == loadID else { return }
                switch item.status {
                case .readyToPlay:
                    self.updateBounds(item)
                    self.player.seek(to: CMTime(seconds: self.lowerBound, preferredTimescale: 600),
                                     toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                        Task { @MainActor [weak self] in
                            guard let self, self.generation == loadID else { return }
                            self.isLoading = false
                        }
                    }
                case .failed:
                    self.pause()
                    self.isLoading = false
                    self.failure = "This recording could not be loaded. Check your connection and try again."
                default: break
                }
            }
        }
        playbackObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == loadID else { return }
                self.isPlaying = self.player.timeControlStatus != .paused
                if self.isPlaying {
                    _ = self.prepareAudioSession()
                } else {
                    AudioSessionCoordinator.shared.release(owner: self.audioOwnerID)
                }
            }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, self.generation == loadID else { return }
                if time.seconds.isFinite { self.position = max(self.lowerBound, time.seconds) }
                if let current = self.player.currentItem { self.updateBounds(current) }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                              object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == loadID else { return }
                self.pause()
                self.hasEnded = true
            }
        }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime,
                                                                  object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == loadID else { return }
                self.pause()
                self.isLoading = false
                self.failure = "Playback was interrupted. Check your connection and try again."
            }
        }
    }

    private func updateBounds(_ item: AVPlayerItem) {
        let duration = item.duration.seconds
        guard duration.isFinite, duration > 0 else { return }
        lowerBound = requestedStart < duration ? requestedStart : 0
        upperBound = min(requestedEnd ?? duration, duration)
        if upperBound <= lowerBound { upperBound = duration }
        // Some lessons reference a complete resource track without clip bounds.
        // An absent end time must preserve the full recording.
    }

    func togglePlayback() {
        guard !isLoading, failure == nil else { return }
        if isPlaying { pause(); return }
        if hasEnded || (upperBound > lowerBound && position >= upperBound - 0.1) {
            seek(to: lowerBound)
        }
        guard prepareAudioSession() else { return }
        player.play()
    }

    private func prepareAudioSession() -> Bool {
        // Spoken lessons should remain audible when the phone's silent switch is on.
        // Activate only for user-initiated playback, not while loading a lesson.
        do {
            try AudioSessionCoordinator.shared.acquire(owner: audioOwnerID, mode: .default) { [weak self] in
                self?.pause()
            }
            return true
        } catch {
            pause()
            failure = "Audio could not start. Please try again."
            return false
        }
    }

    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        let target = max(lowerBound, min(seconds, max(lowerBound, upperBound)))
        hasEnded = false
        position = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    func pause() {
        player.pause()
        isPlaying = false
        AudioSessionCoordinator.shared.release(owner: audioOwnerID)
    }

    func unload() {
        generation = UUID()
        pause()
        statusObservation?.invalidate()
        statusObservation = nil
        playbackObservation?.invalidate()
        playbackObservation = nil
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        failureObserver = nil
        player.replaceCurrentItem(with: nil)
        isPlaying = false
    }

    deinit {
        statusObservation?.invalidate()
        playbackObservation?.invalidate()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        player.pause()
        let owner = audioOwnerID
        Task { @MainActor in AudioSessionCoordinator.shared.release(owner: owner) }
    }
}

private struct NativeLessonPlayer: View {
    let url: URL
    let isVideo: Bool
    let start: Double?
    let end: Double?
    let pauseRequest: UUID?
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var playback = LessonPlayback()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let failure = playback.failure {
                Text(failure).font(.subheadline).foregroundStyle(Palette.secondary)
                Button("Try again", systemImage: "arrow.clockwise") { load() }
            } else {
                if isVideo {
                    VideoPlayer(player: playback.player)
                        .frame(height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(playback.isLoading)
                }
                if playback.isLoading {
                    ProgressView("Loading recording…").font(.subheadline)
                } else if !isVideo {
                    Button(action: playback.togglePlayback) {
                        Label(playback.isPlaying ? "Pause recording" : "Play recording",
                              systemImage: playback.isPlaying ? "pause.fill" : "play.fill")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    if playback.upperBound > playback.lowerBound {
                        Slider(value: Binding(get: {
                            min(max(playback.position, playback.lowerBound), playback.upperBound)
                        }, set: playback.seek), in: playback.lowerBound...playback.upperBound)
                        .accessibilityLabel("Recording position")
                        HStack {
                            Text(time(playback.position - playback.lowerBound))
                            Spacer()
                            Text(time(playback.upperBound - playback.lowerBound))
                        }
                        .font(.caption.monospacedDigit()).foregroundStyle(Palette.secondary)
                    }
                } else if playback.hasEnded {
                    Button("Play again", systemImage: "arrow.counterclockwise", action: playback.togglePlayback)
                }
            }
        }
        .onAppear(perform: load)
        .onDisappear { playback.unload() }
        .onChange(of: pauseRequest) { _, _ in playback.pause() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { playback.pause() }
        }
    }

    private func load() { playback.load(url: url, start: start, end: end) }

    private func time(_ value: Double) -> String {
        guard value.isFinite else { return "0:00" }
        let seconds = Int(max(0, min(value, 86_400_000)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct YouTubeLessonPlayer: View {
    let videoID: String
    let start: Double?
    let end: Double?
    let pauseRequest: UUID?
    let onPlaybackStarted: @MainActor () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var failed = false
    @State private var retryID = UUID()

    private var watchURL: URL {
        var url = URLComponents(string: "https://www.youtube.com/watch")!
        url.queryItems = [URLQueryItem(name: "v", value: videoID)]
        let seconds = Int(LessonMediaURL.start(start))
        if seconds > 0 { url.queryItems?.append(URLQueryItem(name: "t", value: "\(seconds)s")) }
        return url.url!
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            YouTubeLessonWebView(videoID: videoID, start: start, end: end,
                                 isActive: scenePhase == .active, pauseRequest: pauseRequest,
                                 onPlaybackStarted: onPlaybackStarted, failed: $failed)
                .frame(height: 210)
                .id("\(videoID)|\(start ?? -1)|\(end ?? -1)|\(retryID)")
            if failed {
                Text("The embedded player could not load.").font(.subheadline)
                Button("Try again", systemImage: "arrow.clockwise") {
                    failed = false
                    retryID = UUID()
                }
            }
            Text("If playback is unavailable here, open the video on YouTube.")
                .font(.caption).foregroundStyle(Palette.secondary)
            Link(destination: watchURL) {
                Label("Open on YouTube", systemImage: "arrow.up.right.square")
            }
            .font(.subheadline)
        }
    }
}

private struct YouTubeLessonWebView: UIViewRepresentable {
    let videoID: String
    let start: Double?
    let end: Double?
    let isActive: Bool
    let pauseRequest: UUID?
    let onPlaybackStarted: @MainActor () -> Void
    @Binding var failed: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(videoID: videoID, onPlaybackStarted: onPlaybackStarted, failed: $failed)
    }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.lastPauseRequest = pauseRequest
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: Coordinator.messageName)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = webView
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        // YouTube requires the installed app's bundle ID as a native WebView referer.
        let appID = (Bundle.main.bundleIdentifier ?? "com.plurifold.ios.prototype").lowercased()
        let origin = URL(string: "https://\(appID)")!
        context.coordinator.originHost = origin.host
        var embed = URLComponents(string: "https://www.youtube.com/embed/\(videoID)")!
        let beginning = LessonMediaURL.start(start)
        embed.queryItems = [
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "autoplay", value: "0"),
            URLQueryItem(name: "enablejsapi", value: "1"),
            URLQueryItem(name: "origin", value: origin.absoluteString)
        ]
        if beginning > 0 { embed.queryItems?.append(URLQueryItem(name: "start", value: String(Int(beginning)))) }
        if let ending = LessonMediaURL.end(end, after: beginning), Int(ending) > Int(beginning) {
            embed.queryItems?.append(URLQueryItem(name: "end", value: String(Int(ending))))
        }
        let source = embed.url!.absoluteString.replacingOccurrences(of: "&", with: "&amp;")
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <style>html,body{margin:0;width:100%;height:100%;background:transparent}iframe{border:0;width:100%;height:100%}</style>
        </head><body><iframe id="plurifold-youtube-player" title="YouTube lesson video" src="\(source)"
        referrerpolicy="strict-origin-when-cross-origin" allow="encrypted-media; fullscreen; picture-in-picture" allowfullscreen></iframe>
        <script>
        // The official iframe API reports actual playback, including native player controls.
        // Loading and cuing the video never starts it automatically.
        function reportPlurifoldPlayback() {
          window.webkit.messageHandlers.\(Coordinator.messageName).postMessage({
            event: 'playing', videoID: '\(videoID)', nonce: '\(context.coordinator.bridgeNonce)'
          });
        }
        window.onYouTubeIframeAPIReady = function () {
          window.plurifoldYouTubePlayer = new YT.Player('plurifold-youtube-player', {
            events: {
              onReady: function (event) {
                if (event.target.getPlayerState() === YT.PlayerState.PLAYING) {
                  reportPlurifoldPlayback();
                }
              },
              onStateChange: function (event) {
                if (event.data === YT.PlayerState.PLAYING) {
                  reportPlurifoldPlayback();
                }
              }
            }
          });
        };
        </script><script async src="https://www.youtube.com/iframe_api"></script>
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: origin)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.failed = $failed
        context.coordinator.onPlaybackStarted = onPlaybackStarted
        if !isActive || context.coordinator.lastPauseRequest != pauseRequest {
            webView.pauseAllMediaPlayback(completionHandler: nil)
        }
        context.coordinator.lastPauseRequest = pauseRequest
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.isDismantled = true
        coordinator.onPlaybackStarted = {}
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.messageName)
        webView.pauseAllMediaPlayback(completionHandler: nil)
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        static let messageName = "plurifoldYouTube"
        let bridgeNonce = UUID().uuidString
        let videoID: String
        weak var webView: WKWebView?
        var originHost: String?
        var isDismantled = false
        var onPlaybackStarted: @MainActor () -> Void
        var failed: Binding<Bool>
        var lastPauseRequest: UUID?
        init(videoID: String, onPlaybackStarted: @escaping @MainActor () -> Void, failed: Binding<Bool>) {
            self.videoID = videoID
            self.onPlaybackStarted = onPlaybackStarted
            self.failed = failed
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            // Accept only this embed's small main-frame callback, never messages sent
            // directly by the cross-origin iframe, a navigated page, or a discarded player.
            let origin = message.frameInfo.securityOrigin
            guard !isDismantled, message.name == Self.messageName,
                  let webView, message.webView === webView,
                  userContentController === webView.configuration.userContentController,
                  message.frameInfo.isMainFrame,
                  origin.protocol == "https", origin.host == originHost,
                  origin.port == 0 || origin.port == 443,
                  let body = message.body as? [String: Any], body.count == 3,
                  body["event"] as? String == "playing",
                  body["videoID"] as? String == videoID,
                  body["nonce"] as? String == bridgeNonce else { return }
            onPlaybackStarted()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { failed.wrappedValue = true }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { failed.wrappedValue = true }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { failed.wrappedValue = true }
    }
}
