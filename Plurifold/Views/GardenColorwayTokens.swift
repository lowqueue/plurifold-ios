import SwiftUI

/// The website's Garden palette, including its three distinct scenic washes.
/// Keep these values aligned with app/garden-palettes.css in the web project.
struct GardenColorwayTokens {
    let canvas: AdaptiveHex
    let ink: AdaptiveHex
    let card: AdaptiveHex
    let action: AdaptiveHex
    let actionInk: AdaptiveHex
    let secondary: AdaptiveHex
    let secondaryInk: AdaptiveHex
    let muted: AdaptiveHex
    let mutedInk: AdaptiveHex
    let accent: AdaptiveHex
    let accentInk: AdaptiveHex
    let edge: AdaptiveHex
    let input: AdaptiveHex
    let chrome: AdaptiveHex
    let logo: AdaptiveHex
    let avatar: AdaptiveHex
    let navStart: AdaptiveHex
    let navEnd: AdaptiveHex
    let navInk: AdaptiveHex
    let ctaStart: AdaptiveHex
    let ctaEnd: AdaptiveHex
    let progress: AdaptiveHex
    let track: AdaptiveHex
    let preview: AdaptiveHex
    let sceneBase: AdaptiveHex
    let sceneMobile: AdaptiveHex
    let sceneMobileMid: AdaptiveHex
    let sceneEnd: AdaptiveHex
    let artWash: AdaptiveHex

