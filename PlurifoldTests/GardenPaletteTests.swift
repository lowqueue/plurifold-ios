import XCTest
@testable import Plurifold

final class GardenPaletteTests: XCTestCase {
    func testEveryColorwayProvidesReadableCardActionAndNavigationTextInBothLightingModes() {
        for colorway in AppColorway.allCases {
            let colors = GardenColorwayTokens.values(for: colorway)
            let pairs: [(String, AdaptiveHex, AdaptiveHex)] = [
                ("Card text", colors.ink, colors.card),
                ("Secondary text", colors.mutedInk, colors.card),
                ("Action text", colors.actionInk, colors.action),
                ("Navigation start", colors.navInk, colors.navStart),
                ("Navigation end", colors.navInk, colors.navEnd),
                ("CTA start", AdaptiveHex(0xFFFFFF), colors.ctaStart),
                ("CTA end", AdaptiveHex(0xFFFFFF), colors.ctaEnd)
            ]
            for (label, foreground, background) in pairs {
                XCTAssertGreaterThanOrEqual(contrast(foreground.light, background.light), 4.5,
                                            "\(colorway.name): \(label), light")
                XCTAssertGreaterThanOrEqual(contrast(foreground.dark, background.dark), 4.5,
                                            "\(colorway.name): \(label), dark")
            }
        }
    }

    func testGardenAndOriginalRemainDistinctAcrossAllColorways() {
        for colorway in AppColorway.allCases {
            let original = ColorwayTokens.values(for: colorway, layout: .original)
            let garden = ColorwayTokens.values(for: colorway, layout: .garden)
            XCTAssertNotEqual(original.canvas.light, garden.canvas.light)
            XCTAssertNotEqual(original.masthead.light, garden.masthead.light)
            // Garden's pale header needs dark ink, while Original keeps its
            // light wordmark on a colored masthead.
            XCTAssertGreaterThanOrEqual(contrast(garden.mastheadInk.light, garden.masthead.light), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(garden.mastheadInk.dark, garden.masthead.dark), 4.5)
        }
    }

    private func contrast(_ first: UInt, _ second: UInt) -> Double {
        let firstLuminance = luminance(first)
        let secondLuminance = luminance(second)
        return (max(firstLuminance, secondLuminance) + 0.05) / (min(firstLuminance, secondLuminance) + 0.05)
    }

    private func luminance(_ hex: UInt) -> Double {
        func channel(_ shift: UInt) -> Double {
            let value = Double((hex >> shift) & 255) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }
}
