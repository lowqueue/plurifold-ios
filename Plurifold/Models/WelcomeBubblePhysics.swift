import Foundation

struct WelcomeBubbleBody: Equatable, Sendable {
    var x: Double
    var y: Double
    var vx = 0.0
    var vy = 0.0
    var anchorX: Double
    var anchorY: Double
    var radius: Double
    var angle: Double
    var homeAngle: Double
}

/// Small bounded spring-and-collision simulation. Coordinates are local to the
/// language field, so tiles cannot cover account controls or leave the screen.
enum WelcomeBubblePhysics {
    static func makeBodies(count: Int, width: Double, height: Double, tileSize: Double) -> [WelcomeBubbleBody] {
        guard width.isFinite, height.isFinite, tileSize.isFinite,
              width > 0, height > 0, tileSize > 0, count > 0 else { return [] }
        let columns = width >= 400 ? 4 : 3
        let rows = Int(ceil(Double(count) / Double(columns)))
        let padding = tileSize * 0.6 + 5
        return (0..<count).map { index in
            let column = index % columns
            let row = index / columns
            let itemsInRow = min(columns, count - row * columns)
            let cellWidth = (width - 2 * padding) / Double(max(columns - 1, 1))
            let start = (width - Double(itemsInRow - 1) * cellWidth) / 2
            let x = start + Double(column) * cellWidth
            let y = padding + Double(row) * (height - 2 * padding) / Double(max(rows - 1, 1))
            let angle = [-9.0, 7, -6, 9, -7, 6, 8, -8][index % 8]
            return WelcomeBubbleBody(x: x, y: y, anchorX: x, anchorY: y,
                                     radius: tileSize * 0.55, angle: angle, homeAngle: angle)
        }
    }

    static func step(_ bodies: inout [WelcomeBubbleBody], width: Double, height: Double,
                     elapsed: Double, time: Double, heldIndex: Int? = nil,
                     ambientMotion: Bool = true) {
        guard width.isFinite, height.isFinite, width > 0, height > 0,
              elapsed.isFinite, elapsed > 0, time.isFinite else { return }
        // Returning from the background can produce a very large time sample.
        let dt = min(elapsed, 1.0 / 30)
        for index in bodies.indices where index != heldIndex {
            if ambientMotion {
                let dx = bodies[index].anchorX - bodies[index].x
                let dy = bodies[index].anchorY - bodies[index].y
                bodies[index].vx += (dx * 1.25 + sin(time * 0.7 + Double(index) * 1.8) * 8) * dt
                bodies[index].vy += (dy * 1.25 + cos(time * 0.65 + Double(index) * 2.1) * 7) * dt
                let damping = exp(-2.0 * dt)
                bodies[index].vx *= damping
                bodies[index].vy *= damping
                bodies[index].x += bodies[index].vx * dt
                bodies[index].y += bodies[index].vy * dt
                let targetAngle = bodies[index].homeAngle + max(-12, min(12, bodies[index].vx * 0.035))
                bodies[index].angle += (targetAngle - bodies[index].angle) * min(1, dt * 7)
            } else {
                bodies[index].vx = 0
                bodies[index].vy = 0
            }
        }
        // Resolve pairs twice to keep a dragged tile from stacking its neighbors.
        for _ in 0..<2 {
            for first in bodies.indices {
                for second in bodies.indices where second > first {
                    var dx = bodies[second].x - bodies[first].x
                    var dy = bodies[second].y - bodies[first].y
                    var distance = hypot(dx, dy)
                    let minimum = bodies[first].radius + bodies[second].radius
                    guard distance < minimum else { continue }
                    if distance < 0.001 { dx = 1; dy = 0; distance = 1 }
                    let nx = dx / distance
                    let ny = dy / distance
                    let firstMass = first == heldIndex ? 0.0 : 1.0
                    let secondMass = second == heldIndex ? 0.0 : 1.0
                    let totalMass = firstMass + secondMass
                    let overlap = minimum - distance
                    bodies[first].x -= nx * overlap * firstMass / totalMass
                    bodies[first].y -= ny * overlap * firstMass / totalMass
                    bodies[second].x += nx * overlap * secondMass / totalMass
                    bodies[second].y += ny * overlap * secondMass / totalMass
                    let closingSpeed = (bodies[second].vx - bodies[first].vx) * nx
                        + (bodies[second].vy - bodies[first].vy) * ny
                    if closingSpeed < 0, ambientMotion {
                        let impulse = -1.55 * closingSpeed / totalMass
                        bodies[first].vx -= impulse * nx * firstMass
                        bodies[first].vy -= impulse * ny * firstMass
                        bodies[second].vx += impulse * nx * secondMass
                        bodies[second].vy += impulse * ny * secondMass
                    }
                }
            }
            for index in bodies.indices { constrain(&bodies[index], width: width, height: height) }
        }
    }

    static func constrain(_ body: inout WelcomeBubbleBody, width: Double, height: Double) {
        let padding = body.radius + 2
        let minX = min(padding, width / 2)
        let maxX = max(minX, width - padding)
        let minY = min(padding, height / 2)
        let maxY = max(minY, height - padding)
        if body.x < minX { body.x = minX; body.vx = abs(body.vx) * 0.6 }
        if body.x > maxX { body.x = maxX; body.vx = -abs(body.vx) * 0.6 }
        if body.y < minY { body.y = minY; body.vy = abs(body.vy) * 0.6 }
        if body.y > maxY { body.y = maxY; body.vy = -abs(body.vy) * 0.6 }
    }

    static func releaseVelocity(predictedTranslation: Double, translation: Double) -> Double {
        guard predictedTranslation.isFinite, translation.isFinite else { return 0 }
        return max(-650, min(650, (predictedTranslation - translation) * 4))
    }
}
