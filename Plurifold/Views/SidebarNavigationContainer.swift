import SwiftUI

/// Adds chrome around the stable tab/navigation hosts, never replacing them.
struct SidebarNavigationContainer<Content: View>: View {
    @EnvironmentObject private var studyScope: MobileStudyScope
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var animation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.3, dampingFraction: 0.9)
    }

    var body: some View {
        content
            .allowsHitTesting(!studyScope.isSidebarPresented)
            .accessibilityHidden(studyScope.isSidebarPresented)
            .background {
                EdgeSwipeNavigation(isEnabled: scenePhase == .active && !studyScope.isSidebarPresented,
                                    intent: studyScope.edgeNavigationIntent) { intent in
                    withAnimation(animation) { studyScope.completeEdgeNavigation(intent) }
                }
            }
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    if studyScope.isSidebarPresented {
                        ZStack(alignment: .leading) {
                            Button(action: close) { Color.black.opacity(0.36) }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Close navigation menu")
                                .ignoresSafeArea()
                                .transition(.opacity)
                            AppSidebar(onSelect: navigate, onClose: close)
                                .frame(width: min(340, geometry.size.width * 0.86))
                                .frame(maxHeight: .infinity)
                                .background(Palette.surface.ignoresSafeArea())
                                .overlay(alignment: .trailing) { Rectangle().fill(Palette.line).frame(width: 1) }
                                .shadow(color: .black.opacity(0.18), radius: 16, x: 5)
                                .simultaneousGesture(DragGesture(minimumDistance: 20)
                                    .onEnded { value in
                                        if MobileEdgeSwipe.shouldComplete(horizontal: Double(-value.translation.width),
                                            vertical: Double(value.translation.height), velocity: 0,
                                            width: Double(min(340, geometry.size.width * 0.86))) {
                                            close()
                                        }
                                    })
                                .accessibilityElement(children: .contain)
                                .accessibilityLabel("Navigation menu")
                                .accessibilityAddTraits(.isModal)
                                .transition(reduceMotion ? .opacity : .move(edge: .leading))
                        }
                        .accessibilityAction(.escape, close)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
            }
            .animation(animation, value: studyScope.isSidebarPresented)
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { studyScope.isSidebarPresented = false }
            }
    }

    private func close() {
        withAnimation(animation) { studyScope.isSidebarPresented = false }
    }

    private func navigate(_ destination: AppSidebarDestination) {
        withAnimation(animation) {
            studyScope.isSidebarPresented = false
            switch destination {
            case .home: studyScope.showLanguagePicker()
            case .library:
                if let language = studyScope.language { studyScope.selectLanguage(language) }
                else { studyScope.showLanguagePicker() }
            case .words: studyScope.tab = .words
            case .review: studyScope.tab = .review
            case .account: studyScope.tab = .account
            }
        }
    }
}
