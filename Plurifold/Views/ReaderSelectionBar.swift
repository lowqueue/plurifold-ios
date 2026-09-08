import SwiftUI
import UIKit

/// A nearby details button for one word, or a clear limit notice for a long
/// selection. Phrases open automatically after the selection gesture finishes.
@MainActor
final class ReaderSelectionBar: UIView {
    var onOpen: (() -> Void)?
    private let label = UILabel()
    private let icon = UIImageView(image: UIImage(systemName: "text.magnifyingglass"))

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
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.textColor = UIColor(Palette.accentInk)
        icon.tintColor = UIColor(Palette.accentInk)
        icon.contentMode = .scaleAspectFit
        [icon, label].forEach(addSubview)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "Open word details"
        accessibilityHint = "Shows dictionary meanings. AI explanations are optional."
        update(notice: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    func update(notice: String?) {
        label.text = notice ?? "Word details"
        icon.image = UIImage(systemName: notice == nil ? "text.magnifyingglass" : "text.badge.minus")
        layer.borderColor = UIColor(Palette.line).cgColor
        accessibilityTraits = notice == nil ? .button : [.staticText, .notEnabled]
        accessibilityLabel = notice ?? "Open word details"
        accessibilityHint = notice == nil ? "Shows dictionary meanings. AI explanations are optional." : nil
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        icon.frame = CGRect(x: 12, y: 11, width: 18, height: bounds.height - 22)
        label.frame = CGRect(x: 38, y: 5, width: max(0, bounds.width - 50), height: bounds.height - 10)
    }

    override func accessibilityActivate() -> Bool {
        guard !accessibilityTraits.contains(.notEnabled) else { return false }
        onOpen?()
        return true
    }
}
