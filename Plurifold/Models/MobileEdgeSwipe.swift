import Foundation

enum MobileEdgeSwipe {
    /// A deliberate slow pull and a short fling both work. Tiny movements and
    /// vertical scrolling must never open a menu or discard a reading screen.
    static func shouldComplete(horizontal: Double, vertical: Double,
                               velocity: Double, width: Double) -> Bool {
        guard width > 0, horizontal > abs(vertical), velocity > -120 else { return false }
        let distance = min(max(width * 0.22, 56), 100)
        return horizontal >= distance || (horizontal >= 18 && velocity >= 650)
    }
}
