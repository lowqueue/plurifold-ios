import SwiftUI
import WebKit

/// The native shell keeps authentication in Keychain/URLSession. One isolated
/// Plurifold page owns the existing WebRTC audio and feedback experience.
@MainActor
struct NativeSpeakingScreen: View {
    var initialLanguage: String?
    @EnvironmentObject private var session: NativeSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppAppearance.self) private var appearance
    @State private var api: PlurifoldAPI?
    @State private var isLoading = true
    @State private var message: String?
    @State private var retry = UUID()

    var body: some View {
        NavigationStack {
            Group {
                if let api {
                    NativeSpeakingRoom(api: api, language: initialLanguage, colorway: appearance.colorway.rawValue,
                                       lighting: colorScheme == .dark ? "dark" : "light") { error in
                        self.api = nil
                        message = error
                    }
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        Image(systemName: "waveform")
                            .font(.largeTitle).foregroundStyle(Palette.accent).accessibilityHidden(true)
                        Text("Speaking practice")
                            .font(StudyTypography.font(.largeTitle, weight: .bold))
                        if isLoading {
                            ProgressView("Checking speaking access…")
                        } else {
                            Text(message ?? "Speaking is currently a private trial.")
                                .foregroundStyle(Palette.secondary)
                            Button("Try again") { retry = UUID() }
                                .buttonStyle(StudyButtonStyle())
                        }
                    }
                    .frame(maxWidth: 520, alignment: .leading)
                    .gardenCard().padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .studyBackground()
            .navigationTitle("Speaking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { api = nil; dismiss() }
                }
            }
        }
        .tint(Palette.accent)
        .task(id: retry) { await load() }
        .onChange(of: scenePhase) { _, phase in
            // Permission sheets briefly make the scene inactive. Only an
            // actual background transition ends capture and the server call.
            if phase == .background {
                api = nil
                isLoading = false
                message = "The conversation ended when Plurifold went into the background. Start again when you’re ready."
            }
        }
    }

    private func load() async {
        api = nil
        isLoading = true
        message = nil
        let current = PlurifoldAPI(session: session)
        do {
            let capability: MobileSpeakingCapability = try await current.get("/api/mobile/speaking")
            try Task.checkCancellation()
            guard scenePhase == .active else { isLoading = false; return }
            if capability.allowed { api = current }
            else { message = "Speaking is currently a private trial and isn’t enabled for this account." }
        } catch is CancellationError { return }
        catch { message = error.localizedDescription }
        isLoading = false
    }
}

@MainActor
private struct NativeSpeakingRoom: UIViewRepresentable {
    let api: PlurifoldAPI
    let language: String?
    let colorway: String
    let lighting: String
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(api: api, onFailure: onFailure) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.addScriptMessageHandler(context.coordinator, contentWorld: .page,
                                                                    name: "plurifoldSpeaking")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        context.coordinator.webView = webView
        webView.load(URLRequest(url: MobileSpeakingPolicy.roomURL(language: language, colorway: colorway, lighting: lighting),
                                cachePolicy: .reloadIgnoringLocalCacheData))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandlerWithReply, WKNavigationDelegate, WKUIDelegate {
        let api: PlurifoldAPI
        let onFailure: (String) -> Void
        weak var webView: WKWebView?
        private var stopped = false
        private var starting = false
        private var activeHandles = Set<String>()
        private var endingHandles = Set<String>()

        init(api: PlurifoldAPI, onFailure: @escaping (String) -> Void) {
            self.api = api
            self.onFailure = onFailure
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage,
                                   replyHandler: @escaping (Any?, String?) -> Void) {
            guard !stopped, message.name == "plurifoldSpeaking", message.webView === webView,
                  message.frameInfo.isMainFrame,
                  trusted(message.frameInfo.securityOrigin),
                  MobileSpeakingPolicy.allows(webView?.url),
                  let request = MobileSpeakingPolicy.request(message.body) else {
                replyHandler(nil, "This speaking request isn’t supported.")
                return
            }
            if request.operation == .session && starting {
                replyHandler(["status": 409, "headers": ["content-type": "application/json"],
                              "body": "{\"error\":\"An audio connection is already being prepared.\"}"], nil)
                return
            }
            if request.operation == .session { starting = true }
            // Do not cancel an in-flight session creation on dismissal. Its
            // response supplies the handle needed to immediately hang it up.
            Task { [self] in
                defer { if request.operation == .session { starting = false } }
                do {
                    let response = try await api.speakingRequest(operation: request.operation, body: request.body)
                    if let handle = response.sessionHandle {
                        activeHandles.insert(handle)
                        if stopped { await end(handle, failedToConnect: true) }
                    }
                    if request.operation == .hangup, (200..<300).contains(response.status),
                       let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
                       let handle = body["session"] as? String {
                        activeHandles.remove(handle)
                    }
                    replyHandler(response.bridgeValue, nil)
                } catch {
                    replyHandler(nil, stopped ? "The speaking room has closed." : "The audio connection could not reach Plurifold. Please try again.")
                }
            }
        }

        private func trusted(_ origin: WKSecurityOrigin) -> Bool {
            origin.protocol == "https" && origin.host == MobileSpeakingPolicy.host && (origin.port == 0 || origin.port == 443)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if stopped {
                decisionHandler(navigationAction.request.url?.absoluteString == "about:blank" ? .allow : .cancel)
                return
            }
            decisionHandler(navigationAction.targetFrame?.isMainFrame == true && MobileSpeakingPolicy.allows(navigationAction.request.url)
                            ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            nil
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            guard !stopped else { decisionHandler(.allow); return }
            guard navigationResponse.isForMainFrame, MobileSpeakingPolicy.allows(navigationResponse.response.url),
                  let http = navigationResponse.response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode), http.mimeType == "text/html" else {
                decisionHandler(.cancel)
                stop()
                onFailure("The speaking room isn’t available right now. Please try again shortly.")
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            let allowed = !stopped && frame.isMainFrame && trusted(origin)
                && MobileSpeakingPolicy.allows(webView.url) && type == .microphone
            decisionHandler(allowed ? .prompt : .deny)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            fail(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            fail(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard !stopped else { return }
            stop()
            onFailure("The speaking room closed unexpectedly. Your microphone has stopped. Please try again.")
        }

        private func fail(_ error: Error) {
            guard !stopped, (error as? URLError)?.code != .cancelled else { return }
            stop()
            onFailure("The speaking room couldn’t load. Check your connection and try again.")
        }

        func stop() {
            guard !stopped else { return }
            stopped = true
            webView?.setMicrophoneCaptureState(.none, completionHandler: nil)
            webView?.stopLoading()
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "plurifoldSpeaking", contentWorld: .page)
            // Discard the document and all RTCPeerConnections rather than
            // leaving a hidden page with an active microphone.
            webView?.loadHTMLString("", baseURL: nil)
            for handle in activeHandles {
                Task { [self] in await end(handle, failedToConnect: false) }
            }
        }

        private func end(_ handle: String, failedToConnect: Bool) async {
            guard endingHandles.insert(handle).inserted,
                  let body = try? JSONSerialization.data(withJSONObject: ["session": handle, "failedToConnect": failedToConnect]) else { return }
            defer { endingHandles.remove(handle) }
            if let response = try? await api.speakingRequest(operation: .hangup, body: body), (200..<300).contains(response.status) {
                activeHandles.remove(handle)
            }
        }
    }
}
