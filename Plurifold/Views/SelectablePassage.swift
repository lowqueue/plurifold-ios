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
/// selection handles. A short stationary hold enables phrase dragging;
/// VoiceOver retains native text selection tools.
@MainActor
struct SelectablePassage: UIViewRepresentable {
    let text: String
    var highlights: [String] = []
    var clearSelectionRequest: UUID? = nil
    var onClearSelection: () -> Void = {}
    var languageCode = ""
    var scrollRequest: ReaderScrollRequest? = nil
    var onReadingOffsetChange: (Int) -> Void = { _ in }
    var onOpenSelection: (PassageSelection) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PassageTextView {
        let view = PassageTextView(frame: .zero, textContainer: nil)
        let coordinator = context.coordinator
        coordinator.textView = view
        view.delegate = coordinator
        view.isEditable = false
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        // Room for nearby word details or a limit notice below the last line.
        view.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 72, right: 0)
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
        gesture.onTouchBegan = { [weak coordinator] point in coordinator?.beginSelection(at: point) }
        gesture.onTouchMoved = { [weak coordinator] point in coordinator?.moveSelection(to: point) }
        gesture.onTouchEnded = { [weak coordinator] held in coordinator?.finishSelection(afterHold: held) }
        gesture.onHoldBegan = { [weak coordinator] in coordinator?.selectionHoldBegan() }
        gesture.onTouchCancelled = { [weak coordinator] in coordinator?.cancelSelection() }
        gesture.onCueTapped = { [weak coordinator] in coordinator?.finishCueTap() }
        view.addGestureRecognizer(gesture)
        coordinator.selectionGesture = gesture
        coordinator.installSelectionCue(in: view)
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
        coordinator.parent = self
        coordinator.applyClearRequest()
        coordinator.updateAppearance(of: view)
        coordinator.updateInteraction()
        coordinator.scheduleGeometryUpdate()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PassageTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let measured = uiView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
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
        private var wordGeometry = PassageWordGeometryIndex(hits: [])
        private var needsWordGeometry = true
        private var geometryWidth: CGFloat = 0
        private var utf16Length = 0
        private var appliedClearRequest: UUID?
        private var previousRange: NSRange?
        private var savedRanges: [NSRange] = []
        private var activeRange: NSRange?
        private var anchorRange: NSRange?
        private let selectionFeedback = UISelectionFeedbackGenerator()
        private var wordFeedback = PassageWordFeedbackState()
        private var pointerInWindow: CGPoint?
        private var displayLink: CADisplayLink?
        private var geometryUpdateScheduled = false
        private var readingOffsetScheduled = false
        private var lastReadingOffset: Int?
        private var appliedScrollRequest: UUID?
        private var isTornDown = false
        private let selectionCue = ReaderSelectionBar(frame: .zero)
        private var touchedExistingSelection = false

        init(_ parent: SelectablePassage) { self.parent = parent }

        func installSelectionCue(in view: PassageTextView) {
            selectionCue.isHidden = true
            selectionCue.onOpen = { [weak self] in self?.openCurrentSelection() }
            view.addSubview(selectionCue)
        }

