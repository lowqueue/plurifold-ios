import XCTest
@testable import Plurifold

final class SidebarMotionTests: XCTestCase {
    func testNormalTravelTracksFingerWithoutEasing() {
        XCTAssertEqual(SidebarMotion.position(start: 0, translation: 85, width: 340,
                                             reduceMotion: false), 0.25, accuracy: 0.0001)
        XCTAssertEqual(SidebarMotion.position(start: 1, translation: -85, width: 340,
                                             reduceMotion: false), 0.75, accuracy: 0.0001)
        XCTAssertEqual(SidebarMotion.position(start: 0.4, translation: 34, width: 340,
                                             reduceMotion: false), 0.5, accuracy: 0.0001)
    }

    func testSlowPullsSettleOnTheSideOfTheMidpoint() {
        XCTAssertFalse(SidebarMotion.shouldOpen(start: 0, translation: 169, velocity: 0, width: 340))
        XCTAssertTrue(SidebarMotion.shouldOpen(start: 0, translation: 171, velocity: 0, width: 340))
        XCTAssertTrue(SidebarMotion.shouldOpen(start: 1, translation: -169, velocity: 0, width: 340))
        XCTAssertFalse(SidebarMotion.shouldOpen(start: 1, translation: -171, velocity: 0, width: 340))
    }

    func testShortFlingOpensAndClosesWithDeliberateTravel() {
        XCTAssertTrue(SidebarMotion.shouldOpen(start: 0, translation: 26, velocity: 900, width: 340))
        XCTAssertFalse(SidebarMotion.shouldOpen(start: 1, translation: -26, velocity: -900, width: 340))
        XCTAssertFalse(SidebarMotion.shouldOpen(start: 0, translation: 26, velocity: 0, width: 340))
        XCTAssertTrue(SidebarMotion.shouldOpen(start: 1, translation: -26, velocity: 0, width: 340))
    }

    func testDeliberateFlingDoesNotRequireHalfOfAWideDrawer() {
        for width in [280.0, 340, 600] {
            XCTAssertTrue(SidebarMotion.shouldOpen(start: 0, translation: 22, velocity: 650, width: width))
            XCTAssertFalse(SidebarMotion.shouldOpen(start: 1, translation: -22, velocity: -650, width: width))
            XCTAssertFalse(SidebarMotion.shouldOpen(start: 0, translation: 22, velocity: 100, width: width))
            XCTAssertTrue(SidebarMotion.shouldOpen(start: 1, translation: -22, velocity: -100, width: width))
        }
    }

    func testEdgeStartIncludesAnIntentionalMarginAndLandscapeSafeArea() {
        XCTAssertTrue(MobileEdgeSwipe.beginsAtEdge(x: 30, safeAreaLeading: 0, width: 390))
        XCTAssertFalse(MobileEdgeSwipe.beginsAtEdge(x: 45, safeAreaLeading: 0, width: 390))
        XCTAssertTrue(MobileEdgeSwipe.beginsAtEdge(x: 80, safeAreaLeading: 59, width: 844))
        XCTAssertFalse(MobileEdgeSwipe.beginsAtEdge(x: 100, safeAreaLeading: 59, width: 844))
        XCTAssertFalse(MobileEdgeSwipe.beginsAtEdge(x: -1, safeAreaLeading: 0, width: 390))
        XCTAssertFalse(MobileEdgeSwipe.beginsAtEdge(x: .nan, safeAreaLeading: 0, width: 390))
        XCTAssertFalse(MobileEdgeSwipe.beginsAtEdge(x: 0, safeAreaLeading: 0, width: 0))
    }

