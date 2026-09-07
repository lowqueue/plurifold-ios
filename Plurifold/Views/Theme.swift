import SwiftUI
import UIKit

enum Palette {
    // Plurifold's website Blue Hour colorway, with its green and gold accents.
    // Light and dark values follow app/colorways.css in the website source.
    static let background = adaptive(0xD3DFE9, 0x17212C)
    static let surface = adaptive(0xF4F8FC, 0x263646)
    static let field = adaptive(0xC6D5E2, 0x364E65)
    static let ink = adaptive(0x1E3449, 0xEDF3FB)
    static let secondary = adaptive(0x4B5E70, 0xBBCCDE)
    static let line = adaptive(0x8199AE, 0x7592AE)
    static let accent = adaptive(0x304F76, 0xB3CDEE)
    static let accentInk = adaptive(0xF6F9FF, 0x192A40)
    static let accentSoft = field
    static let courseSurface = adaptive(0xC7D9E9, 0x2C435A)
    static let green = adaptive(0x365B40, 0xB8D79F)
    static let warm = adaptive(0xB48A2C, 0xF2CF7E)
    static let readingSurface = surface

    private static func adaptive(_ light: UInt, _ dark: UInt) -> Color {
        Color(UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255,
                alpha: 1
            )
        })
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.monospaced().weight(.medium))
            .tracking(1.5)
            .foregroundStyle(Palette.secondary)
    }
}

struct Wordmark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 2) {
            Text("plurifold").font(.title2.monospaced().weight(.semibold))
            TimelineView(.periodic(from: .now, by: 0.8)) { context in
                Text("_")
                    .font(.title2.monospaced().weight(.semibold))
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 16)
            .foregroundStyle(Palette.accentInk)
            .background(Palette.accent, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension View {
    func studyCard() -> some View {
        padding(20)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }

    /// One frame for the complete text, leaving paragraph breaks continuous.
    /// Only the empty padding responds here; the text owns its word gestures.
    func readingPanel(onBackgroundTap: @escaping () -> Void) -> some View {
        padding(18)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Palette.readingSurface)
                    .onTapGesture(perform: onBackgroundTap)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
    }

    func studyBackground() -> some View {
        background(Palette.background.ignoresSafeArea())
            .foregroundStyle(Palette.ink)
            .toolbarBackground(Palette.background, for: .navigationBar)
    }
}