        func updateAppearance(of view: PassageTextView) {
            let font = UIFont.preferredFont(forTextStyle: .title3, compatibleWith: view.traitCollection)
            let textChanged = view.text != parent.text
            let fontChanged = renderedFont != font
            let wordsChanged = textChanged || renderedLanguage != parent.languageCode
            let highlightsChanged = textChanged || renderedHighlights != parent.highlights
            guard textChanged || fontChanged || wordsChanged || highlightsChanged else { return }
            if textChanged {
                view.highlightLayoutManager.cancelReaction()
                utf16Length = parent.text.utf16.count
                selectionGesture?.cancelTracking()
                anchorRange = nil
                activeRange = nil
                previousRange = nil
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
            needsWordGeometry = true
            scheduleGeometryUpdate()
            renderedHighlights = parent.highlights
            renderedFont = font
            renderedLanguage = parent.languageCode
        }

        /// Text and font edits invalidate layout. Selection changes invalidate
        /// drawing only, using cached word rectangles instead of textStorage edits.
        private func rebuildWordGeometryIfNeeded() {
            guard let view = textView, view.bounds.width > 0,
                  needsWordGeometry || geometryWidth != view.bounds.width else { return }
            let manager = view.highlightLayoutManager
            manager.ensureLayout(for: view.textContainer)
            func marks(for ranges: [NSRange]) -> [PassageHighlightMark] {
                ranges.map { range in
                    let glyphs = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                    var rectangles: [CGRect] = []
                    manager.enumerateEnclosingRects(forGlyphRange: glyphs,
                        withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                        in: view.textContainer) { rect, _ in
                        if rect.width > 0 && rect.height > 0 { rectangles.append(rect) }
                    }
                    return PassageHighlightMark(range: range, rectangles: rectangles)
                }
            }
            let words = marks(for: wordRanges)
            manager.cancelReaction()
            manager.wordMarks = words
            manager.savedMarks = marks(for: savedRanges)
            manager.activeRange = activeRange
            wordGeometry = PassageWordGeometryIndex(hits: words.flatMap { mark in
                mark.rectangles.map { PassageWordHit(range: mark.range, rect: $0) }
            })
            manager.wordGeometry = wordGeometry
            manager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: utf16Length))
            geometryWidth = view.bounds.width
            needsWordGeometry = false
            positionSelectionCue()
        }

        private func setActiveRange(_ range: NSRange?) {
            guard range != activeRange else { return }
            let previous = activeRange
            activeRange = range
            if range == nil { selectionCue.isHidden = true }
            guard let manager = textView?.highlightLayoutManager else { return }
            manager.activeRange = range
            if range == nil { manager.cancelReaction() }
            for dirty in PassageTextSelection.highlightDisplayRanges(
                previous: previous, current: range, words: wordRanges
            ) {
                manager.invalidateDisplay(forCharacterRange: dirty)
            }
        }

        func applyClearRequest() {
            guard let request = parent.clearSelectionRequest, request != appliedClearRequest else { return }
            appliedClearRequest = request
            clearSelection(notify: false)
        }

        private func clearSelection(notify: Bool) {
            selectionGesture?.cancelTracking()
            wordFeedback.reset()
            previousRange = nil
            anchorRange = nil
            pointerInWindow = nil
            stopAutoscroll()
            setActiveRange(nil)
            if let view = textView, view.isSelectable { view.selectedRange = NSRange(location: 0, length: 0) }
            if notify { parent.onClearSelection() }
        }

        func updateInteraction() {
            guard let view = textView else { return }
            let accessible = UIAccessibility.isVoiceOverRunning
            if view.isSelectable != accessible { view.isSelectable = accessible }
            if selectionGesture?.isEnabled != !accessible { selectionGesture?.isEnabled = !accessible }
            view.accessibilityHint = accessible
                ? "Select a word or phrase, then choose Study selection."
                : "Tap a word for its Word details button. Hold briefly and drag in any direction to select a phrase. Release 2 to 14 words to open their explanation. Tap empty space to clear."
        }

        func startObservingAccessibility() {
            accessibilityObserver = NotificationCenter.default.addObserver(
                forName: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.selectionGesture?.cancelTracking()
                    self?.textView?.highlightLayoutManager.cancelReaction()
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
            // Early movement releases the enclosing scroll immediately. Only a
            // stationary hold claims phrase selection in every direction.
            otherGestureRecognizer === readerScrollView?.panGestureRecognizer
        }

        @objc func selectionGestureChanged(_ recognizer: WordDragGestureRecognizer) {
            if recognizer.state == .ended { recognizer.commitRecognizedSelection() }
            else if recognizer.state == .cancelled || recognizer.state == .failed { recognizer.cancelTracking() }
        }

        func beginSelection(at point: CGPoint) -> PassageTouchMode? {
            guard let view = textView, !UIAccessibility.isVoiceOverRunning else { return nil }
            rebuildWordGeometryIfNeeded()
            if !selectionCue.isHidden, selectionCue.frame.contains(point), let activeRange {
                previousRange = activeRange
                anchorRange = activeRange
                touchedExistingSelection = true
                selectionFeedback.prepare()
                return .cue
            }
            let position = CGPoint(x: point.x - view.textContainerInset.left,
                                   y: point.y - view.textContainerInset.top)
            guard let word = wordGeometry.word(at: position, nearest: false) else {
                clearSelection(notify: true)
                return nil
            }
            previousRange = activeRange
            anchorRange = word
            touchedExistingSelection = activeRange.map { NSIntersectionRange($0, word).length > 0 } ?? false
            wordFeedback.begin(at: word)
            selectionFeedback.prepare()
            if !touchedExistingSelection {
                selectionCue.isHidden = true
                setActiveRange(word)
            }
            view.highlightLayoutManager.react(to: word)
            pointerInWindow = view.convert(point, to: nil)
            return .word
        }

        func selectionHoldBegan() {
            guard anchorRange != nil else { return }
            selectionCue.isHidden = true
            if touchedExistingSelection, let anchorRange { setActiveRange(anchorRange) }
            touchedExistingSelection = false
            emitSelectionFeedback()
        }

        private func positionSelectionCue() {
            guard let view = textView, let range = activeRange,
                  anchorRange == nil || touchedExistingSelection,
                  !UIAccessibility.isVoiceOverRunning else { selectionCue.isHidden = true; return }
            let fragments = wordGeometry.selectionFragments(for: range)
            var visible = view.bounds
            if let scroll = readerScrollView {
                let viewport = scroll.bounds.inset(by: scroll.adjustedContentInset)
                visible = visible.intersection(view.convert(viewport, from: scroll))
            }
            // Keep the cue by a visible selected line; never pin it to a distant
            // screen edge after the selected words have scrolled offscreen.
            guard !visible.isNull,
                  let fragment = fragments.last(where: { $0.intersects(visible) }) else {
                selectionCue.isHidden = true
                return
            }
            let notice = selectionNotice(for: range)
            let width = min(notice == nil ? 170 : 280, max(0, visible.width - 4))
            let height: CGFloat = notice == nil ? 44 : 62
            let x = min(max(visible.minX + 2, fragment.midX - width / 2), visible.maxX - width - 2)
            let below = fragment.maxY + 7
            let y = below + height <= visible.maxY ? below : max(visible.minY, fragment.minY - height - 7)
            selectionCue.bounds = CGRect(x: 0, y: 0, width: width, height: height)
            selectionCue.center = CGPoint(x: x + width / 2, y: y + height / 2)
            selectionCue.isHidden = false
            selectionCue.update(notice: notice)
            view.bringSubviewToFront(selectionCue)
        }

        private func selectionNotice(for range: NSRange) -> String? {
            guard let selection = PassageSelection(context: parent.text, range: range) else { return nil }
            if DefinitionSelection.exceedsExplanationWordLimit(selection.text, languageCode: parent.languageCode) {
                return DefinitionSelection.wordLimitMessage
            }
            return range.length > 800 ? "Select a shorter phrase for a focused explanation." : nil
        }

        func finishCueTap() {
            anchorRange = nil
            previousRange = nil
            pointerInWindow = nil
            touchedExistingSelection = false
            wordFeedback.reset()
            positionSelectionCue()
            openCurrentSelection()
        }

        private func openCurrentSelection() {
            guard let range = activeRange, selectionNotice(for: range) == nil,
                  let selection = PassageSelection(context: parent.text, range: range) else { return }
            selectionCue.isHidden = true
            parent.onOpenSelection(selection)
        }

        private func emitSelectionFeedback() {
            selectionFeedback.selectionChanged()
            selectionFeedback.prepare()
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
            guard let view = textView, let anchorRange else { return }
            let position = CGPoint(x: point.x - view.textContainerInset.left,
                                   y: point.y - view.textContainerInset.top)
            guard let endpoint = wordGeometry.word(at: position, nearest: true) else { return }
            setActiveRange(PassageTextSelection.phraseRange(anchor: anchorRange, endpoint: endpoint))
            // Selection can snap across a gap, but feedback waits until the
            // finger reaches a word. Track the endpoint, not phrase length,
            // so shortening and reversing a selection also give one tick.
            let touchedWord = wordGeometry.word(at: position, nearest: false)
            if wordFeedback.move(to: touchedWord) {
                emitSelectionFeedback()
                if let touchedWord { view.highlightLayoutManager.react(to: touchedWord) }
            }
        }

        func finishSelection(afterHold: Bool) {
            stopAutoscroll()
            wordFeedback.reset()
            // A second tap still toggles a word. A hold from any highlighted
            // word starts a fresh phrase selection in every direction.
            if touchedExistingSelection, let anchorRange { setActiveRange(anchorRange) }
            guard anchorRange != nil, let range = activeRange,
                  PassageSelection(context: parent.text, range: range) != nil else {
                cancelSelection()
                return
            }
            let shouldClear = PassageTapDecision.shouldClear(previous: previousRange, completed: range, afterHold: afterHold)
            anchorRange = nil
            pointerInWindow = nil
            previousRange = nil
            touchedExistingSelection = false
            if shouldClear { clearSelection(notify: true); return }
            positionSelectionCue()
            if let selected = PassageSelection(context: parent.text, range: range),
               DefinitionSelection.shouldAutomaticallyExplain(selected.text, languageCode: parent.languageCode) {
                openCurrentSelection()
            }
        }

        func cancelSelection() {
            stopAutoscroll()
            wordFeedback.reset()
            textView?.highlightLayoutManager.cancelReaction()
            if anchorRange != nil { setActiveRange(previousRange) }
            previousRange = nil
            anchorRange = nil
            pointerInWindow = nil
            touchedExistingSelection = false
            positionSelectionCue()
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
                self.rebuildWordGeometryIfNeeded()
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
                    self?.positionSelectionCue()
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
                                               offset: max(0, min(request.utf16Offset, utf16Length))) else { return }
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
            wordFeedback.reset()
            stopAutoscroll()
            textView?.highlightLayoutManager.cancelReaction()
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
            let explain = UIAction(title: "Study selection", image: UIImage(systemName: "text.magnifyingglass")) { [weak self] _ in
                guard let self, self.parent.text == selection.context else { return }
                guard self.accessibleSelectionIsAllowed(selection) else { return }
                self.parent.onOpenSelection(selection)
            }
            return UIMenu(children: [explain] + suggestedActions)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            textView.accessibilityCustomActions = textView.isSelectable && textView.selectedRange.length > 0 ? [
                UIAccessibilityCustomAction(name: "Study selection", target: self,
                                            selector: #selector(explainAccessibleSelection))
            ] : []
        }

        @objc private func explainAccessibleSelection() -> Bool {
            guard let view = textView,
                  let selection = PassageSelection(context: view.text ?? "", range: view.selectedRange) else { return false }
            guard accessibleSelectionIsAllowed(selection) else { return true }
            parent.onOpenSelection(selection)
            return true
        }

        private func accessibleSelectionIsAllowed(_ selection: PassageSelection) -> Bool {
            let notice: String?
            if DefinitionSelection.exceedsExplanationWordLimit(selection.text, languageCode: parent.languageCode) {
                notice = DefinitionSelection.wordLimitMessage
            } else {
                notice = selection.range.length > 800 ? "Select a shorter phrase for a focused explanation." : nil
            }
            if let notice { UIAccessibility.post(notification: .announcement, argument: notice); return false }
            return DefinitionSelection.wordCount(in: selection.text, languageCode: parent.languageCode) > 0
        }
    }
}