    func testSlowHorizontalStartUsesTravelInsteadOfNoisyVelocity() {
        XCTAssertTrue(MobileEdgeSwipe.shouldBegin(horizontal: 12, vertical: 2,
                                                 velocityX: 0, velocityY: 15, isDrawer: false))
        XCTAssertTrue(MobileEdgeSwipe.shouldBegin(horizontal: -12, vertical: 2,
                                                 velocityX: 0, velocityY: 15, isDrawer: true))
        XCTAssertFalse(MobileEdgeSwipe.shouldBegin(horizontal: -12, vertical: 2,
                                                  velocityX: -100, velocityY: 0, isDrawer: false))
        XCTAssertFalse(MobileEdgeSwipe.shouldBegin(horizontal: 10, vertical: 10,
                                                  velocityX: 200, velocityY: 100, isDrawer: true))
        XCTAssertFalse(MobileEdgeSwipe.shouldBegin(horizontal: 3, vertical: 15,
                                                  velocityX: 200, velocityY: 100, isDrawer: false))
        XCTAssertFalse(MobileEdgeSwipe.shouldBegin(horizontal: 0, vertical: 0,
                                                  velocityX: 0, velocityY: 0, isDrawer: false))
        XCTAssertTrue(MobileEdgeSwipe.shouldBegin(horizontal: 0, vertical: 0,
                                                 velocityX: 100, velocityY: 10, isDrawer: false))
    }

    func testInvalidEdgeSamplesCannotPopANavigationDestination() {
        XCTAssertFalse(MobileEdgeSwipe.shouldComplete(horizontal: .infinity, vertical: 0, velocity: 100, width: 390))
        XCTAssertFalse(MobileEdgeSwipe.shouldComplete(horizontal: 100, vertical: .nan, velocity: 100, width: 390))
        XCTAssertFalse(MobileEdgeSwipe.shouldComplete(horizontal: 100, vertical: 0, velocity: .infinity, width: 390))
        XCTAssertFalse(MobileEdgeSwipe.shouldComplete(horizontal: 100, vertical: 0, velocity: 100, width: .infinity))
    }

    func testTinyMovementIgnoresEvenAnExtremeReleaseVelocity() {
        XCTAssertFalse(SidebarMotion.shouldOpen(start: 0, translation: 17, velocity: 10_000, width: 340))
        XCTAssertTrue(SidebarMotion.shouldOpen(start: 1, translation: -17, velocity: -10_000, width: 340))
    }

    func testReversingDirectionBeforeReleaseCanChangeTheDestination() {
        XCTAssertTrue(SidebarMotion.shouldOpen(start: 0, translation: 220, velocity: 0, width: 340))
        XCTAssertFalse(SidebarMotion.shouldOpen(start: 0, translation: 220, velocity: -600, width: 340))
        XCTAssertFalse(SidebarMotion.shouldOpen(start: 1, translation: -220, velocity: 0, width: 340))
        XCTAssertTrue(SidebarMotion.shouldOpen(start: 1, translation: -220, velocity: 600, width: 340))
        XCTAssertFalse(SidebarMotion.shouldOpen(start: 0, translation: 60, velocity: 0, width: 340))
    }

    func testEndResistanceIsContinuousSymmetricAndBounded() {
        let small = SidebarMotion.position(start: 1, translation: 1, width: 340, reduceMotion: false) - 1
        let large = SidebarMotion.position(start: 1, translation: 340, width: 340, reduceMotion: false) - 1
        let extreme = SidebarMotion.position(start: 1, translation: 1_000_000, width: 340, reduceMotion: false) - 1
        XCTAssertGreaterThan(small, 0)
        XCTAssertLessThan(small, 1.0 / 340)
        XCTAssertGreaterThan(large, small)
        XCTAssertGreaterThan(extreme, large)
        XCTAssertLessThanOrEqual(extreme, 0.06)
        XCTAssertEqual(SidebarMotion.position(start: 0, translation: -340, width: 340,
                                             reduceMotion: false), -large, accuracy: 0.0001)
        XCTAssertEqual(SidebarMotion.position(start: 1, translation: 0, width: 340,
                                             reduceMotion: false), 1)
    }

