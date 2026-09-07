import NaturalLanguage
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

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
        // UTF-16 ranges must contain complete visible characters, including
        // accents, variation selectors, surrogate pairs, and joined emoji.
        guard (context as NSString).rangeOfComposedCharacterSequences(for: range) == range,
              let indices = Range(range, in: context) else { return nil }
        let selected = String(context[indices])
        guard !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        text = selected
        self.context = context
        self.range = range
    }
}

/// A continuous reading surface. Touch selection is independent of UIKit's
/// delayed long-press handles; VoiceOver retains the native text selection tools.
@MainActor
struct SelectablePassage: UIViewRepresentable {
    let text: String
    var highlights: [String] = []
    var selectionMode = false
    var languageCode = ""
    var scrollRequest: ReaderScrollRequest? = nil
    var onReadingOffsetChange: (Int) -> Void = { _ in }
    let onSelect: (PassageSelection) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PassageTextView {
        let view = PassageTextView()
        let coordinator = context.coordinator
        coordinator.textView = view
        view.delegate = coordinator
        view.isEditable = false
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = true
        view.dataDetectorTypes = []
        view.tintColor = UIColor(Palette.ink)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultHigh, for: .vertical)

        let gesture = WordDragGestureRecognizer()
        gesture.delegate = coordinator
        gesture.cancelsTouchesInView = true
        gesture.delaysTouchesBegan = false
        gesture.delaysTouchesEnded = false
        gesture.addTarget(coordinator, action: #selector(Coordinator.selectionGestureChanged(_:)))
        gesture.onTouchBegan = { [weak coordinator] point in coordinator?.beginSelection(at: point) ?? false }
        gesture.onTouchMoved = { [weak coordinator] point in coordinator?.moveSelection(to: point) }
        gesture.onTouchEnded = { [weak coordinator] in coordinator?.finishSelection() }
        gesture.onTouchCancelled = { [weak coordinator] in coordinator?.cancelSelection() }
        view.addGestureRecognizer(gesture)
        coordinator.selectionGesture = gesture
        view.onTypographyChange = { [weak coordinator] view in coordinator?.updateAppearance(of: view) }
        view.onGeometryChange = { [weak coordinator] in coordinator?.scheduleGeometryUpdate() }
        view.onWindowRemoved = { [weak coordinator] in coordinator?.suspend() }
        coordinator.startObservingAccessibility()
        coordinator.updateAppearance(of: view)
        coordinator.updateInteraction()
        return view
    }