@MainActor
private final class SelectionDisplayLinkTarget: NSObject {
    weak var coordinator: SelectablePassage.Coordinator?
    init(coordinator: SelectablePassage.Coordinator) { self.coordinator = coordinator }
    @objc func tick(_ link: CADisplayLink) { coordinator?.autoscroll(link) }
}

/// Geometry is computed only when text, typography, highlights, or width change.
struct PassageHighlightMark {
    let range: NSRange
    let rectangles: [CGRect]
}

struct PassageWordHit {
    let range: NSRange
    let rect: CGRect
}

/// A line index makes hit testing proportional to one line, not transcript length.
struct PassageWordGeometryIndex {
    private struct Line {
        var bounds: CGRect
        var hits: [PassageWordHit]
        var sourceRange: NSRange
    }
    private var lines: [Line] = []

    init(hits: [PassageWordHit]) {
        let sorted = hits.sorted { first, second in
            if first.rect.minY != second.rect.minY { return first.rect.minY < second.rect.minY }
            return first.rect.minX < second.rect.minX
        }
        for hit in sorted {
            if let last = lines.last, abs(last.bounds.minY - hit.rect.minY) <= 1 {
                lines[lines.count - 1].bounds = last.bounds.union(hit.rect)
                lines[lines.count - 1].hits.append(hit)
                lines[lines.count - 1].sourceRange = NSUnionRange(last.sourceRange, hit.range)
            } else {
                lines.append(Line(bounds: hit.rect, hits: [hit], sourceRange: hit.range))
            }
        }
    }

