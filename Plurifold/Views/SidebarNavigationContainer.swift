import SwiftUI
import UIKit

/// Non-observable presentation sample. Reading it at touch-down lets a new drag
/// catch a settling drawer at its displayed position instead of its target.
private final class SidebarPresentation {
    var position: Double = 0
}

private struct SidebarTranslation: GeometryEffect {
    var position: Double
    let travel: CGFloat
    let inset: CGFloat
    let presentation: SidebarPresentation

    var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        presentation.position = position
        return ProjectionTransform(CGAffineTransform(translationX: inset + CGFloat(position - 1) * travel, y: 0))
    }
}

/// Drag samples move only the overlay. The tab/navigation hosts keep their
/// identity, layout, reading position, and selection throughout the interaction.
struct SidebarNavigationContainer<Content: View>: View {
    private struct DragSession {
        let id: UUID
        let intent: MobileEdgeNavigationIntent
        let isDrawer: Bool
        let start: Double
        let translationOffset: Double
        let wasOpen: Bool
    }

    @EnvironmentObject private var studyScope: MobileStudyScope
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: Double = 0
    @State private var presentation = SidebarPresentation()
    @State private var drag: DragSession?
    @State private var isSurfaceVisible = false
    @State private var isSettledOpen = false
    @State private var handledOpen = false
    @State private var settleToken = UUID()
    @State private var feedback = UISelectionFeedbackGenerator()
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var settlingAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.36, dampingFraction: 0.86)
    }

    var body: some View {
        content
            .allowsHitTesting(!isSurfaceVisible)
            .accessibilityHidden(isSurfaceVisible)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    let width = min(340, geometry.size.width * 0.86)
                    let inset: CGFloat = 10
                    let travel = width + inset + geometry.safeAreaInsets.leading
                    let coverage = min(max(position, 0), 1)
                    let shape = RoundedRectangle(cornerRadius: 24 + 4 * CGFloat(coverage), style: .continuous)

                    ZStack(alignment: .leading) {
                        Button(action: close) { Color.black.opacity(0.36) }
                            .buttonStyle(.plain)
                            .opacity(coverage)
                            .accessibilityLabel("Close navigation menu")
                            .ignoresSafeArea()

                        // Keep the panel mounted offscreen, allowing reversal and
                        // cancellation without remounting its scrolling content.
                        AppSidebar(isActive: isSettledOpen, onSelect: navigate, onClose: close)
                            .frame(width: width, height: max(0, geometry.size.height - inset * 2))
                            .background(Palette.surface)
                            .clipShape(shape)
                            .overlay { shape.strokeBorder(Palette.line.opacity(0.9), lineWidth: 1) }
                            .shadow(color: .black.opacity(0.22 * coverage), radius: 10 + 14 * CGFloat(coverage), x: 4, y: 4)
                            .modifier(SidebarTranslation(position: position, travel: travel,
                                                         inset: inset, presentation: presentation))
                            .allowsHitTesting(isSettledOpen && drag == nil)
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("Navigation menu")
                            .accessibilityAddTraits(.isModal)
                            .accessibilityHidden(!isSettledOpen)
                    }
                    .allowsHitTesting(isSurfaceVisible)
                    .accessibilityHidden(!isSurfaceVisible)
                    .accessibilityAction(.escape, close)
                    .background {
                        EdgeSwipeNavigation(isEnabled: scenePhase == .active,
                                            isDrawerVisible: isSurfaceVisible,
                                            intent: studyScope.edgeNavigationIntent) { event in
                            handle(event, travel: Double(travel))
                        }
                    }
                    .onChange(of: geometry.size) { _, _ in resetForLayout() }
                    .onChange(of: geometry.safeAreaInsets) { _, _ in resetForLayout() }
                }
                .environment(\.layoutDirection, .leftToRight)
            }
            .onChange(of: studyScope.isSidebarPresented) { _, open in
                if open != handledOpen {
                    drag = nil
                    settle(open: open)
                }
            }
            .onChange(of: studyScope.edgeNavigationIntent) { _, _ in
                if drag != nil {
                    drag = nil
                    settle(open: studyScope.isSidebarPresented)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    studyScope.isSidebarPresented = false
                    resetForLayout()
                }
            }
            .onAppear { resetForLayout() }
    }

    private func track(_ value: Double) {
        // Spring animations here would chase the finger and introduce latency.
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { position = value }
    }

    private func handle(_ event: NavigationSwipe, travel: Double) {
        switch event.phase {
        case .began:
            guard event.intent == studyScope.edgeNavigationIntent, scenePhase == .active else { return }
            let isDrawer = event.source == .drawer || event.intent.action == .sidebar
            let start = isDrawer ? presentation.position : 0
            // When catching a moving spring, UIKit has already consumed a few
            // points deciding this is a pan. Do not add that earlier movement
            // to the displayed position we have only just captured.
            let offset = isDrawer && isSurfaceVisible && !isSettledOpen ? Double(event.translation.width) : 0
            settleToken = UUID()
            drag = DragSession(id: event.id, intent: event.intent, isDrawer: isDrawer,
                               start: start, translationOffset: offset, wasOpen: studyScope.isSidebarPresented)
            if isDrawer {
                feedback.prepare()
                isSurfaceVisible = true
                isSettledOpen = false
                track(SidebarMotion.position(start: start, translation: Double(event.translation.width) - offset,
                                              width: travel, reduceMotion: reduceMotion))
            }
        case .changed:
            guard let current = drag, current.id == event.id,
                  current.intent == studyScope.edgeNavigationIntent, current.isDrawer else { return }
            track(SidebarMotion.position(start: current.start, translation: Double(event.translation.width) - current.translationOffset,
                                         width: travel, reduceMotion: reduceMotion))
        case .ended:
            guard let current = drag, current.id == event.id,
                  current.intent == studyScope.edgeNavigationIntent else { return }
            drag = nil
            if current.isDrawer {
                let translation = Double(event.translation.width) - current.translationOffset
                track(SidebarMotion.position(start: current.start, translation: translation,
                                             width: travel, reduceMotion: reduceMotion))
                let open = SidebarMotion.shouldOpen(start: current.start, translation: translation,
                                                     velocity: Double(event.velocity.x), width: travel)
                if open != current.wasOpen { feedback.selectionChanged() }
                settle(open: open)
            } else if MobileEdgeSwipe.shouldComplete(horizontal: Double(event.translation.width),
                                                     vertical: Double(event.translation.height),
                                                     velocity: Double(event.velocity.x), width: Double(event.width)) {
                withAnimation(settlingAnimation) { studyScope.completeEdgeNavigation(current.intent) }
            }
        case .cancelled:
            guard let current = drag, current.id == event.id else { return }
            drag = nil
            if current.isDrawer { settle(open: current.wasOpen) }
        }
    }

    private func settle(open: Bool) {
        let token = UUID()
        settleToken = token
        handledOpen = open
        isSettledOpen = false
        isSurfaceVisible = true
        studyScope.isSidebarPresented = open
        withAnimation(settlingAnimation, completionCriteria: .removed) {
            position = open ? 1 : 0
        } completion: {
            guard settleToken == token, drag == nil else { return }
            isSettledOpen = open
            isSurfaceVisible = open
        }
    }

    private func resetForLayout() {
        settleToken = UUID()
        drag = nil
        let open = studyScope.isSidebarPresented
        handledOpen = open
        isSurfaceVisible = open
        isSettledOpen = open
        presentation.position = open ? 1 : 0
        track(open ? 1 : 0)
    }

    private func close() {
        drag = nil
        settle(open: false)
    }

    private func navigate(_ destination: AppSidebarDestination) {
        close()
        switch destination {
        case .home: studyScope.showHome()
        case .languagePicker: studyScope.showLanguagePicker()
        case .library: studyScope.openLibrary(.lessons)
        case .courses: studyScope.openLibrary(.courses)
        case .words: studyScope.tab = .words
        case .review: studyScope.tab = .review
        case .progress: studyScope.tab = .progress
        case .trophies: studyScope.showingTrophies = true
        case .speaking: studyScope.showingSpeaking = true
        case .account: studyScope.tab = .account
        }
    }
}
