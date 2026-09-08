import Foundation

/// Finger tracking is direct during the normal travel range. Only the ends
/// resist further movement; release chooses a destination for the UI to spring to.
enum SidebarMotion {
    private static let elasticLimit = 0.06

    static func position(start: Double, translation: Double, width: Double,
                         reduceMotion: Bool) -> Double {
        let origin = startingPosition(start)
        guard width.isFinite, width > 0, translation.isFinite else {
            return reduceMotion ? min(max(origin, 0), 1) : origin
        }
        if reduceMotion { return min(max(min(max(origin, 0), 1) + translation / width, 0), 1) }
        if translation == 0 { return origin }
        // The starting value may be the presentation layer's position partway
        // through a spring. Undo its resistance before applying fresh travel so
        // catching an overshoot does not clamp the drawer back to an endpoint.
        let proposed = unresistedPosition(origin) + translation / width
        if proposed < 0 { return -resistance(-proposed) }
        if proposed > 1 { return 1 + resistance(proposed - 1) }
        return proposed
    }

    static func shouldOpen(start: Double, translation: Double,
                           velocity: Double, width: Double) -> Bool {
        let origin = startingPosition(start)
        guard width.isFinite, width > 0, translation.isFinite else { return origin >= 0.5 }
        let current = unresistedPosition(origin) + translation / width
        // Tiny edge movements do not turn into a fling. A release reversal can
        // change the result because we use the final velocity and position.
        let projection: Double
        if abs(translation) >= 18, velocity.isFinite {
            projection = min(max(velocity / width * 0.18, -0.5), 0.5)
        } else {
            projection = 0
        }
        return current + projection >= 0.5
    }

    private static func startingPosition(_ start: Double) -> Double {
        start.isFinite ? min(max(start, -elasticLimit), 1 + elasticLimit) : 0
    }

    private static func unresistedPosition(_ position: Double) -> Double {
        if position < 0 { return -inverseResistance(-position) }
        if position > 1 { return 1 + inverseResistance(position - 1) }
        return position
    }

    private static func inverseResistance(_ excess: Double) -> Double {
        // The asymptote can round to its exact limit in a presentation sample.
        // Stay below that singularity so subsequent movement remains finite.
        let bounded = min(excess, elasticLimit.nextDown)
        return elasticLimit * bounded / (elasticLimit - bounded)
    }

    private static func resistance(_ excess: Double) -> Double {
        // This form also remains bounded if a very small width overflows the
        // normalized translation. Its slope joins normal tracking smoothly.
        return elasticLimit * (1 - 1 / (1 + excess / elasticLimit))
    }
}