    static func values(for colorway: AppColorway) -> GardenColorwayTokens {
        switch colorway {
        case .verdant:
            GardenColorwayTokens(
                canvas: AdaptiveHex(0xF2F6F7, 0x151E1D),
                ink: AdaptiveHex(0x11141E, 0xEEF4F1),
                card: AdaptiveHex(0xFFFFFF, 0x202B28),
                action: AdaptiveHex(0x234C36, 0xACD1B6),
                actionInk: AdaptiveHex(0xFFFFFF, 0x142A1C),
                secondary: AdaptiveHex(0xE5EEEA, 0x304139),
                secondaryInk: AdaptiveHex(0x234634, 0xD6E6DC),
                muted: AdaptiveHex(0xECF1F3, 0x263630),
                mutedInk: AdaptiveHex(0x596273, 0xAFC1BA),
                accent: AdaptiveHex(0xE3EDE8, 0x354A3C),
                accentInk: AdaptiveHex(0x183F2C, 0xE8F0EC),
                edge: AdaptiveHex(0xE0E7E9, 0x3B4A43),
                input: AdaptiveHex(0xD8E0E4, 0x536359),
                chrome: AdaptiveHex(0xFBFDFE, 0x192420),
                logo: AdaptiveHex(0x568363, 0x568363),
                avatar: AdaptiveHex(0x51766D, 0x51766D),
                navStart: AdaptiveHex(0xE8F0EC, 0x30473A),
                navEnd: AdaptiveHex(0xDFECE8, 0x30473A),
                navInk: AdaptiveHex(0x1D422D, 0xE4F1E8),
                ctaStart: AdaptiveHex(0x2B5B3D, 0x2B5B3D),
                ctaEnd: AdaptiveHex(0x193A29, 0x193A29),
                progress: AdaptiveHex(0x487657, 0x9BC5AA),
                track: AdaptiveHex(0xD7E4DC, 0x40564A),
                preview: AdaptiveHex(0xF8F6EF, 0x273530),
                sceneBase: AdaptiveHex(0xF9FAF8, 0x182620),
                sceneMobile: AdaptiveHex(0xFAFBF9, 0x182620, lightAlpha: 0.90980, darkAlpha: 0.96078),
                sceneMobileMid: AdaptiveHex(0xFAFBF9, 0x182620, lightAlpha: 0.73333, darkAlpha: 0.79608),
                sceneEnd: AdaptiveHex(0x000000, 0x182620, lightAlpha: 0.00000, darkAlpha: 0.21176),
                artWash: AdaptiveHex(0x000000, 0x000000, lightAlpha: 0.00000, darkAlpha: 0.00000)
            )
        case .vermilion:
            GardenColorwayTokens(
                canvas: AdaptiveHex(0xF5EAE3, 0x231918),
                ink: AdaptiveHex(0x30211F, 0xFAECE6),
                card: AdaptiveHex(0xFFFAF6, 0x332321),
                action: AdaptiveHex(0xA3362B, 0xF0AD96),
                actionInk: AdaptiveHex(0xFFFFFF, 0x301910),
                secondary: AdaptiveHex(0xF1DCD1, 0x4D322C),
                secondaryInk: AdaptiveHex(0x6F2B23, 0xF4D5C7),
                muted: AdaptiveHex(0xEEE1DA, 0x3B2B28),
                mutedInk: AdaptiveHex(0x74574E, 0xD8B8AA),
                accent: AdaptiveHex(0xF4D6C8, 0x5B3830),
                accentInk: AdaptiveHex(0x792E22, 0xFCE3D8),
                edge: AdaptiveHex(0xE6CFC3, 0x604138),
                input: AdaptiveHex(0xC8A295, 0x92695A),
                chrome: AdaptiveHex(0xFFF6EF, 0x2B1D1B),
                logo: AdaptiveHex(0xB4523C, 0xB4523C),
                avatar: AdaptiveHex(0x965342, 0x965342),
                navStart: AdaptiveHex(0xF9E1D4, 0x59372D),
                navEnd: AdaptiveHex(0xEDC4B1, 0x653B2F),
                navInk: AdaptiveHex(0x762B20, 0xFFE4D5),
                ctaStart: AdaptiveHex(0xAC3C2E, 0xAC3C2E),
                ctaEnd: AdaptiveHex(0x792720, 0x792720),
                progress: AdaptiveHex(0xB34B36, 0xEAA58C),
                track: AdaptiveHex(0xECD2C5, 0x68463A),
                preview: AdaptiveHex(0xF4E2D4, 0x44302A),
                sceneBase: AdaptiveHex(0xFFF3E8, 0x30201B),
                sceneMobile: AdaptiveHex(0xFFF3E8, 0x30201B, lightAlpha: 0.92941, darkAlpha: 0.96078),
                sceneMobileMid: AdaptiveHex(0xFFE6D3, 0x30201B, lightAlpha: 0.73333, darkAlpha: 0.80784),
                sceneEnd: AdaptiveHex(0xB45530, 0x542C26, lightAlpha: 0.07843, darkAlpha: 0.23922),
                artWash: AdaptiveHex(0xBD6137, 0xBD6137, lightAlpha: 0.20000, darkAlpha: 0.20000)
            )
        case .blueHour:
            GardenColorwayTokens(
                canvas: AdaptiveHex(0xE8EEF8, 0x141C2B),
                ink: AdaptiveHex(0x172941, 0xE8EFFC),
                card: AdaptiveHex(0xF9FBFF, 0x202D43),
                action: AdaptiveHex(0x355D98, 0xADCAFA),
                actionInk: AdaptiveHex(0xFFFFFF, 0x15263F),
                secondary: AdaptiveHex(0xDCE5F5, 0x304363),
                secondaryInk: AdaptiveHex(0x294878, 0xD5E3FF),
                muted: AdaptiveHex(0xE0E7F2, 0x28364D),
                mutedInk: AdaptiveHex(0x506584, 0xAEBFDD),
                accent: AdaptiveHex(0xD5E1F7, 0x354B72),
                accentInk: AdaptiveHex(0x244A82, 0xE1EBFF),
                edge: AdaptiveHex(0xCBD8EC, 0x405478),
                input: AdaptiveHex(0x9BB1CF, 0x6B86B0),
                chrome: AdaptiveHex(0xF2F6FF, 0x1A2438),
                logo: AdaptiveHex(0x537BB5, 0x537BB5),
                avatar: AdaptiveHex(0x4E6994, 0x4E6994),
                navStart: AdaptiveHex(0xE0EAFF, 0x324D78),
                navEnd: AdaptiveHex(0xC8D8F5, 0x3A527F),
                navInk: AdaptiveHex(0x274B83, 0xE1ECFF),
                ctaStart: AdaptiveHex(0x365F9E, 0x365F9E),
                ctaEnd: AdaptiveHex(0x233E70, 0x233E70),
                progress: AdaptiveHex(0x4B70B3, 0xADCAFA),
                track: AdaptiveHex(0xCFDCF2, 0x435C83),
                preview: AdaptiveHex(0xE1E8F6, 0x2A3C58),
                sceneBase: AdaptiveHex(0xEEF3FF, 0x1A2842),
                sceneMobile: AdaptiveHex(0xEEF3FF, 0x1A2842, lightAlpha: 0.92941, darkAlpha: 0.96078),
                sceneMobileMid: AdaptiveHex(0xD8E5FF, 0x1A2842, lightAlpha: 0.73333, darkAlpha: 0.80784),
                sceneEnd: AdaptiveHex(0x4E71B5, 0x223F72, lightAlpha: 0.10196, darkAlpha: 0.23922),
                artWash: AdaptiveHex(0x5679BC, 0x5679BC, lightAlpha: 0.18039, darkAlpha: 0.18039)
            )
        }
    }
}
