import XCTest
@testable import Plurifold

final class WelcomeBubblePhysicsTests: XCTestCase {
    func testEveryOfferedLanguageStartsInsidePhoneAndTabletBounds() {
        for width in [320.0, 345, 430, 580] {
            let size = min(92, max(68, (width - 42) / (width >= 400 ? 4 : 3)))
            let bodies = WelcomeBubblePhysics.makeBodies(count: 8, width: width, height: 326, tileSize: size)
            XCTAssertEqual(bodies.count, 8)
            for body in bodies {
                XCTAssertGreaterThanOrEqual(body.x, body.radius)
                XCTAssertLessThanOrEqual(body.x, width - body.radius)
                XCTAssertGreaterThanOrEqual(body.y, body.radius)
                XCTAssertLessThanOrEqual(body.y, 326 - body.radius)
            }
        }
    }

    func testCollisionSeparatesTilesAndTransfersMomentum() {
        var bodies = [body(x: 140, y: 140, vx: 120), body(x: 205, y: 140, vx: -20)]
        WelcomeBubblePhysics.step(&bodies, width: 400, height: 300, elapsed: 1.0 / 60, time: 0)
        XCTAssertGreaterThanOrEqual(hypot(bodies[1].x - bodies[0].x, bodies[1].y - bodies[0].y), 80 - 0.001)
        XCTAssertGreaterThan(bodies[1].vx, bodies[0].vx)
    }

    func testHeldTileMovesItsNeighborWithoutBeingMovedByCollision() {
        var bodies = [body(x: 140, y: 140), body(x: 190, y: 140)]
        WelcomeBubblePhysics.step(&bodies, width: 400, height: 300, elapsed: 1.0 / 60, time: 0,
                                  heldIndex: 0, ambientMotion: false)
        XCTAssertEqual(bodies[0].x, 140)
        XCTAssertEqual(bodies[0].y, 140)
        XCTAssertEqual(bodies[1].x, 220, accuracy: 0.001)
    }

    func testFlingBouncesAtFieldEdges() {
        var tile = body(x: 2, y: 400, vx: -200, vy: 300)
        WelcomeBubblePhysics.constrain(&tile, width: 320, height: 326)
        XCTAssertEqual(tile.x, 42)
        XCTAssertEqual(tile.y, 284)
        XCTAssertGreaterThan(tile.vx, 0)
        XCTAssertLessThan(tile.vy, 0)
    }

    func testPauseFreezesTilesAndReleaseIsFiniteAndBounded() {
        var bodies = [body(x: 140, y: 140, vx: 120, vy: 30)]
        WelcomeBubblePhysics.step(&bodies, width: 400, height: 300, elapsed: 1.0 / 60,
                                  time: 100, ambientMotion: false)
        XCTAssertEqual(bodies[0].x, 140)
        XCTAssertEqual(bodies[0].y, 140)
        XCTAssertEqual(bodies[0].vx, 0)
        XCTAssertEqual(bodies[0].vy, 0)
        XCTAssertEqual(WelcomeBubblePhysics.releaseVelocity(predictedTranslation: 1_000_000, translation: 0), 650)
        XCTAssertEqual(WelcomeBubblePhysics.releaseVelocity(predictedTranslation: -1_000_000, translation: 0), -650)
        XCTAssertEqual(WelcomeBubblePhysics.releaseVelocity(predictedTranslation: .nan, translation: 0), 0)
        XCTAssertEqual(WelcomeBubblePhysics.releaseVelocity(predictedTranslation: 12, translation: 10), 8)
    }

    func testBackgroundGapCannotAdvanceAnUnboundedSimulationStep() {
        var afterGap = [body(x: 140, y: 140, vx: 120)]
        var normal = afterGap
        WelcomeBubblePhysics.step(&afterGap, width: 400, height: 300, elapsed: 3_600, time: 0)
        WelcomeBubblePhysics.step(&normal, width: 400, height: 300, elapsed: 1.0 / 30, time: 0)
        XCTAssertEqual(afterGap, normal)
        let unchanged = normal
        WelcomeBubblePhysics.step(&normal, width: 400, height: 300, elapsed: .nan, time: 0)
        XCTAssertEqual(normal, unchanged)
    }

    func testCoincidentTilesRecoverWithoutNonFiniteValues() {
        var bodies = [body(x: 140, y: 140), body(x: 140, y: 140)]
        WelcomeBubblePhysics.step(&bodies, width: 400, height: 300, elapsed: 1.0 / 60, time: 0,
                                  ambientMotion: false)
        XCTAssertGreaterThan(abs(bodies[0].x - bodies[1].x), 79)
        XCTAssertTrue(bodies.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.vx.isFinite && $0.vy.isFinite })
    }

    private func body(x: Double, y: Double, vx: Double = 0, vy: Double = 0) -> WelcomeBubbleBody {
        WelcomeBubbleBody(x: x, y: y, vx: vx, vy: vy, anchorX: x, anchorY: y,
                          radius: 40, angle: 0, homeAngle: 0)
    }
}
