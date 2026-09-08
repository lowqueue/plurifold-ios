import Observation
import XCTest
@testable import Plurifold

final class AppAppearanceTests: XCTestCase {
    func testColorwayAndLightingPersistIndependentlyBetweenLaunches() throws {
        let suite = "AppAppearanceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let appearance = AppAppearance(defaults: defaults)
        XCTAssertEqual(appearance.colorway, .verdant)
        XCTAssertEqual(appearance.lighting, .system)
        XCTAssertNil(appearance.preferredColorScheme)

        appearance.colorway = .vermilion
        appearance.lighting = .dark
        appearance.colorway = .blueHour

        let restored = AppAppearance(defaults: defaults)
        XCTAssertEqual(restored.colorway, .blueHour)
        XCTAssertEqual(restored.lighting, .dark)
        XCTAssertEqual(restored.preferredColorScheme, .dark)
    }

    func testUnknownStoredOptionsUseWebsiteDefaultAndSystemLighting() throws {
        let suite = "AppAppearanceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("retired-palette", forKey: AppAppearance.colorwayStorageKey)
        defaults.set("automatic-old-value", forKey: AppAppearance.lightingStorageKey)

        let appearance = AppAppearance(defaults: defaults)
        XCTAssertEqual(appearance.colorway, .verdant)
        XCTAssertEqual(appearance.lighting, .system)
    }

    func testAppearanceRevisionParticipatesInObservationWithoutReplacingRoot() throws {
        let suite = "AppAppearanceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let appearance = AppAppearance(defaults: defaults)
        let changed = expectation(description: "The observed appearance invalidates")
        let initialRevision = appearance.revisionID

        withObservationTracking {
            _ = appearance.revisionID
        } onChange: {
            changed.fulfill()
        }
        appearance.colorway = .vermilion

        wait(for: [changed], timeout: 1)
        XCTAssertNotEqual(appearance.revisionID, initialRevision)
    }
}