    func testReducedMotionRetainsFingerTrackingButRemovesElasticOvershoot() {
        XCTAssertEqual(SidebarMotion.position(start: 0, translation: 170, width: 340,
                                             reduceMotion: true), 0.5)
        XCTAssertEqual(SidebarMotion.position(start: 1, translation: 200, width: 340,
                                             reduceMotion: true), 1)
        XCTAssertEqual(SidebarMotion.position(start: 0, translation: -200, width: 340,
                                             reduceMotion: true), 0)
    }

    func testCatchingAnInterruptedSpringPreservesItsDisplayedPosition() {
        for start in [-0.02, 0.35, 1.02] {
            XCTAssertEqual(SidebarMotion.position(start: start, translation: 0, width: 340,
                                                 reduceMotion: false), start, accuracy: 0.0001)
        }
        XCTAssertEqual(SidebarMotion.position(start: 1.02, translation: -10.2, width: 340,
                                             reduceMotion: false), 1, accuracy: 0.0001)
        XCTAssertEqual(SidebarMotion.position(start: -0.02, translation: 10.2, width: 340,
                                             reduceMotion: false), 0, accuracy: 0.0001)
    }

    func testCatchingAndReversingElasticTravelContinuesTheSameMotion() {
        let caught = SidebarMotion.position(start: 1, translation: 34, width: 340, reduceMotion: false)
        let returned = SidebarMotion.position(start: caught, translation: -17, width: 340, reduceMotion: false)
        let uninterrupted = SidebarMotion.position(start: 1, translation: 17, width: 340, reduceMotion: false)
        XCTAssertEqual(returned, uninterrupted, accuracy: 0.0001)

        let lowerCaught = SidebarMotion.position(start: 0, translation: -34, width: 340, reduceMotion: false)
        let lowerReturned = SidebarMotion.position(start: lowerCaught, translation: 17, width: 340, reduceMotion: false)
        XCTAssertEqual(lowerReturned, 1 - uninterrupted, accuracy: 0.0001)
        XCTAssertTrue(SidebarMotion.shouldOpen(start: 1.02, translation: -175, velocity: 0, width: 340))
        XCTAssertFalse(SidebarMotion.shouldOpen(start: 1.02, translation: -185, velocity: 0, width: 340))
    }

    func testCatchingAnElasticLimitDoesNotProduceNonFiniteMotion() {
        for start in [-0.06, 1.06] {
            XCTAssertEqual(SidebarMotion.position(start: start, translation: 0, width: 340,
                                                 reduceMotion: false), start, accuracy: 0.0001)
            let moved = SidebarMotion.position(start: start, translation: -10, width: 340, reduceMotion: false)
            XCTAssertTrue(moved.isFinite)
            XCTAssertGreaterThanOrEqual(moved, -0.06)
            XCTAssertLessThanOrEqual(moved, 1.06)
        }
    }

    func testInvalidWidthLeavesDrawerOnItsStartingSide() {
        for width in [0.0, -1, Double.nan, Double.infinity] {
            XCTAssertEqual(SidebarMotion.position(start: 0.3, translation: 200, width: width,
                                                 reduceMotion: false), 0.3)
            XCTAssertFalse(SidebarMotion.shouldOpen(start: 0, translation: 200, velocity: 900, width: width))
            XCTAssertTrue(SidebarMotion.shouldOpen(start: 1, translation: -200, velocity: -900, width: width))
        }
    }

    func testInvalidSamplesCannotIntroduceNonFiniteMotion() {
        XCTAssertEqual(SidebarMotion.position(start: 1, translation: .nan, width: 340,
                                             reduceMotion: false), 1)
        XCTAssertFalse(SidebarMotion.shouldOpen(start: 0, translation: .infinity, velocity: 900, width: 340))
        XCTAssertTrue(SidebarMotion.shouldOpen(start: 0, translation: 200, velocity: .nan, width: 340))
        let position = SidebarMotion.position(start: 0, translation: Double.greatestFiniteMagnitude,
                                              width: Double.leastNonzeroMagnitude, reduceMotion: false)
        XCTAssertTrue(position.isFinite)
        XCTAssertLessThanOrEqual(position, 1.06)
    }
}
