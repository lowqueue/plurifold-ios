import SwiftUI
import UIKit

struct NavigationSwipe {
    enum Source { case edge, drawer }
    enum Phase { case began, changed, ended, cancelled }
    let id: UUID
    let source: Source
    let phase: Phase
    let intent: MobileEdgeNavigationIntent
    let translation: CGSize
    let velocity: CGPoint
    let width: CGFloat
}

/// Observes the existing touch hierarchy without placing an invisible control
/// over the reader. Edge navigation and drawer dragging share one gesture owner.
struct EdgeSwipeNavigation: UIViewControllerRepresentable {
    let isEnabled: Bool
    let isDrawerVisible: Bool
    let intent: MobileEdgeNavigationIntent
    let onSwipe: (NavigationSwipe) -> Void

    func makeUIViewController(context: Context) -> ObserverController {
        ObserverController(configuration: self)
    }

    func updateUIViewController(_ controller: ObserverController, context: Context) {
        controller.update(configuration: self)
    }

    static func dismantleUIViewController(_ controller: ObserverController, coordinator: ()) {
        controller.detach()
    }

    @MainActor
    final class ObserverController: UIViewController, UIGestureRecognizerDelegate {
        private struct Pending {
            let id = UUID()
            let source: NavigationSwipe.Source
            let intent: MobileEdgeNavigationIntent
        }

