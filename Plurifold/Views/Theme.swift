import SwiftUI
import UIKit

enum Palette {
    static let background = adaptive(0xF5F8EF, 0x14241B)
    static let surface = adaptive(0xFFFFFF, 0x203529)
    static let field = adaptive(0xD5E2CA, 0x304C39)
    static let ink = adaptive(0x294435, 0xD5E2CA)
    static let secondary = adaptive(0x52634F, 0xB0C1A8)
    static let line = adaptive(0xCCD8C4, 0x40563D)

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
            .foregroundStyle(Palette.background)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension View {
    func studyCard() -> some View {
        padding(20)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line, lineWidth: 1))
    }

    func studyBackground() -> some View {
        background(Palette.background.ignoresSafeArea())
            .foregroundStyle(Palette.ink)
            .toolbarBackground(Palette.background, for: .navigationBar)
    }
}
