import SwiftUI

/// The exact vectors from design/AppIcon.svg, with only the empty outer canvas cropped.
/// SwiftUI renders the supplied SVG geometry directly so the cursor can blink natively.
struct PlurifoldLogo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var cursorVisible = true

    private var shouldBlink: Bool { !reduceMotion && scenePhase == .active }

    var body: some View {
        ZStack {
            PlurifoldLogoLetter().fill(style: FillStyle(eoFill: true))
            PlurifoldLogoCursor().opacity(cursorVisible || !shouldBlink ? 1 : 0)
        }
        .aspectRatio(330.0 / 234.0, contentMode: .fit)
        .foregroundStyle(Palette.headerInk)
        .accessibilityHidden(true)
        // Match the SVG's step-end animation, including when a parent animates.
        .transaction { $0.animation = nil }
        .task(id: shouldBlink) {
            cursorVisible = true
            guard shouldBlink else { return }
            do {
                while !Task.isCancelled {
                    // Original SVG: 1.2 seconds, visible for 65%, hidden for 35%.
                    try await Task.sleep(nanoseconds: 780_000_000)
                    cursorVisible = false
                    try await Task.sleep(nanoseconds: 420_000_000)
                    cursorVisible = true
                }
            } catch {
                // SwiftUI cancels the task on disappearance, inactivity, or Reduce Motion.
                cursorVisible = true
            }
        }
    }
}

private enum PlurifoldLogoGeometry {
    static func transform(in rect: CGRect) -> CGAffineTransform {
        let scale = min(rect.width / 330, rect.height / 234)
        // Cropping after the SVG's translate(-13 -2) is equivalent to cropping
        // these original coordinates at (104, 140), preserving every curve.
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                 tx: rect.midX - 269 * scale,
                                 ty: rect.midY - 257 * scale)
    }
}

private struct PlurifoldLogoLetter: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 104, y: 146))
        path.addLine(to: CGPoint(x: 148, y: 146))
        path.addLine(to: CGPoint(x: 148, y: 162))
        path.addCurve(to: CGPoint(x: 204, y: 142), control1: CGPoint(x: 163, y: 149), control2: CGPoint(x: 182, y: 142))
        path.addCurve(to: CGPoint(x: 290, y: 228), control1: CGPoint(x: 254, y: 142), control2: CGPoint(x: 290, y: 178))
        path.addCurve(to: CGPoint(x: 204, y: 314), control1: CGPoint(x: 290, y: 278), control2: CGPoint(x: 254, y: 314))
        path.addCurve(to: CGPoint(x: 148, y: 295), control1: CGPoint(x: 182, y: 314), control2: CGPoint(x: 164, y: 308))
        path.addLine(to: CGPoint(x: 148, y: 374))
        path.addLine(to: CGPoint(x: 104, y: 374))
        path.closeSubpath()
        path.move(to: CGPoint(x: 148, y: 228))
        path.addCurve(to: CGPoint(x: 197, y: 274), control1: CGPoint(x: 148, y: 256), control2: CGPoint(x: 168, y: 274))
        path.addCurve(to: CGPoint(x: 246, y: 228), control1: CGPoint(x: 225, y: 274), control2: CGPoint(x: 246, y: 255))
        path.addCurve(to: CGPoint(x: 197, y: 182), control1: CGPoint(x: 246, y: 201), control2: CGPoint(x: 225, y: 182))
        path.addCurve(to: CGPoint(x: 148, y: 228), control1: CGPoint(x: 168, y: 182), control2: CGPoint(x: 148, y: 200))
        path.closeSubpath()
        return path.applying(PlurifoldLogoGeometry.transform(in: rect))
    }
}

private struct PlurifoldLogoCursor: Shape {
    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: 312, y: 140, width: 122, height: 234))
            .applying(PlurifoldLogoGeometry.transform(in: rect))
    }
}
