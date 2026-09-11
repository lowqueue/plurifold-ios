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
        XCTAssertEqual(appearance.workspaceLayout, .garden)
        XCTAssertNil(appearance.preferredColorScheme)

        appearance.colorway = .vermilion
        appearance.lighting = .dark
        appearance.colorway = .blueHour
        appearance.workspaceLayout = .original

        let restored = AppAppearance(defaults: defaults)
        XCTAssertEqual(restored.colorway, .blueHour)
        XCTAssertEqual(restored.lighting, .dark)
        XCTAssertEqual(restored.preferredColorScheme, .dark)
        XCTAssertEqual(restored.workspaceLayout, .original)
    }

    func testUnknownStoredOptionsUseWebsiteDefaultAndSystemLighting() throws {
        let suite = "AppAppearanceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("retired-palette", forKey: AppAppearance.colorwayStorageKey)
        defaults.set("automatic-old-value", forKey: AppAppearance.lightingStorageKey)
        defaults.set("retired-layout", forKey: AppAppearance.workspaceLayoutStorageKey)

        let appearance = AppAppearance(defaults: defaults)
        XCTAssertEqual(appearance.colorway, .verdant)
        XCTAssertEqual(appearance.lighting, .system)
        XCTAssertEqual(appearance.workspaceLayout, .garden)
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

    func testLayoutChangeInvalidatesAppearanceWithoutChangingPaletteOrLighting() throws {
        let suite = "AppAppearanceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(AppColorway.blueHour.rawValue, forKey: AppAppearance.colorwayStorageKey)
        defaults.set(AppLighting.dark.rawValue, forKey: AppAppearance.lightingStorageKey)
        let appearance = AppAppearance(defaults: defaults)
        let changed = expectation(description: "Layout updates existing views")
        let revision = appearance.revisionID

        withObservationTracking {
            _ = appearance.revisionID
        } onChange: {
            changed.fulfill()
        }
        appearance.workspaceLayout = .original

        wait(for: [changed], timeout: 1)
        XCTAssertNotEqual(revision, appearance.revisionID)
        XCTAssertEqual(appearance.colorway, .blueHour)
        XCTAssertEqual(appearance.lighting, .dark)
        XCTAssertEqual(defaults.string(forKey: AppAppearance.workspaceLayoutStorageKey), "original")
    }
}