    func word(at point: CGPoint, nearest: Bool) -> NSRange? {
        guard !lines.isEmpty else { return nil }
        var lower = 0
        var upper = lines.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if lines[middle].bounds.midY < point.y { lower = middle + 1 }
            else { upper = middle }
        }
        let candidates = [max(0, lower - 1), min(lines.count - 1, lower)]
        guard let index = candidates.min(by: {
            abs(lines[$0].bounds.midY - point.y) < abs(lines[$1].bounds.midY - point.y)
        }) else { return nil }
        let line = lines[index]
        if let hit = line.hits.first(where: { $0.rect.contains(point) }) { return hit.range }
        // A little edge forgiveness leaves the actual inter-word gaps and
        // paragraph margins available for tapping away from a selection.
        if !nearest {
            return line.hits.filter { $0.rect.insetBy(dx: -1.5, dy: -1.5).contains(point) }.min {
                let firstDistance = hypot($0.rect.midX - point.x, $0.rect.midY - point.y)
                let secondDistance = hypot($1.rect.midX - point.x, $1.rect.midY - point.y)
                return firstDistance < secondDistance
            }?.range
        }
        return line.hits.min { first, second in
            let firstDistance = max(first.rect.minX - point.x, max(0, point.x - first.rect.maxX))
            let secondDistance = max(second.rect.minX - point.x, max(0, point.x - second.rect.maxX))
            return firstDistance < secondDistance
        }?.range
    }

    /// Join selected neighbours across their spaces, stopping at line breaks
    /// and at visually intervening unselected words (important for bidi text).
    /// Only lines intersecting the requested display interval are inspected.
    func selectionFragments(for range: NSRange, displaying displayRange: NSRange? = nil) -> [CGRect] {
        let visibleRange = displayRange.map { NSIntersectionRange(range, $0) } ?? range
        guard visibleRange.length > 0 else { return [] }
        var lower = 0
        var upper = lines.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if NSMaxRange(lines[middle].sourceRange) <= visibleRange.location { lower = middle + 1 }
            else { upper = middle }
        }
        var result: [CGRect] = []
        while lower < lines.count, lines[lower].sourceRange.location < NSMaxRange(visibleRange) {
            var joined: CGRect?
            for hit in lines[lower].hits {
                if NSIntersectionRange(hit.range, range).length > 0 {
                    joined = joined.map { $0.union(hit.rect) } ?? hit.rect
                } else if let fragment = joined {
                    result.append(fragment)
                    joined = nil
                }
            }
            if let joined { result.append(joined) }
            lower += 1
        }
        return result
    }
}

