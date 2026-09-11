import SwiftUI

/// Dynamic Type stays system-driven. Only the optional Original layout uses
/// the terminal typeface; pronunciation and code-like text can still opt in.
enum StudyTypography {
    static func font(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: Palette.isGarden ? .default : .monospaced).weight(weight)
    }
}

struct GardenCardModifier: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Palette.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Palette.cardRadius, style: .continuous)
                    .strokeBorder(Palette.line, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: Palette.ink.opacity(Palette.isGarden ? 0.035 : 0), radius: 12, x: 0, y: 4)
    }
}

/// Press feedback works with native Buttons and NavigationLinks, leaving their
/// cancellation, scrolling, accessibility, and activation semantics intact.
struct GardenPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed && !reduceMotion && Palette.isGarden ? 0.985 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.46)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

/// A bounded decorative background for a card or header. The same scene assets
/// as the website are washed by the selected colorway, including in dark mode.
/// Add with .background { GardenSceneBackground(asset: "GardenSession") }.
struct GardenSceneBackground: View {
    let asset: String
    var alignment: Alignment = .trailing
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Palette.sceneBase
                if Palette.isGarden && !reduceTransparency {
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignment)
                        .clipped()
                    Palette.artWash
                    LinearGradient(stops: [
                        .init(color: Palette.sceneLeading, location: 0),
                        .init(color: Palette.sceneMiddle, location: 0.6),
                        .init(color: Palette.sceneTrailing, location: 1)
                    ], startPoint: .leading, endPoint: .trailing)
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

extension View {
    func gardenCard(padding: CGFloat = 20) -> some View {
        modifier(GardenCardModifier(padding: padding))
    }
}
