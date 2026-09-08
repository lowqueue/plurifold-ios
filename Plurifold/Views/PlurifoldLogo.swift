import SwiftUI

/// Native rendering of the website's terminal wordmark and trailing block cursor.
struct PlurifoldLogo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .title3) private var wordmarkSize: CGFloat = 23
    @State private var cursorVisible = true

    private var shouldBlink: Bool { !reduceMotion && scenePhase == .active }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: wordmarkSize * 0.2) {
            Text("plurifold")
                .font(.system(size: wordmarkSize, weight: .regular, design: .monospaced))
                .tracking(wordmarkSize * -0.07)
                .lineLimit(1)
            Rectangle()
                .frame(width: wordmarkSize * 0.47, height: wordmarkSize * 0.88)
                .offset(y: wordmarkSize * 0.09)
                .opacity(cursorVisible || !shouldBlink ? 1 : 0)
        }
        .foregroundStyle(Palette.headerInk)
        .accessibilityHidden(true)
        // Keep the cursor's space reserved while matching the website's step-end blink.
        .transaction { $0.animation = nil }
        .task(id: shouldBlink) {
            cursorVisible = true
            guard shouldBlink else { return }
            do {
                while !Task.isCancelled {
                    // Website: 1.1 seconds, visible until the 49% keyframe.
                    try await Task.sleep(nanoseconds: 539_000_000)
                    cursorVisible = false
                    try await Task.sleep(nanoseconds: 561_000_000)
                    cursorVisible = true
                }
            } catch {
                // SwiftUI cancels the task on disappearance, inactivity, or Reduce Motion.
                cursorVisible = true
            }
        }
    }
}