    func updateUIView(_ view: PassageTextView, context: Context) {
        let coordinator = context.coordinator
        let modeChanged = coordinator.parent.selectionMode != selectionMode
        coordinator.parent = self
        if modeChanged { coordinator.selectionGesture?.cancelTracking() }
        coordinator.updateAppearance(of: view)
        coordinator.updateInteraction()
        coordinator.scheduleGeometryUpdate()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PassageTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let measured = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(measured.height))
    }

    static func dismantleUIView(_ view: PassageTextView, coordinator: Coordinator) {
        coordinator.teardown()
        view.delegate = nil
        view.onTypographyChange = nil
        view.onGeometryChange = nil
        view.onWindowRemoved = nil
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: SelectablePassage
        weak var textView: PassageTextView?
        weak var selectionGesture: WordDragGestureRecognizer?
        private weak var readerScrollView: UIScrollView?
        private var scrollObservation: NSKeyValueObservation?
        private var accessibilityObserver: NSObjectProtocol?
        private var applicationObserver: NSObjectProtocol?
        private var renderedHighlights: [String] = []
        private var renderedFont: UIFont?
        private var renderedLanguage = ""
        private var wordRanges: [NSRange] = []
        private var savedRanges: [NSRange] = []
        private var activeRange: NSRange?
        private var anchorRange: NSRange?
        private var pointerInWindow: CGPoint?
        private var displayLink: CADisplayLink?
        private var geometryUpdateScheduled = false
        private var readingOffsetScheduled = false
        private var lastReadingOffset: Int?
        private var appliedScrollRequest: UUID?
        private var isTornDown = false

        init(_ parent: SelectablePassage) { self.parent = parent }

        func updateAppearance(of view: PassageTextView) {
            let font = UIFont.preferredFont(forTextStyle: .title3, compatibleWith: view.traitCollection)
            let textChanged = view.text != parent.text
            let fontChanged = renderedFont != font
            let wordsChanged = textChanged || renderedLanguage != parent.languageCode
            let highlightsChanged = textChanged || renderedHighlights != parent.highlights
            guard textChanged || fontChanged || wordsChanged || highlightsChanged else { return }
            if textChanged {
                selectionGesture?.cancelTracking()
                anchorRange = nil
                activeRange = nil
                lastReadingOffset = nil
                appliedScrollRequest = nil
            }
            if wordsChanged {
                wordRanges = PassageTextSelection.wordRanges(in: parent.text, languageCode: parent.languageCode)
            }
            if highlightsChanged {
                savedRanges = PassageTextSelection.highlightRanges(in: parent.text, terms: parent.highlights)
            }
            if textChanged || fontChanged {
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineSpacing = 5
                paragraph.baseWritingDirection = .natural
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font, .foregroundColor: UIColor(Palette.ink), .paragraphStyle: paragraph
                ]
                let selection = view.selectedRange
                view.textStorage.beginEditing()
                if textChanged {
                    view.textStorage.setAttributedString(NSAttributedString(string: parent.text, attributes: attributes))
                } else {
                    view.textStorage.setAttributes(attributes, range: NSRange(location: 0, length: view.textStorage.length))
                }
                view.textStorage.endEditing()
                if !textChanged && view.isSelectable { view.selectedRange = selection }
                view.invalidateIntrinsicContentSize()
            }
            redrawHighlights()
            renderedHighlights = parent.highlights
            renderedFont = font
            renderedLanguage = parent.languageCode
        }

        private func redrawHighlights(in changedRange: NSRange? = nil) {
            guard let view = textView else { return }
            let dirty = changedRange ?? NSRange(location: 0, length: view.textStorage.length)
            guard dirty.length > 0 else { return }
            view.textStorage.beginEditing()
            view.textStorage.removeAttribute(.backgroundColor, range: dirty)
            for range in savedRanges {
                let overlap = NSIntersectionRange(range, dirty)
                if overlap.length > 0 {
                    view.textStorage.addAttribute(.backgroundColor, value: UIColor(Palette.field), range: overlap)
                }
            }
            if let activeRange {
                let overlap = NSIntersectionRange(activeRange, dirty)
                if overlap.length > 0 {
                    view.textStorage.addAttribute(.backgroundColor, value: UIColor(Palette.secondary).withAlphaComponent(0.48), range: overlap)
                }
            }
            view.textStorage.endEditing()
        }

        private func setActiveRange(_ range: NSRange?) {
            guard range != activeRange else { return }
            let previous = activeRange
            activeRange = range
            if let previous, let range { redrawHighlights(in: NSUnionRange(previous, range)) }
            else if let dirty = previous ?? range { redrawHighlights(in: dirty) }
        }

        func updateInteraction() {
            guard let view = textView else { return }
            let accessible = UIAccessibility.isVoiceOverRunning
            if view.isSelectable != accessible { view.isSelectable = accessible }
            selectionGesture?.selectionMode = parent.selectionMode
            if selectionGesture?.isEnabled != !accessible { selectionGesture?.isEnabled = !accessible }
            view.accessibilityHint = accessible
                ? "Select a word or phrase, then choose Explain selection to study it."
                : "Tap a word to explain it. Drag across words to explain a phrase."
        }

        func startObservingAccessibility() {
            accessibilityObserver = NotificationCenter.default.addObserver(
                forName: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.selectionGesture?.cancelTracking()
                    self?.updateInteraction()
                }
            }
            applicationObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.selectionGesture?.cancelTracking() }
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // The enclosing vertical scroll waits only for our six-point
            // direction decision, not for a long press or double tap timeout.
            otherGestureRecognizer === readerScrollView?.panGestureRecognizer
        }

        @objc func selectionGestureChanged(_ recognizer: WordDragGestureRecognizer) {
            if recognizer.state == .ended { recognizer.commitRecognizedSelection() }
            else if recognizer.state == .cancelled || recognizer.state == .failed { recognizer.cancelTracking() }
        }

        func beginSelection(at point: CGPoint) -> Bool {
            guard let view = textView, !UIAccessibility.isVoiceOverRunning,
                  let offset = characterOffset(at: point, requiringInk: true),
                  let word = PassageTextSelection.wordRange(in: wordRanges, utf16Offset: offset, nearest: false)
            else { return false }
            anchorRange = word
            setActiveRange(word)
            pointerInWindow = view.convert(point, to: nil)
            return true
        }

        func moveSelection(to point: CGPoint) {
            guard let view = textView, anchorRange != nil else { return }
            pointerInWindow = view.convert(point, to: nil)
            updateSelectionEndpoint(at: point)
            if displayLink == nil {
                let proxy = SelectionDisplayLinkTarget(coordinator: self)
                let link = CADisplayLink(target: proxy, selector: #selector(SelectionDisplayLinkTarget.tick(_:)))
                link.add(to: .main, forMode: .common)
                displayLink = link
            }
        }

        private func updateSelectionEndpoint(at point: CGPoint) {
            guard let anchorRange,
                  let offset = characterOffset(at: point, requiringInk: false),
                  let endpoint = PassageTextSelection.wordRange(in: wordRanges, utf16Offset: offset, nearest: true)
            else { return }
            let expanded = PassageTextSelection.phraseRange(anchor: anchorRange, endpoint: endpoint)
            setActiveRange(expanded)
        }

        func finishSelection() {
            stopAutoscroll()
            guard anchorRange != nil, let range = activeRange,
                  let selection = PassageSelection(context: parent.text, range: range) else {
                cancelSelection()
                return
            }
            anchorRange = nil
            pointerInWindow = nil
            UISelectionFeedbackGenerator().selectionChanged()
            // Only a completed touch invokes AI. Highlighting and autoscrolling
            // never make requests, and a canceled scroll never opens a sheet.
            parent.onSelect(selection)
        }

        func cancelSelection() {
            stopAutoscroll()
            anchorRange = nil
            pointerInWindow = nil
            setActiveRange(nil)
        }

        private func characterOffset(at point: CGPoint, requiringInk: Bool) -> Int? {
            guard let view = textView, !parent.text.isEmpty else { return nil }
            if requiringInk {
                guard let character = view.characterRange(at: point),
                      view.selectionRects(for: character).contains(where: { $0.rect.insetBy(dx: -3, dy: -3).contains(point) })
                else { return nil }
                return view.offset(from: view.beginningOfDocument, to: character.start)
            }
            guard let position = view.closestPosition(to: point) else { return nil }
            return view.offset(from: view.beginningOfDocument, to: position)
        }

        fileprivate func autoscroll(_ link: CADisplayLink) {
            guard let view = textView, view.window != nil,
                  let scroll = readerScrollView, let pointer = pointerInWindow,
                  let gesture = selectionGesture,
                  gesture.state == .began || gesture.state == .changed else {
                stopAutoscroll()
                return
            }
            let point = scroll.convert(pointer, from: nil)
            let top = scroll.bounds.minY + scroll.adjustedContentInset.top
            let bottom = scroll.bounds.maxY - scroll.adjustedContentInset.bottom
            let edge: CGFloat = 52
            let speed: CGFloat
            if point.y < top + edge {
                speed = -min(1, max(0, (top + edge - point.y) / edge)) * 480
            } else if point.y > bottom - edge {
                speed = min(1, max(0, (point.y - bottom + edge) / edge)) * 480
            } else {
                return
            }
            let minimum = -scroll.adjustedContentInset.top
            let maximum = max(minimum, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            let duration = link.targetTimestamp - link.timestamp
            let delta = speed * CGFloat(min(max(duration, 1.0 / 120.0), 1.0 / 30.0))
            let next = min(maximum, max(minimum, scroll.contentOffset.y + delta))
            guard abs(next - scroll.contentOffset.y) > 0.01 else { return }
            scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: next), animated: false)
            updateSelectionEndpoint(at: view.convert(pointer, from: nil))
        }

        private func stopAutoscroll() {
            displayLink?.invalidate()
            displayLink = nil
        }

        func scheduleGeometryUpdate() {
            guard !isTornDown, !geometryUpdateScheduled else { return }
            geometryUpdateScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isTornDown else { return }
                self.geometryUpdateScheduled = false
                self.connectScrollView()
                self.applyScrollRequest()
                self.scheduleReadingOffset()
            }
        }

        private func connectScrollView() {
            var ancestor = textView?.superview
            var enclosing: UIScrollView?
            while let current = ancestor {
                if let scroll = current as? UIScrollView, scroll.isScrollEnabled {
                    enclosing = scroll
                    break
                }
                ancestor = current.superview
            }
            guard readerScrollView !== enclosing else { return }
            scrollObservation = nil
            readerScrollView = enclosing
            scrollObservation = enclosing?.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    if let self, let scroll = self.readerScrollView,
                       scroll.panGestureRecognizer.state == .began || scroll.panGestureRecognizer.state == .changed {
                        self.selectionGesture?.cancelTracking()
                    }
                    self?.scheduleReadingOffset()
                }
            }
        }

        private func scheduleReadingOffset() {
            guard !isTornDown, !readingOffsetScheduled else { return }
            readingOffsetScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isTornDown else { return }
                self.readingOffsetScheduled = false
                guard let view = self.textView, view.window != nil, let scroll = self.readerScrollView else { return }
                let top = scroll.bounds.minY + scroll.adjustedContentInset.top + 8
                let converted = view.convert(CGPoint(x: scroll.bounds.minX, y: top), from: scroll)
                let point = CGPoint(x: 1, y: max(0, converted.y))
                let offset = self.characterOffset(at: point, requiringInk: false) ?? 0
                guard offset != self.lastReadingOffset else { return }
                self.lastReadingOffset = offset
                self.parent.onReadingOffsetChange(offset)
            }
        }

        private func applyScrollRequest() {
            guard let request = parent.scrollRequest, request.id != appliedScrollRequest,
                  let view = textView, view.window != nil, view.bounds.width > 0, view.bounds.height > 0,
                  let scroll = readerScrollView,
                  let position = view.position(from: view.beginningOfDocument,
                                               offset: max(0, min(request.utf16Offset, parent.text.utf16.count))) else { return }
            view.layoutIfNeeded()
            let caret = view.caretRect(for: position)
            guard caret.origin.y.isFinite else { return }
            let rect = scroll.convert(caret, from: view)
            let height = max(1, scroll.bounds.height - scroll.adjustedContentInset.top - scroll.adjustedContentInset.bottom - 16)
            scroll.scrollRectToVisible(CGRect(x: rect.minX, y: max(0, rect.minY - 8), width: 1, height: height), animated: false)
            appliedScrollRequest = request.id
        }

        func suspend() {
            selectionGesture?.cancelTracking()
            stopAutoscroll()
        }

        func teardown() {
            isTornDown = true
            suspend()
            scrollObservation = nil
            if let accessibilityObserver { NotificationCenter.default.removeObserver(accessibilityObserver) }
            if let applicationObserver { NotificationCenter.default.removeObserver(applicationObserver) }
            accessibilityObserver = nil
            applicationObserver = nil
        }

        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange,
                      suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard UIAccessibility.isVoiceOverRunning,
                  let selection = PassageSelection(context: textView.text ?? "", range: range) else { return nil }
            let explain = UIAction(title: "Explain selection", image: UIImage(systemName: "text.magnifyingglass")) { [weak self] _ in
                guard let self, self.parent.text == selection.context else { return }
                self.parent.onSelect(selection)
            }
            return UIMenu(children: [explain] + suggestedActions)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            textView.accessibilityCustomActions = textView.isSelectable && textView.selectedRange.length > 0 ? [
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

@MainActor
private final class SelectionDisplayLinkTarget: NSObject {
    weak var coordinator: SelectablePassage.Coordinator?
    init(coordinator: SelectablePassage.Coordinator) { self.coordinator = coordinator }
    @objc func tick(_ link: CADisplayLink) { coordinator?.autoscroll(link) }
}

final class PassageTextView: UITextView {
    var onTypographyChange: ((PassageTextView) -> Void)?
    var onGeometryChange: (() -> Void)?
    var onWindowRemoved: (() -> Void)?

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            onTypographyChange?(self)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { onWindowRemoved?() } else { onGeometryChange?() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onGeometryChange?()
    }
}

/// Starts highlighting on touch-down, commits only on touch-up, and resolves
/// vertical scrolling before either recognizer begins. No hold timer is involved.
final class WordDragGestureRecognizer: UIGestureRecognizer {
    var selectionMode = false
    var onTouchBegan: ((CGPoint) -> Bool)?
    var onTouchMoved: ((CGPoint) -> Void)?
    var onTouchEnded: (() -> Void)?
    var onTouchCancelled: (() -> Void)?
    private weak var trackedTouch: UITouch?
    private var origin = CGPoint.zero
    private var isTrackingWord = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard trackedTouch == nil, touches.count == 1, (event.allTouches?.count ?? 1) == 1,
              let touch = touches.first, let view else {
            cancelTracking()
            return
        }
        trackedTouch = touch
        origin = touch.location(in: view)
        isTrackingWord = onTouchBegan?(origin) ?? false
        if !isTrackingWord { state = .failed }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard (event.allTouches?.count ?? 1) == 1 else { cancelTracking(); return }
        guard isTrackingWord, let touch = trackedTouch, touches.contains(touch), let view else { return }
        let point = touch.location(in: view)
        if state == .possible {
            switch PassageDragDecision.decide(dx: point.x - origin.x, dy: point.y - origin.y, selectionMode: selectionMode) {
            case .pending: return
            case .scroll: cancelTracking(); return
            case .select: state = .began
            }
        } else {
            state = .changed
        }
        onTouchMoved?(point)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard isTrackingWord, let touch = trackedTouch, touches.contains(touch) else { return }
        if (state == .began || state == .changed), let view { onTouchMoved?(touch.location(in: view)) }
        state = .ended
    }

    /// UIKit calls the registered action only after competing recognizers and
    /// failure requirements settle. Raw touchesEnded is too early to commit AI.
    func commitRecognizedSelection() {
        guard state == .ended, isTrackingWord else { return }
        isTrackingWord = false
        onTouchEnded?()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { cancelTracking() }

    override func reset() {
        super.reset()
        if isTrackingWord { onTouchCancelled?() }
        isTrackingWord = false
        trackedTouch = nil
    }

    func cancelTracking() {
        if isTrackingWord { onTouchCancelled?() }
        isTrackingWord = false
        trackedTouch = nil
        if state == .possible { state = .failed }
        else if state == .began || state == .changed { state = .cancelled }
    }
}

enum PassageDragDecision: Equatable {
    case pending, select, scroll

    static func decide(dx: CGFloat, dy: CGFloat, selectionMode: Bool) -> Self {
        guard max(abs(dx), abs(dy)) >= 6 else { return .pending }
        if selectionMode { return .select }
        return abs(dx) > abs(dy) ? .select : .scroll
    }
}

enum PassageTextSelection {
    static func wordRange(in text: String, utf16Offset: Int) -> NSRange? {
        guard utf16Offset >= 0, utf16Offset < text.utf16.count,
              (text as NSString).rangeOfComposedCharacterSequence(at: utf16Offset).location == utf16Offset else { return nil }
        return wordRange(in: wordRanges(in: text), utf16Offset: utf16Offset, nearest: false)
    }

    static func wordRanges(in text: String, languageCode: String = "") -> [NSRange] {
        guard !text.isEmpty else { return [] }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        if let language = tokenizerLanguageCode(languageCode) { tokenizer.setLanguage(NLLanguage(rawValue: language)) }
        var ranges: [NSRange] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            if text[range].unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) {
                let utf16 = NSRange(range, in: text)
                if (text as NSString).rangeOfComposedCharacterSequences(for: utf16) == utf16 { ranges.append(utf16) }
            }
            return true
        }
        return ranges
    }

    static func tokenizerLanguageCode(_ locale: String) -> String? {
        let pieces = locale.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-").map(String.init)
        guard let primary = pieces.first, !primary.isEmpty else { return nil }
        if primary == "zh" {
            if pieces.contains("hant") || pieces.contains("tw") || pieces.contains("hk") || pieces.contains("mo") {
                return "zh-Hant"
            }
            return "zh-Hans"
        }
        if primary == "no" { return "nb" }
        return primary
    }

    /// Binary search over cached word boundaries keeps dragging independent of
    /// transcript length. During a drag, whitespace snaps to the nearest word.
    static func wordRange(in ranges: [NSRange], utf16Offset: Int, nearest: Bool) -> NSRange? {
        guard !ranges.isEmpty, utf16Offset >= 0 else { return nil }
        var lower = 0
        var upper = ranges.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if ranges[middle].location <= utf16Offset { lower = middle + 1 }
            else { upper = middle }
        }
        if lower > 0, NSLocationInRange(utf16Offset, ranges[lower - 1]) { return ranges[lower - 1] }
        guard nearest else { return nil }
        if lower == 0 { return ranges[0] }
        if lower == ranges.count { return ranges[lower - 1] }
        let previous = ranges[lower - 1]
        let next = ranges[lower]
        return utf16Offset - NSMaxRange(previous) <= next.location - utf16Offset ? previous : next
    }

    static func phraseRange(anchor: NSRange, endpoint: NSRange) -> NSRange {
        let start = min(anchor.location, endpoint.location)
        return NSRange(location: start, length: max(NSMaxRange(anchor), NSMaxRange(endpoint)) - start)
    }

    static func highlightRanges(in text: String, terms: [String]) -> [NSRange] {
        guard !text.isEmpty, !terms.isEmpty else { return [] }
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
                if starts.contains(match.lowerBound), ends.contains(match.upperBound) { matches.append(NSRange(match, in: text)) }
                searchStart = match.upperBound
            }
        }
        return matches
    }
}