        private var configuration: EdgeSwipeNavigation
        private weak var owner: UIViewController?
        private var pending: Pending?
        private var attached = false
        // Restrict the start in shouldReceive, rather than requiring the
        // finger to land on UIKit's exact physical screen edge.
        private lazy var edge = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        private lazy var drawer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))

        init(configuration: EdgeSwipeNavigation) {
            self.configuration = configuration
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func loadView() {
            view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
            view.isAccessibilityElement = false
            for recognizer in [edge, drawer] {
                recognizer.maximumNumberOfTouches = 1
                recognizer.delaysTouchesBegan = false
                recognizer.delegate = self
            }
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            if parent == nil { detach() } else { attachIfNeeded() }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            attachIfNeeded()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            attachIfNeeded()
        }

        func update(configuration: EdgeSwipeNavigation) {
            if self.configuration.intent != configuration.intent || !configuration.isEnabled {
                cancelPending(deferred: true)
            }
            self.configuration = configuration
            attachIfNeeded()
            updateAvailability()
        }

        private func attachIfNeeded() {
            guard isViewLoaded, let parent else { return }
            var root = parent
            while let ancestor = root.parent { root = ancestor }
            guard root.isViewLoaded else { return }
            if owner !== root || !attached {
                detach()
                owner = root
                root.view.addGestureRecognizer(edge)
                root.view.addGestureRecognizer(drawer)
                attached = true
            }
            updateAvailability()
        }

        private func updateAvailability() {
            // A partial reveal must not disable the very edge gesture driving it.
            // Likewise, retain a closing pan until UIKit ends its touch sequence.
            let edgeActive = edge.state == .began || edge.state == .changed
            let drawerActive = drawer.state == .began || drawer.state == .changed
            edge.isEnabled = configuration.isEnabled && (edgeActive || (!drawerActive && !configuration.isDrawerVisible))
            drawer.isEnabled = configuration.isEnabled && (drawerActive || (!edgeActive && configuration.isDrawerVisible))
        }

        func detach() {
            cancelPending(deferred: true)
            edge.view?.removeGestureRecognizer(edge)
            drawer.view?.removeGestureRecognizer(drawer)
            owner = nil
            attached = false
        }

        private var canNavigate: Bool {
            guard configuration.isEnabled, !UIAccessibility.isVoiceOverRunning,
                  let owner, viewIfLoaded?.window != nil else { return false }
            return !hasPresentationOrTransition(owner)
        }

        private func hasPresentationOrTransition(_ controller: UIViewController) -> Bool {
            if controller.presentedViewController != nil || controller.transitionCoordinator != nil { return true }
            return controller.children.contains { child in
                child.viewIfLoaded?.window != nil && hasPresentationOrTransition(child)
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard canNavigate, let surface = gestureRecognizer.view else { return false }
            let point = touch.location(in: surface)
            guard surface.bounds.contains(point), !touchUsesHorizontalControl(touch.view) else { return false }
            if gestureRecognizer === drawer { return configuration.isDrawerVisible }
            return !configuration.isDrawerVisible && MobileEdgeSwipe.beginsAtEdge(
                x: Double(point.x), safeAreaLeading: Double(surface.safeAreaInsets.left),
                width: Double(surface.bounds.width))
        }

        private func touchUsesHorizontalControl(_ touchedView: UIView?) -> Bool {
            var candidate = touchedView
            while let current = candidate, current !== owner?.view {
                // Scrubbing media and editing text must keep their horizontal
                // gestures. Reader phrase selection keeps its existing hold
                // recognizer and wins once its hold has begun.
                if current is UISlider || current is UISwitch || current is UITextField { return true }
                if let text = current as? UITextView, text.isEditable { return true }
                candidate = current.superview
            }
            return false
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard canNavigate, let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let translation = pan.translation(in: pan.view)
            let velocity = pan.velocity(in: pan.view)
            return MobileEdgeSwipe.shouldBegin(horizontal: Double(translation.x), vertical: Double(translation.y),
                                               velocityX: Double(velocity.x), velocityY: Double(velocity.y),
                                               isDrawer: pan === drawer)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Native back and scrolling wait for the appropriate horizontal pan.
            // Do not create circular failure dependencies between our own pair.
            guard otherGestureRecognizer !== edge, otherGestureRecognizer !== drawer else { return false }
            return gestureRecognizer.isEnabled && (gestureRecognizer === edge || gestureRecognizer === drawer)
                && otherGestureRecognizer is UIPanGestureRecognizer
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            false
        }

        private func event(_ phase: NavigationSwipe.Phase, pending: Pending,
                           recognizer: UIPanGestureRecognizer) -> NavigationSwipe {
            let translation = recognizer.translation(in: recognizer.view)
            return NavigationSwipe(id: pending.id, source: pending.source, phase: phase, intent: pending.intent,
                                   translation: CGSize(width: translation.x, height: translation.y),
                                   velocity: recognizer.velocity(in: recognizer.view),
                                   width: recognizer.view?.bounds.width ?? 0)
        }

        private func cancelPending(deferred: Bool) {
            guard let captured = pending else { return }
            pending = nil
            let recognizer: UIPanGestureRecognizer = captured.source == .edge ? edge : drawer
            let cancelled = event(.cancelled, pending: captured, recognizer: recognizer)
            let callback = configuration.onSwipe
            // update/dismantle can run inside a SwiftUI rendering transaction.
            if deferred { DispatchQueue.main.async { callback(cancelled) } }
            else { callback(cancelled) }
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let source: NavigationSwipe.Source = recognizer === edge ? .edge : .drawer
            switch recognizer.state {
            case .began:
                guard canNavigate, pending == nil else { return }
                let captured = Pending(source: source, intent: configuration.intent)
                pending = captured
                configuration.onSwipe(event(.began, pending: captured, recognizer: recognizer))
            case .changed:
                guard let captured = pending, captured.source == source else { return }
                guard canNavigate, captured.intent == configuration.intent else {
                    cancelPending(deferred: false)
                    return
                }
                configuration.onSwipe(event(.changed, pending: captured, recognizer: recognizer))
            case .ended:
                guard let captured = pending, captured.source == source else { return }
                pending = nil
                let phase: NavigationSwipe.Phase = canNavigate && captured.intent == configuration.intent ? .ended : .cancelled
                configuration.onSwipe(event(phase, pending: captured, recognizer: recognizer))
            case .cancelled, .failed:
                // A sibling recognizer failing cannot cancel the owner of an
                // already recognized touch sequence.
                if pending?.source == source { cancelPending(deferred: false) }
            default:
                break
            }
        }
    }
}
