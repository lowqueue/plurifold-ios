import Foundation

enum MobileEdgeSwipe {
    /// A small margin inside the safe area is easier to catch than UIKit's
    /// exact screen edge, especially with a case or a landscape sensor inset.
    static func beginsAtEdge(x: Double, safeAreaLeading: Double, width: Double) -> Bool {
        guard x.isFinite, safeAreaLeading.isFinite, width.isFinite, width > 0 else { return false }
        return x >= 0 && x <= min(max(safeAreaLeading, 0) + 32, width * 0.25)
    }

    /// Use actual movement once it is available. The velocity of a slow start
    /// can briefly be zero or point across the intended direction.
    static func shouldBegin(horizontal: Double, vertical: Double,
                            velocityX: Double, velocityY: Double, isDrawer: Bool) -> Bool {
        guard horizontal.isFinite, vertical.isFinite, velocityX.isFinite, velocityY.isFinite else { return false }
        let hasTravel = max(abs(horizontal), abs(vertical)) >= 3
        let x = hasTravel ? horizontal : velocityX
        let y = hasTravel ? vertical : velocityY
        return (isDrawer ? abs(x) : x) > abs(y) * 1.15
    }

    /// A deliberate slow pull and a short fling both work. Tiny movements and
    /// vertical scrolling must never open a menu or discard a reading screen.
    static func shouldComplete(horizontal: Double, vertical: Double,
                               velocity: Double, width: Double) -> Bool {
        guard width.isFinite, width > 0, horizontal.isFinite, vertical.isFinite, velocity.isFinite,
              horizontal > abs(vertical), velocity > -120 else { return false }
        let distance = min(max(width * 0.22, 56), 100)
        return horizontal >= distance || (horizontal >= 18 && velocity >= 650)
    }
}
