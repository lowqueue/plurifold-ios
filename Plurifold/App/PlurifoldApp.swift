import SwiftUI

@main
@MainActor
struct PlurifoldApp: App {
    private let catalogResult = Result { try StudyCatalog.load() }

    var body: some Scene {
        WindowGroup {
            switch catalogResult {
            case .success(let catalog):
                AppRoot(catalog: catalog)
            case .failure(let error):
                ContentUnavailableView {
                    Label("Lessons could not open", systemImage: "book.closed")
                } description: {
                    Text(error.localizedDescription)
                }
            }
        }
    }
}

@MainActor
private struct AppRoot: View {
    @StateObject private var store: StudyStore

    init(catalog: StudyCatalog) {
        _store = StateObject(wrappedValue: StudyStore(catalog: catalog))
    }

    var body: some View {
        TabView {
            NavigationStack { LibraryView() }
                .tabItem { Label("Learn", systemImage: "books.vertical") }
            NavigationStack { WordsView() }
                .tabItem { Label("Words", systemImage: "bookmark") }
            NavigationStack { ProgressScreen() }
                .tabItem { Label("Progress", systemImage: "chart.bar") }
        }
        .tint(Palette.ink)
        .environmentObject(store)
        .alert("Local study data", isPresented: Binding(
            get: { store.storageNotice != nil },
            set: { if !$0 { store.storageNotice = nil } }
        )) {
            Button("OK", role: .cancel) { store.storageNotice = nil }
        } message: {
            Text(store.storageNotice ?? "")
        }
    }
}

#Preview {
    if let catalog = try? StudyCatalog.load() {
        AppRoot(catalog: catalog)
    }
}
