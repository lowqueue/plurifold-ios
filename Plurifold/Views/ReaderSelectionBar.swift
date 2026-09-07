import SwiftUI

struct ReaderSelectionBar: View {
    let selection: PassageSelection
    let onExplain: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(selection.text)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Selected: \(selection.text)")
                Button("Explain", action: onExplain)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.ink)
                    .foregroundStyle(Palette.background)
                    .disabled(selection.text.utf16.count > 800)
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3).frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Clear selection")
            }
            if selection.text.utf16.count > 800 {
                Text("Select a shorter phrase to explain it.")
                    .font(.caption).foregroundStyle(Palette.secondary)
            }
        }
        .foregroundStyle(Palette.ink)
    }
}
