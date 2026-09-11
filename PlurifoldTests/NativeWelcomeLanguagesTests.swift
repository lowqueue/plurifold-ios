import XCTest
@testable import Plurifold

final class NativeWelcomeLanguagesTests: XCTestCase {
    func testCatalogMatchesOfferedLanguagesAndSearchFindsNativeNames() {
        XCTAssertEqual(Set(NativeWelcomeLanguages.offered.map(\.code)),
                       Set(["it-IT", "es-AR", "et-EE", "ka-GE", "ru-RU", "uk-UA", "ja-JP", "de-DE"]))
        XCTAssertEqual(NativeWelcomeLanguages.offered.filter { $0.matches("日本語") }.map(\.code), ["ja-JP"])
        XCTAssertEqual(NativeWelcomeLanguages.offered.filter { $0.matches(" espanol ") }.map(\.code), ["es-AR"])
        XCTAssertEqual(NativeWelcomeLanguages.offered.filter { $0.matches("GEORGIAN") }.map(\.code), ["ka-GE"])
        XCTAssertTrue(NativeWelcomeLanguages.offered.filter { $0.matches("French") }.isEmpty)
    }

    func testSelectionPreservesOrderRejectsUnknownValuesAndIsConsumedOnlyOnce() throws {
        let suite = "plurifold-welcome-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        NativeWelcomeLanguages.saveSelection(["ja-JP", "it-IT", "ja-JP", "bad", "de-DE"], defaults: defaults)
        XCTAssertEqual(NativeWelcomeLanguages.selection(defaults: defaults), ["ja-JP", "it-IT", "de-DE"])
        XCTAssertEqual(NativeWelcomeLanguages.selection(defaults: defaults), ["ja-JP", "it-IT", "de-DE"])
        XCTAssertEqual(NativeWelcomeLanguages.takeSelection(defaults: defaults), ["ja-JP", "it-IT", "de-DE"])
        XCTAssertTrue(NativeWelcomeLanguages.takeSelection(defaults: defaults).isEmpty)
        NativeWelcomeLanguages.saveSelection(["it-IT"], defaults: defaults)
        NativeWelcomeLanguages.saveSelection([], defaults: defaults)
        XCTAssertTrue(NativeWelcomeLanguages.selection(defaults: defaults).isEmpty)
    }
}
