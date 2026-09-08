import SwiftUI

@main
@MainActor
struct PlurifoldApp: App {
    @StateObject private var session = NativeSession()
    @State private var appearance = AppAppearance.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                if session.isRestoring {
                    VStack(spacing: 24) {
                        Wordmark()
                        ProgressView("Opening your account…")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .studyBackground()
                } else if let user = session.user {
                    SignedInRoot(session: session)
                        .id(user.id)
                } else {
                    SignInView()
                }
            }
            .environmentObject(session)
            .environment(appearance)
            .preferredColorScheme(appearance.preferredColorScheme)
            .tint(Palette.accent)
            .task { await session.restore() }
        }
    }
}

@MainActor
private struct SignedInRoot: View {
    @EnvironmentObject private var session: NativeSession
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store: LiveLibraryStore
    @StateObject private var studyScope = MobileStudyScope()
    @State private var needsForegroundRefresh = false
    @State private var foregroundRefreshTask: Task<Void, Never>?

    init(session: NativeSession) {
        _store = StateObject(wrappedValue: LiveLibraryStore(session: session))
    }

    var body: some View {
        SidebarNavigationContainer {
            VStack(spacing: 0) {
                AppMasthead()
                AppLanguageBar()
                TabView(selection: $studyScope.tab) {
                    LiveHomeView()
                        .tabItem { Label("Home", systemImage: "house") }
                        .tag(MobileStudyTab.home)
                    LiveWordsView()
                        .tabItem { Label("Words", systemImage: "bookmark") }
                        .tag(MobileStudyTab.words)
                    LiveReviewView()
                        .tabItem { Label("Review", systemImage: "rectangle.on.rectangle") }
                        .tag(MobileStudyTab.review)
                    AccountView()
                        .tabItem { Label("Account", systemImage: "person.crop.circle") }
                        .tag(MobileStudyTab.account)
                }
                .toolbarBackground(Palette.surface, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            }
            .background(Palette.header.ignoresSafeArea(edges: .top))
        }
        .tint(Palette.accent)
        .environmentObject(store)
        .environmentObject(studyScope)
        .onChange(of: store.isLoading) { _, loading in
            // Reconcile the completed catalog + vocabulary snapshot together.
            if !loading, store.notice == nil {
                studyScope.reconcile(languages: MobileStudyLanguageList(courses: store.courses, words: store.words).languages)
            }
            if !loading { refreshAfterReturning() }
        }
        .onChange(of: store.isSaving) { _, saving in
            if !saving { refreshAfterReturning() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                needsForegroundRefresh = true
                refreshAfterReturning()
            } else {
                foregroundRefreshTask?.cancel()
            }
        }
        .onDisappear {
            needsForegroundRefresh = false
            foregroundRefreshTask?.cancel()
            foregroundRefreshTask = nil
        }
    }

    private func refreshAfterReturning() {
        // A desktop edit should appear on return to the app. Wait for native
        // writes to finish; the store also rejects stale refresh snapshots.
        guard needsForegroundRefresh, scenePhase == .active,
              !store.isSaving, !store.isLoading, foregroundRefreshTask == nil else { return }
        needsForegroundRefresh = false
        foregroundRefreshTask = Task {
            defer {
                foregroundRefreshTask = nil
                if needsForegroundRefresh { refreshAfterReturning() }
            }
            await store.refresh()
        }
    }

}
