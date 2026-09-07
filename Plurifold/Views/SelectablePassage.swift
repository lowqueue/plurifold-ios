import NaturalLanguage
import SwiftUI
import UIKit

/// Ranges use UTF-16 offsets, matching UITextView and NSAttributedString.
struct PassageSelection: Identifiable {
    let id = UUID()
    let text: String
    let context: String
    let range: NSRange

    init?(context: String, range: NSRange) {
        let count = context.utf16.count
        guard range.location != NSNotFound, range.location >= 0,
              range.length > 0, range.location <= count,
              range.length <= count - range.location else { return nil }
        // Range conversion alone can accept an offset inside a surrogate pair,
        // then Swift's substring expands it to the whole visible character.
        // Require whole characters so the text and stored UTF-16 range agree.
        guard (context as NSString).rangeOfComposedCharacterSequences(for: range) == range,
              let indices = Range(range, in: context) else { return nil }
        let selected = String(context[indices])
        guard !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        self.text = selected
        self.context = context
        self.range = range
    }
}

/// Native selection remains available for every word, including words without a saved highlight.
/// A tap studies one word. A long press exposes the system handles and an explicit phrase action.
@MainActor
struct SelectablePassage: UIViewRepresentable {
    let text: String
    var highlights: [String] = []
    let onSelect: (PassageSelection) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PassageTextView {
        let view = PassageTextView()
        view.delegate = context.coordinator
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = true
        view.dataDetectorTypes = []
        view.tintColor = UIColor(Palette.ink)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultHigh, for: .vertical)
        view.accessibilityHint = "Select a word or phrase, then choose Explain selection to study it."

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didTapWord(_:)))
        tap.delegate = context.coordinator
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        // Let the text view's double/triple taps establish native selection first.
        for case let nativeTap as UITapGestureRecognizer in view.gestureRecognizers ?? [] {
            if nativeTap.numberOfTapsRequired > 1 { tap.require(toFail: nativeTap) }
        }
        view.addGestureRecognizer(tap)
        context.coordinator.textView = view
        view.onTypographyChange = { [weak coordinator = context.coordinator] view in
            coordinator?.updateAppearance(of: view)
        }
        context.coordinator.updateAppearance(of: view)
        return view
    }

    func updateUIView(_ uiView: PassageTextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateAppearance(of: uiView)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PassageTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let measured = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(measured.height))
    }

    static func dismantleUIView(_ uiView: PassageTextView, coordinator: Coordinator) {
        uiView.delegate = nil
        uiView.onTypographyChange = nil
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: SelectablePassage
        weak var textView: PassageTextView?
        private var renderedHighlights: [String] = []
        private var renderedFont: UIFont?

        init(_ parent: SelectablePassage) { self.parent = parent }

        func updateAppearance(of view: PassageTextView) {
            let font = UIFont.preferredFont(forTextStyle: .title3, compatibleWith: view.traitCollection)
            let textChanged = view.text != parent.text
            guard textChanged || renderedHighlights != parent.highlights || renderedFont != font else { return }

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 5
            paragraph.baseWritingDirection = .natural
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(Palette.ink),
                .paragraphStyle: paragraph
            ]
            let selection = view.selectedRange
            view.textStorage.beginEditing()
            if textChanged {
                view.textStorage.setAttributedString(NSAttributedString(string: parent.text, attributes: attributes))
            } else {
                // Attribute-only updates preserve the text and the user's selection handles.
                view.textStorage.setAttributes(attributes, range: NSRange(location: 0, length: view.textStorage.length))
            }
            for range in PassageTextSelection.highlightRanges(in: parent.text, terms: parent.highlights) {
                view.textStorage.addAttributes([
                    .backgroundColor: UIColor(Palette.field),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: UIColor(Palette.secondary)
                ], range: range)
            }
            view.textStorage.endEditing()
            if textChanged {
                view.selectedRange = NSRange(location: 0, length: 0)
            } else if view.selectedRange != selection {
                view.selectedRange = selection
            }
            renderedHighlights = parent.highlights
            renderedFont = font
            view.invalidateIntrinsicContentSize()
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let view = textView, !UIAccessibility.isVoiceOverRunning else { return false }
            // Tapping a selection handle or an existing native selection must not open a sheet.
            return !(view.isFirstResponder && view.selectedRange.length > 0)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Keep native tap behavior; leave long presses and scrolling in charge of their gestures.
            gestureRecognizer is UITapGestureRecognizer && otherGestureRecognizer is UITapGestureRecognizer
        }

        @objc func didTapWord(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let view = textView else { return }
            let point = recognizer.location(in: view)
            guard let character = view.characterRange(at: point),
                  view.selectionRects(for: character).contains(where: { $0.rect.insetBy(dx: -1, dy: 0).contains(point) })
            else { return }
            let offset = view.offset(from: view.beginningOfDocument, to: character.start)
            guard let range = PassageTextSelection.wordRange(in: parent.text, utf16Offset: offset),
                  let selected = PassageSelection(context: parent.text, range: range) else { return }
            view.selectedRange = range
            view.resignFirstResponder()
            parent.onSelect(selected)
        }

        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange,
                      suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard let selection = PassageSelection(context: textView.text ?? "", range: range) else {
                return UIMenu(children: suggestedActions)
            }
            let explain = UIAction(title: "Explain selection", image: UIImage(systemName: "text.magnifyingglass")) {
                [weak self] _ in
                guard let self, self.parent.text == selection.context else { return }
                self.parent.onSelect(selection)
            }
            return UIMenu(children: [explain] + suggestedActions)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // Moving handles never triggers a lookup or an API call.
            textView.accessibilityCustomActions = textView.selectedRange.length > 0 ? [
                UIAccessibilityCustomAction(name: "Explain selection", target: self,
                                            selector: #selector(explainAccessibleSelection))
            ] : []
        }

        @objc private func explainAccessibleSelection() -> Bool {
            guard let view = textView,
                  let selection = PassageSelection(context: view.text ?? "", range: view.selectedRange) else { return false }
            parent.onSelect(selection)
            return true
        }
    }
}

final class PassageTextView: UITextView {
    var onTypographyChange: ((PassageTextView) -> Void)?

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            onTypographyChange?(self)
        }
    }
}

enum PassageTextSelection {
    static func wordRange(in text: String, utf16Offset: Int) -> NSRange? {
        guard utf16Offset >= 0, utf16Offset < text.utf16.count,
              let position = Range(NSRange(location: utf16Offset, length: 0), in: text)?.lowerBound else { return nil }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        let range = tokenizer.tokenRange(at: position)
        guard range.contains(position),
              text[range].unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) else { return nil }
        return NSRange(range, in: text)
    }

    static func highlightRanges(in text: String, terms: [String]) -> [NSRange] {
        guard !text.isEmpty, !terms.isEmpty else { return [] }
        // Token boundaries prevent saved "in" from highlighting the middle of "morning".
        // NaturalLanguage also provides boundaries in scripts without spaces.
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var starts = Set<String.Index>()
        var ends = Set<String.Index>()
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            starts.insert(range.lowerBound)
            ends.insert(range.upperBound)
            return true
        }
        var matches: [NSRange] = []
        for term in Set(terms.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }).sorted() where !term.isEmpty {
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let match = text.range(of: term, options: [.caseInsensitive], range: searchStart..<text.endIndex) {
                if starts.contains(match.lowerBound), ends.contains(match.upperBound) {
                    matches.append(NSRange(match, in: text))
                }
                searchStart = match.upperBound
            }
        }
        return matches
    }
}