/// Cached rounded marks are painted under glyphs without modifying attributes.
/// Changing the active selection invalidates display only, preserving text layout.
final class PassageHighlightLayoutManager: NSLayoutManager {
    var wordMarks: [PassageHighlightMark] = []
    var savedMarks: [PassageHighlightMark] = []
    var activeRange: NSRange?
    var wordGeometry = PassageWordGeometryIndex(hits: [])
    private var reaction = PassageSelectionReactionState()
    private var reactionLink: CADisplayLink?

    private let normal = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.38, green: 0.70, blue: 0.79, alpha: 0.20)
            : UIColor(red: 0.63, green: 0.83, blue: 0.89, alpha: 0.52)
    }
    private let saved = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.80, green: 0.58, blue: 0.18, alpha: 0.42)
            : UIColor(red: 0.98, green: 0.75, blue: 0.27, alpha: 0.65)
    }
    private let selected = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.27, green: 0.53, blue: 0.68, alpha: 1)
            : UIColor(red: 0.53, green: 0.76, blue: 0.90, alpha: 1)
    }

    /// A short local lift is painted beneath the glyphs. It never transforms
    /// the text view or changes line wrapping, and is silent for Reduce Motion.
    func react(to word: NSRange) {
        cancelReaction()
        guard !UIAccessibility.isReduceMotionEnabled, !UIAccessibility.isVoiceOverRunning else { return }
        reaction.begin(at: word, timestamp: CACurrentMediaTime())
        invalidateDisplay(forCharacterRange: word)
        let target = PassageReactionDisplayLinkTarget(manager: self)
        let link = CADisplayLink(target: target, selector: #selector(PassageReactionDisplayLinkTarget.tick(_:)))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .common)
        reactionLink = link
    }

    func cancelReaction() {
        reactionLink?.invalidate()
        reactionLink = nil
        if let previous = reaction.range { invalidateDisplay(forCharacterRange: previous) }
        reaction.clear()
    }

    fileprivate func advanceReaction(_ link: CADisplayLink) {
        guard !UIAccessibility.isReduceMotionEnabled, !UIAccessibility.isVoiceOverRunning,
              let range = reaction.range, let activeRange,
              NSIntersectionRange(range, activeRange).length > 0,
              reaction.isActive(at: CACurrentMediaTime()) else {
            cancelReaction()
            return
        }
        invalidateDisplay(forCharacterRange: range)
    }

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        let characters = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let clip = context.boundingBoxOfClipPath
        let fragments = activeRange.map { wordGeometry.selectionFragments(for: $0, displaying: characters) } ?? []
        let activeRects = fragments.map {
            $0.offsetBy(dx: origin.x, dy: origin.y).insetBy(dx: -0.5, dy: 1)
        }
        func paint(_ mark: PassageHighlightMark, color: UIColor) {
            color.setFill()
            for rectangle in mark.rectangles {
                let rect = rectangle.offsetBy(dx: origin.x, dy: origin.y).insetBy(dx: -0.5, dy: 1)
                if !rect.intersects(clip) { continue }
                UIBezierPath(roundedRect: rect, cornerRadius: 3).fill()
            }
        }
        // Word marks are sorted by source range. Skip everything before the
        // requested display interval with a binary search.
        var lower = 0
        var upper = wordMarks.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if NSMaxRange(wordMarks[middle].range) <= characters.location { lower = middle + 1 }
            else { upper = middle }
        }
        // Remove the separate blue/gold marks under the selected phrase so
        // the joined fill has one color, including its spaces and rounded ends.
        context.saveGState()
        if !activeRects.isEmpty {
            let exclusions = CGMutablePath()
            exclusions.addRect(clip)
            for rect in activeRects { exclusions.addRect(rect) }
            context.addPath(exclusions)
            context.clip(using: .evenOdd)
        }
        while lower < wordMarks.count, wordMarks[lower].range.location < NSMaxRange(characters) {
            let mark = wordMarks[lower]
            paint(mark, color: normal)
            lower += 1
        }
        for mark in savedMarks where NSIntersectionRange(mark.range, characters).length > 0 {
            paint(mark, color: saved)
        }
        context.restoreGState()
        selected.setFill()
        for rect in activeRects where rect.intersects(clip) {
            UIBezierPath(roundedRect: rect, cornerRadius: 5).fill()
        }
        if let range = reaction.range, let activeRange,
           NSIntersectionRange(range, activeRange).length > 0 {
            let lift = reaction.lift(at: CACurrentMediaTime())
            if lift > 0 {
                for fragment in wordGeometry.selectionFragments(for: range, displaying: characters) {
                    let rect = fragment.offsetBy(dx: origin.x, dy: origin.y)
                        .insetBy(dx: -0.5 - lift, dy: 1 - lift * 1.4)
                    guard rect.intersects(clip) else { continue }
                    selected.setFill()
                    let bubble = UIBezierPath(roundedRect: rect, cornerRadius: 5 + lift)
                    bubble.fill()
                    UIColor.white.withAlphaComponent(0.12 * lift).setFill()
                    bubble.fill()
                }
            }
        }
    }
}

