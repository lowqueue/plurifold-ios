import SwiftUI

@main
@MainActor
struct PlurifoldApp: App {
    @StateObject private var session = NativeSession()

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
            .task { await session.restore() }
        }
    }
}

@MainActor
private struct SignedInRoot: View {
    @EnvironmentObject private var session: NativeSession
    @StateObject private var store: LiveLibraryStore

    init(session: NativeSession) {
        _store = StateObject(wrappedValue: LiveLibraryStore(session: session))
    }

    var body: some View {
        TabView {
            LiveHomeView()
                .tabItem { Label("Home", systemImage: "house") }
            LiveWordsView()
                .tabItem { Label("Words", systemImage: "bookmark") }
            account
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .tint(Palette.accent)
        .environmentObject(store)
    }

    private var account: some View {
        NavigationStack {
            List {
                Section("Signed in") {
                    if let email = session.user?.email {
                        Text(email).textSelection(.enabled)
                    }
                    Text("Your saved vocabulary and reading places are shared with your Plurifold account.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondary)
                }
                .listRowBackground(Palette.surface)

                Section {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        HStack {
                            Label("Refresh library and study data", systemImage: "arrow.clockwise")
                            Spacer()
                            if store.isLoading { ProgressView() }
                        }
                    }
                    .disabled(store.isLoading || store.isSaving)
                    Link(destination: NativeSession.baseURL) {
                        Label("Open Plurifold website", systemImage: "arrow.up.right.square")
                    }
                }
                .listRowBackground(Palette.surface)

                if let notice = store.notice {
                    Section {
                        Label(notice, systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondary)
                    }
                    .listRowBackground(Palette.surface)
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        Task { await session.signOut() }
                    }
                    .disabled(session.isBusy || store.isSaving)
                } footer: {
                    if store.isSaving {
                        Text("Finishing your study changes before signing out…")
                    }
                }
                .listRowBackground(Palette.surface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .studyBackground()
            .navigationTitle("Account")
        }
    }
}
