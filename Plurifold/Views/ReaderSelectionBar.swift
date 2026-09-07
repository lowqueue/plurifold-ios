import SwiftUI
import UIKit

/// A compact cue anchored to highlighted words. The text view's recognizer owns
/// the pull, sharing the same distance-based rules for the cue and selected text.
@MainActor
final class ReaderSelectionBar: UIView {
    var onOpen: (() -> Void)?
    private let label = UILabel()
    private let arrow = UIImageView(image: UIImage(systemName: "arrow.down"))
    private let progressTrack = UIView()
    private var progress: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(Palette.accent)
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 5
        layer.shadowOffset = CGSize(width: 0, height: 2)
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.textColor = UIColor(Palette.accentInk)
        arrow.tintColor = UIColor(Palette.accentInk)
        arrow.contentMode = .scaleAspectFit
        progressTrack.backgroundColor = UIColor(Palette.warm)
        progressTrack.layer.cornerRadius = 1.5
        [arrow, label, progressTrack].forEach(addSubview)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "Open word details"
        accessibilityHint = "Shows dictionary meanings. AI explanations are optional."
        update(progress: 0, canOpen: true)
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    func update(progress: CGFloat, canOpen: Bool) {
        self.progress = min(1, max(0, progress))
        label.text = !canOpen ? "Select a shorter phrase" : progress >= 1 ? "Release for details" : "Pull down for details"
        arrow.image = UIImage(systemName: progress >= 1 ? "checkmark" : "arrow.down")
        alpha = canOpen ? 1 : 0.8
        layer.borderColor = UIColor(Palette.line).cgColor
        accessibilityTraits = canOpen ? .button : [.button, .notEnabled]
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        arrow.frame = CGRect(x: 12, y: 11, width: 18, height: bounds.height - 22)
        label.frame = CGRect(x: 38, y: 5, width: max(0, bounds.width - 50), height: bounds.height - 10)
        progressTrack.frame = CGRect(x: 12, y: bounds.height - 5,
                                     width: max(0, bounds.width - 24) * progress, height: 3)
    }

    override func accessibilityActivate() -> Bool {
        guard !accessibilityTraits.contains(.notEnabled) else { return false }
        onOpen?()
        return true
    }
}
