import SwiftUI
import UIKit

/// Semantic tokens shared with the website's Original and Garden colorways. Computed
/// properties read observable appearance state in their caller's SwiftUI body.
/// Keep these as Color values so existing SwiftUI and UIKit readers share them.
enum Palette {
    static var revisionID: String { AppAppearance.shared.revisionID }
    static var isGarden: Bool { AppAppearance.shared.workspaceLayout == .garden }
    static var cardRadius: CGFloat { isGarden ? 22 : 4 }
    static var controlRadius: CGFloat { isGarden ? 15 : 4 }

    static var background: Color { color(\.canvas) }
    static var surface: Color { color(\.surface) }
    static var field: Color { color(\.secondary) }
    static var ink: Color { color(\.ink) }
    static var secondary: Color { color(\.muted) }
    static var line: Color { color(\.line) }
    static var accent: Color { color(\.action) }
    static var accentInk: Color { color(\.actionInk) }
    static var accentSoft: Color { isGarden ? gardenColor(\.secondary) : field }
    static var courseSurface: Color { color(\.course) }
    static var groupSurface: Color { color(\.group) }
    static var band: Color { color(\.band) }
    static var bandInk: Color { color(\.bandInk) }
    static var header: Color { color(\.masthead) }
    static var headerInk: Color { color(\.mastheadInk) }
    static var headerMuted: Color { color(\.mastheadMuted) }
    static var readingSurface: Color { surface }
    static var logo: Color { isGarden ? gardenColor(\.logo) : headerInk }
    static var avatar: Color { isGarden ? gardenColor(\.avatar) : accent }
    static var navInk: Color { isGarden ? gardenColor(\.navInk) : accent }
    static var progress: Color { isGarden ? gardenColor(\.progress) : accent }
    static var progressTrack: Color { isGarden ? gardenColor(\.track) : field }
    static var preview: Color { isGarden ? gardenColor(\.preview) : courseSurface }
    static var inputLine: Color { isGarden ? gardenColor(\.input) : line }
    static var sceneBase: Color { isGarden ? gardenColor(\.sceneBase) : background }
    static var sceneLeading: Color { isGarden ? gardenColor(\.sceneMobile) : background }
    static var sceneMiddle: Color { isGarden ? gardenColor(\.sceneMobileMid) : background.opacity(0.8) }
    static var sceneTrailing: Color { isGarden ? gardenColor(\.sceneEnd) : background.opacity(0.2) }
    static var artWash: Color { isGarden ? gardenColor(\.artWash) : .clear }
    static var welcomeBackground: Color {
        AppAppearance.shared.colorway == .verdant ? adaptive(0xE5F1DF, 0x14261C) : background
    }
    static var welcomeGlow: Color {
        AppAppearance.shared.colorway == .verdant ? adaptive(0xF1F9EA, 0x294731) : header
    }
    static var welcomeInk: Color {
        AppAppearance.shared.colorway == .verdant ? adaptive(0x122C1B, 0xE1F1DC) : ink
    }
    static var welcomeMuted: Color {
        AppAppearance.shared.colorway == .verdant ? adaptive(0x4F6E54, 0xADC6A7) : secondary
    }
    static var navGradient: LinearGradient {
        LinearGradient(colors: isGarden ? [gardenColor(\.navStart), gardenColor(\.navEnd)] : [field, field],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var actionGradient: LinearGradient {
        LinearGradient(colors: isGarden ? [gardenColor(\.ctaStart), gardenColor(\.ctaEnd)] : [accent, accent],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    /// The photographic CTA uses a dark gradient in both lighting modes.
    static var actionGradientInk: Color { isGarden ? .white : accentInk }

    // Feedback and learning status retain their meaning across colorways.
    static var green: Color { adaptive(0x365B40, 0xB8D79F) }
    static var warm: Color { adaptive(0xB48A2C, 0xF2CF7E) }
    static var uiToken: UIColor { adaptiveUIColor(0xA1D4E3, 0x61B3C9, lightAlpha: 0.52, darkAlpha: 0.20) }
    static var uiSavedToken: UIColor { adaptiveUIColor(0xFABF45, 0xCC942E, lightAlpha: 0.65, darkAlpha: 0.42) }
    static var uiSelectedToken: UIColor { adaptiveUIColor(0x87C2E6, 0x4587AD) }

    private static func color(_ keyPath: KeyPath<ColorwayTokens, AdaptiveHex>) -> Color {
        let appearance = AppAppearance.shared
        let values = ColorwayTokens.values(for: appearance.colorway, layout: appearance.workspaceLayout)[keyPath: keyPath]
        return resolved(values)
    }

    private static func gardenColor(_ keyPath: KeyPath<GardenColorwayTokens, AdaptiveHex>) -> Color {
        resolved(GardenColorwayTokens.values(for: AppAppearance.shared.colorway)[keyPath: keyPath])
    }

    private static func resolved(_ values: AdaptiveHex) -> Color {
        Color(adaptiveUIColor(values.light, values.dark,
                              lightAlpha: values.lightAlpha, darkAlpha: values.darkAlpha))
    }

    private static func adaptive(_ light: UInt, _ dark: UInt) -> Color {
        Color(adaptiveUIColor(light, dark))
    }

    private static func adaptiveUIColor(_ light: UInt, _ dark: UInt,
                                        lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> UIColor {
        // Capture this selection now so a new color replaces an old color when
        // Observation invalidates its view. System appearance stays trait-driven.
        let lighting = AppAppearance.shared.lighting
        return UIColor { traits in
            let isDark = lighting == .dark || (lighting == .system && traits.userInterfaceStyle == .dark)
            let value = isDark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255,
                           alpha: isDark ? darkAlpha : lightAlpha)
        }
    }
}

struct AdaptiveHex {
    let light: UInt
    let dark: UInt
    let lightAlpha: CGFloat
    let darkAlpha: CGFloat

    init(_ light: UInt, _ dark: UInt? = nil, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) {
        self.light = light
        self.dark = dark ?? light
        self.lightAlpha = lightAlpha
        self.darkAlpha = darkAlpha
    }
}

struct ColorwayTokens {
    let canvas: AdaptiveHex
    let surface: AdaptiveHex
    let secondary: AdaptiveHex
    let ink: AdaptiveHex
    let muted: AdaptiveHex
    let line: AdaptiveHex
    let action: AdaptiveHex
    let actionInk: AdaptiveHex
    let course: AdaptiveHex
    let group: AdaptiveHex
    let band: AdaptiveHex
    let bandInk: AdaptiveHex
    let masthead: AdaptiveHex
    let mastheadInk: AdaptiveHex
    let mastheadMuted: AdaptiveHex

    static func values(for colorway: AppColorway, layout: AppWorkspaceLayout = .original) -> ColorwayTokens {
        if layout == .garden {
            let garden = GardenColorwayTokens.values(for: colorway)
            return ColorwayTokens(canvas: garden.canvas, surface: garden.card, secondary: garden.muted,
                                  ink: garden.ink, muted: garden.mutedInk, line: garden.edge,
                                  action: garden.action, actionInk: garden.actionInk,
                                  course: garden.preview, group: garden.secondary,
                                  band: garden.secondary, bandInk: garden.secondaryInk,
                                  masthead: garden.chrome, mastheadInk: garden.ink, mastheadMuted: garden.mutedInk)
        }
        return switch colorway {
        case .verdant:
            ColorwayTokens(
                canvas: AdaptiveHex(0xD5E2CA, 0x152119),
                surface: AdaptiveHex(0xF5F8EF, 0x24352A),
                secondary: AdaptiveHex(0xCBDCBF, 0x334D3B),
                ink: AdaptiveHex(0x243B2C, 0xEDF3E5),
                muted: AdaptiveHex(0x4B5E46, 0xBDCFB5),
                line: AdaptiveHex(0x849B79, 0x678164),
                action: AdaptiveHex(0x365B40, 0xB8D79F),
                actionInk: AdaptiveHex(0xFCFFF6, 0x172317),
                course: AdaptiveHex(0xC8DAB9, 0x2D4433),
                group: AdaptiveHex(0xE3EBDC, 0x1B2B20),
                band: AdaptiveHex(0x35563E, 0x395443),
                bandInk: AdaptiveHex(0xF3F8EB),
                masthead: AdaptiveHex(0x294435, 0x162B20),
                mastheadInk: AdaptiveHex(0xF0F6E8),
                mastheadMuted: AdaptiveHex(0xD0DFC8, 0xC2D6BD)
            )
        case .vermilion:
            ColorwayTokens(
                canvas: AdaptiveHex(0xE3D7C5, 0x211917),
                surface: AdaptiveHex(0xFCF5E8, 0x322622),
                secondary: AdaptiveHex(0xDBC6B0, 0x4E3830),
                ink: AdaptiveHex(0x282321, 0xF7EDDB),
                muted: AdaptiveHex(0x6E574A, 0xD7BCAA),
                line: AdaptiveHex(0xAA8875, 0xA27C63),
                action: AdaptiveHex(0x9F322B, 0xF0AD8D),
                actionInk: AdaptiveHex(0xFFF7E8, 0x2B1B14),
                course: AdaptiveHex(0xEDD7C1, 0x493127),
                group: AdaptiveHex(0xE9DDCC, 0x2A1E1B),
                band: AdaptiveHex(0x963029, 0x682D26),
                bandInk: AdaptiveHex(0xFFF2DC),
                masthead: AdaptiveHex(0xA22F29, 0x68231F),
                mastheadInk: AdaptiveHex(0xFFF2DC),
                mastheadMuted: AdaptiveHex(0xF1D7BD, 0xEEC4AA)
            )
        case .blueHour:
            ColorwayTokens(
                canvas: AdaptiveHex(0xD3DFE9, 0x17212C),
                surface: AdaptiveHex(0xF4F8FC, 0x263646),
                secondary: AdaptiveHex(0xC6D5E2, 0x364E65),
                ink: AdaptiveHex(0x1E3449, 0xEDF3FB),
                muted: AdaptiveHex(0x4B5E70, 0xBBCCDE),
                line: AdaptiveHex(0x8199AE, 0x7592AE),
                action: AdaptiveHex(0x304F76, 0xB3CDEE),
                actionInk: AdaptiveHex(0xF6F9FF, 0x192A40),
                course: AdaptiveHex(0xC7D9E9, 0x2C435A),
                group: AdaptiveHex(0xDFE8F0, 0x1D2B39),
                band: AdaptiveHex(0x304E70, 0x334F70),
                bandInk: AdaptiveHex(0xF1F6FF),
                masthead: AdaptiveHex(0x263E5C, 0x192C44),
                mastheadInk: AdaptiveHex(0xF1F6FF),
                mastheadMuted: AdaptiveHex(0xC8D8E9, 0xC2D5EB)
            )
        }
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(StudyTypography.font(.caption, weight: .medium))
            .tracking(1.5)
            .foregroundStyle(Palette.secondary)
    }
}

struct Wordmark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 2) {
            Text("plurifold").font(StudyTypography.font(.title2, weight: .semibold))
            TimelineView(.periodic(from: .now, by: 0.8)) { context in
                RoundedRectangle(cornerRadius: Palette.isGarden ? 2 : 0)
                    .fill(Palette.isGarden ? Palette.logo : Palette.ink)
                    .frame(width: 9, height: 21)
                    .opacity(reduceMotion || Int(context.date.timeIntervalSince1970 / 0.8) % 2 == 0 ? 1 : 0)
            }
            .accessibilityHidden(true)
        }
        .foregroundStyle(Palette.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Plurifold")
    }
}

struct StudyButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 16)
            .foregroundStyle(Palette.accentInk)
            .background(Palette.accent, in: RoundedRectangle(cornerRadius: Palette.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Palette.controlRadius, style: .continuous)
                    .strokeBorder(.white.opacity(Palette.isGarden ? 0.1 : 0), lineWidth: 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.86 : 1) : 0.46)
            .scaleEffect(configuration.isPressed && !reduceMotion && Palette.isGarden ? 0.98 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.76), value: configuration.isPressed)
    }
}

extension View {
    func studyCard() -> some View {
        modifier(GardenCardModifier(padding: 20))
    }

    /// One frame for the complete text, leaving paragraph breaks continuous.
    /// Only the empty padding responds here; the text owns its word gestures.
    func readingPanel(onBackgroundTap: @escaping () -> Void) -> some View {
        padding(18)
            .background {
                RoundedRectangle(cornerRadius: Palette.isGarden ? 18 : 4, style: .continuous)
                    .fill(Palette.readingSurface)
                    .onTapGesture(perform: onBackgroundTap)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Palette.isGarden ? 18 : 4, style: .continuous).stroke(Palette.line, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }

    func studyBackground() -> some View {
        background(Palette.background.ignoresSafeArea())
            .foregroundStyle(Palette.ink)
            .toolbarBackground(Palette.background, for: .navigationBar)
    }
}
