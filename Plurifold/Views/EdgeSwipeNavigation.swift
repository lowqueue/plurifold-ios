import SwiftUI
import UIKit

/// Observes the root controller's existing touch hierarchy. No transparent
/// overlay sits on top of text, buttons, or scrolling content.
struct EdgeSwipeNavigation: UIViewControllerRepresentable {
    let isEnabled: Bool
    let intent: MobileEdgeNavigationIntent
    let onComplete: (MobileEdgeNavigationIntent) -> Void

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
        private var configuration: EdgeSwipeNavigation
        private weak var owner: UIViewController?
        private var pendingIntent: MobileEdgeNavigationIntent?
        private var attached = false
        private lazy var edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdge(_:)))

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
            edge.edges = .left
            edge.maximumNumberOfTouches = 1
            edge.delaysTouchesBegan = false
            edge.delegate = self
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
                pendingIntent = nil
            }
            self.configuration = configuration
            attachIfNeeded()
            edge.isEnabled = configuration.isEnabled
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
                attached = true
            }
            edge.isEnabled = configuration.isEnabled
        }

        func detach() {
            pendingIntent = nil
            edge.view?.removeGestureRecognizer(edge)
            owner = nil
            attached = false
        }

        private var canNavigate: Bool {
            guard configuration.isEnabled, !UIAccessibility.isVoiceOverRunning,
                  let owner, viewIfLoaded?.window != nil else { return false }
            return !hasPresentationOrTransition(owner)
        }

        private func hasPresentationOrTransition(_ controller: UIViewController) -> Bool {
            // Covers sheets/popovers owned by any nested NavigationStack, as
            // well as pushes that have not finished updating their visible view.
            if controller.presentedViewController != nil || controller.transitionCoordinator != nil {
                return true
            }
            return controller.children.contains { child in
                child.viewIfLoaded?.window != nil && hasPresentationOrTransition(child)
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard canNavigate, let surface = edge.view else { return false }
            let point = touch.location(in: surface)
            // Use the controller's physical edge, including landscape notch
            // insets. The background observer itself follows the safe area.
            return surface.bounds.contains(point) && point.x <= 20
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard canNavigate else { return false }
            let velocity = edge.velocity(in: edge.view)
            return velocity.x > abs(velocity.y)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // The native interactive-pop and scroll pans wait for this edge
            // gesture. This keeps one owner of back navigation without replacing
            // UIKit delegates or changing the native recognizers' enabled state.
            gestureRecognizer === edge && otherGestureRecognizer is UIPanGestureRecognizer
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            false
        }

        @objc private func handleEdge(_ recognizer: UIScreenEdgePanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                pendingIntent = canNavigate ? configuration.intent : nil
            case .ended:
                let captured = pendingIntent
                pendingIntent = nil
                guard let captured, canNavigate, captured == configuration.intent else { return }
                let translation = recognizer.translation(in: recognizer.view)
                let velocity = recognizer.velocity(in: recognizer.view)
                guard MobileEdgeSwipe.shouldComplete(horizontal: Double(translation.x),
                                                      vertical: Double(translation.y),
                                                      velocity: Double(velocity.x),
                                                      width: Double(recognizer.view?.bounds.width ?? 0)) else { return }
                configuration.onComplete(captured)
            case .cancelled, .failed:
                pendingIntent = nil
            default:
                break
            }
        }
    }
}