/// The display link retains only this proxy, so a view leaving the hierarchy
/// cannot leave its text manager retained by an unfinished animation.
private final class PassageReactionDisplayLinkTarget: NSObject {
    weak var manager: PassageHighlightLayoutManager?
    init(manager: PassageHighlightLayoutManager) { self.manager = manager }
    @objc func tick(_ link: CADisplayLink) {
        guard let manager else { link.invalidate(); return }
        manager.advanceReaction(link)
    }
}

/// Explicit lifecycle keeps an old word's pulse from surviving clear/cancel or
/// firing later after the finger reverses onto another word.
struct PassageSelectionReactionState {
    private(set) var range: NSRange?
    private var started: TimeInterval = 0
    private let duration: TimeInterval = 0.26

    mutating func begin(at range: NSRange, timestamp: TimeInterval) {
        self.range = range
        started = timestamp
    }

    func isActive(at timestamp: TimeInterval) -> Bool {
        range != nil && timestamp >= started && timestamp - started < duration
    }

    func lift(at timestamp: TimeInterval) -> CGFloat {
        guard isActive(at: timestamp) else { return 0 }
        let progress = (timestamp - started) / duration
        // A quick rounded rise, then a small settling rebound. Maximum lift is
        // less than two points so neighbouring words remain easy to target.
        return CGFloat(abs(sin(progress * .pi * 1.5)) * pow(1 - progress, 1.8) * 3)
    }

    mutating func clear() { range = nil }
}

final class PassageTextView: UITextView {
    var onTypographyChange: ((PassageTextView) -> Void)?
    var onGeometryChange: (() -> Void)?
    var onWindowRemoved: (() -> Void)?
    var highlightLayoutManager: PassageHighlightLayoutManager { layoutManager as! PassageHighlightLayoutManager }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        let storage = NSTextStorage()
        let manager = PassageHighlightLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.heightTracksTextView = false
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)
        super.init(frame: frame, textContainer: container)
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:textContainer:)") }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            onTypographyChange?(self)
        }
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            highlightLayoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textStorage.length))
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

/// A brief hold starts phrase selection in every direction, whether the touch
/// begins on a new word or an existing highlight. Only the nearby cue is a tap.
enum PassageTouchMode { case word, cue }

final class WordDragGestureRecognizer: UIGestureRecognizer {
    var onTouchBegan: ((CGPoint) -> PassageTouchMode?)?
    var onTouchMoved: ((CGPoint) -> Void)?
    var onTouchEnded: ((Bool) -> Void)?
    var onTouchCancelled: (() -> Void)?
    var onHoldBegan: (() -> Void)?
    var onCueTapped: (() -> Void)?
    private weak var trackedTouch: UITouch?
    private var origin = CGPoint.zero
    private var latestPoint = CGPoint.zero
    private var isTrackingWord = false
    private var holdReady = false
    private var holdTimer: Timer?
    private var mode: PassageTouchMode = .word

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard trackedTouch == nil, touches.count == 1, (event.allTouches?.count ?? 1) == 1,
              let touch = touches.first, let view else {
            cancelTracking()
            return
        }
        trackedTouch = touch
        origin = touch.location(in: view)
        latestPoint = origin
        guard let touchMode = onTouchBegan?(origin) else { state = .failed; return }
        mode = touchMode
        isTrackingWord = true
        guard mode != .cue else { return }
        let timer = Timer(timeInterval: PassageDragDecision.holdDuration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.recognizeHold() }
        }
        holdTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func recognizeHold() {
        holdTimer = nil
        guard state == .possible, isTrackingWord, trackedTouch != nil, mode == .word else { return }
        holdReady = true
        state = .began
        onHoldBegan?()
        onTouchMoved?(latestPoint)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard (event.allTouches?.count ?? 1) == 1 else { cancelTracking(); return }
        guard isTrackingWord, let touch = trackedTouch, touches.contains(touch), let view else { return }
        let point = touch.location(in: view)
        latestPoint = point
        if state == .possible {
            switch PassageDragDecision.decide(dx: point.x - origin.x, dy: point.y - origin.y, holdReady: holdReady) {
            case .pending: return
            case .scroll: cancelTracking(); return
            case .select: state = .began
            }
        } else if state == .began || state == .changed {
            state = .changed
        } else { return }
        onTouchMoved?(point)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard isTrackingWord, let touch = trackedTouch, touches.contains(touch) else { return }
        holdTimer?.invalidate()
        holdTimer = nil
        if let view {
            latestPoint = touch.location(in: view)
            if holdReady && (state == .began || state == .changed) { onTouchMoved?(latestPoint) }
        }
        state = .ended
    }

    /// Open eligible phrases only after UIKit resolves competing recognizers.
    /// Moving through 2–14 words during a longer drag never starts a request.
    func commitRecognizedSelection() {
        guard state == .ended, isTrackingWord else { return }
        isTrackingWord = false
        if mode == .cue { onCueTapped?() }
        else { onTouchEnded?(holdReady) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { cancelTracking() }

    override func reset() {
        super.reset()
        holdTimer?.invalidate()
        holdTimer = nil
        if isTrackingWord { onTouchCancelled?() }
        isTrackingWord = false
        holdReady = false
        mode = .word
        trackedTouch = nil
    }

    func cancelTracking() {
        holdTimer?.invalidate()
        holdTimer = nil
        if isTrackingWord { onTouchCancelled?() }
        isTrackingWord = false
        holdReady = false
        trackedTouch = nil
        if state == .possible { state = .failed }
        else if state == .began || state == .changed { state = .cancelled }
    }
}

enum PassageDragDecision: Equatable {
    case pending, select, scroll
    static let holdDuration: TimeInterval = 0.20

    static func decide(dx: CGFloat, dy: CGFloat, holdReady: Bool) -> Self {
        guard dx.isFinite, dy.isFinite else { return .scroll }
        if holdReady { return .select }
        return max(abs(dx), abs(dy)) >= 8 ? .scroll : .pending
    }
}

enum PassageTapDecision {
    static func shouldClear(previous: NSRange?, completed: NSRange, afterHold: Bool) -> Bool {
        !afterHold && previous == completed
    }
}

/// Feedback follows distinct word boundaries during one drag. Empty space,
/// repeated display-link samples, and a cancelled gesture produce no ticks.
struct PassageWordFeedbackState {
    private var lastWord: NSRange?

    mutating func begin(at word: NSRange) { lastWord = word }

    mutating func move(to word: NSRange?) -> Bool {
        guard let previous = lastWord, let word, word != previous else { return false }
        lastWord = word
        return true
    }

    mutating func reset() { lastWord = nil }
}

enum PassageTextSelection {
    /// Joined shapes also change rounding at the shared boundary, even if that
    /// word remains selected. Repaint those few endpoint words, not the entire
    /// anchor-to-finger interval, when a phrase grows, shrinks, or reverses.
    static func highlightDisplayRanges(previous: NSRange?, current: NSRange?, words: [NSRange]) -> [NSRange] {
        var dirty = changedDisplayRanges(previous: previous, current: current)
        guard previous != current else { return dirty }
        for range in [previous, current].compactMap({ $0 }) where range.length > 0 {
            for offset in [range.location, NSMaxRange(range) - 1] {
                if let word = wordRange(in: words, utf16Offset: offset, nearest: false), !dirty.contains(word) {
                    dirty.append(word)
                }
            }
        }
        return dirty
    }

    /// Only the newly added or removed ends need repainting during a drag.
    /// Repainting the anchor-to-finger union on every movement grows needlessly
    /// expensive for selections spanning a long transcript.
    static func changedDisplayRanges(previous: NSRange?, current: NSRange?) -> [NSRange] {
        guard previous != current else { return [] }
        guard let previous else { return current.map { [$0] } ?? [] }
        guard let current else { return [previous] }
        guard NSIntersectionRange(previous, current).length > 0 else { return [previous, current] }
        var changed: [NSRange] = []
        let start = min(previous.location, current.location)
        let startLength = abs(previous.location - current.location)
        if startLength > 0 { changed.append(NSRange(location: start, length: startLength)) }
        let end = min(NSMaxRange(previous), NSMaxRange(current))
        let endLength = abs(NSMaxRange(previous) - NSMaxRange(current))
        if endLength > 0 { changed.append(NSRange(location: end, length: endLength)) }
        return changed
    }

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
