import Foundation
import NaturalLanguage
import SwiftUI

@MainActor
struct SelectionInsightSheet: View {
    let selection: PassageSelection
    let lesson: MobileLesson

    @EnvironmentObject private var store: LiveLibraryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speech = SpeechPlayer()
    @State private var insight: SelectionInsight?
    @State private var isLoading = true
    @State private var lookupError: String?
    @State private var lookupGeneration = UUID()
    @State private var retryNumber = 0
    @State private var question = ""
    @State private var conversation: [InsightExchange] = []
    @State private var askError: String?
    @State private var isAsking = false
    @State private var askTask: Task<Void, Never>?
    @State private var askGeneration = UUID()
    @State private var saveTask: Task<Void, Never>?
    @State private var isSavingSelection = false
    @State private var didAttemptSave = false
    @FocusState private var questionFocused: Bool

    private var scope: String {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = selection.text
        tokenizer.setLanguage(NLLanguage(rawValue: String(lesson.languageCode.prefix(2))))
        var words = 0
        tokenizer.enumerateTokens(in: selection.text.startIndex..<selection.text.endIndex) { range, _ in
            if selection.text[range].unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) {
                words += 1
            }
            return words < 2
        }
        return words > 1 ? "phrase" : "word"
    }

    private var requestContext: String { InsightText.context(around: selection, utf16Limit: 2_400) }
    private var validSelection: Bool {
        !selection.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selection.text.utf16.count <= 800
    }
    private var trimmedQuestion: String { question.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canAsk: Bool { !trimmedQuestion.isEmpty && trimmedQuestion.utf16.count <= 600 && !isAsking }

    private var isSaved: Bool {
        let term = InsightText.normalizedTerm(selection.text, language: lesson.languageCode)
        let dialect = InsightText.normalizedDialect(lesson.dialect)
        return store.words.contains {
            $0.languageCode == lesson.languageCode && $0.kind == scope
                && InsightText.normalizedTerm($0.term, language: lesson.languageCode) == term
                && InsightText.normalizedDialect($0.dialect) == dialect
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    heading
                    pronunciationButton

                    if isLoading {
                        ProgressView("Finding the meaning…")
                            .frame(maxWidth: .infinity).padding(.vertical, 28)
                    } else if let lookupError {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(lookupError, systemImage: "exclamationmark.circle")
                                .foregroundStyle(Palette.secondary)
                            if validSelection {
                                Button("Try again") { retryNumber += 1 }
                                    .buttonStyle(.bordered)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .studyCard()
                    } else if let insight {
                        explanation(insight)
                        saveButton(insight)
                        followUp(insight)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "From this lesson")
                        Text(requestContext).textSelection(.enabled)
                        Text(lesson.title).font(.caption).foregroundStyle(Palette.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .studyCard()
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .studyBackground()
            .navigationTitle(scope == "phrase" ? "Phrase details" : "Word details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: "\(selection.id.uuidString):\(retryNumber)") { await loadInsight() }
            .onDisappear {
                cancelAsking()
                saveTask?.cancel()
                saveTask = nil
                speech.stop()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { speech.stop() }
            }
        }
        .tint(Palette.ink)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: lesson.languageName)
            Text(selection.text).font(.largeTitle.weight(.semibold)).textSelection(.enabled)
            if let dialect = lesson.dialect, !dialect.isEmpty {
                Text(dialect).font(.caption).foregroundStyle(Palette.secondary)
            }
            if let insight {
                if !insight.partOfSpeech.isEmpty {
                    Text(insight.partOfSpeech).font(.subheadline.italic()).foregroundStyle(Palette.secondary)
                }
                if !insight.pronunciation.isEmpty {
                    Text(insight.pronunciation).font(.body.monospaced()).textSelection(.enabled)
                }
            }
        }
    }

    private var pronunciationButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if speech.isSpeaking { speech.stop() }
                else { speech.speak(selection.text, language: lesson.languageCode) }
            } label: {
                Label(speech.isSpeaking ? "Stop pronunciation" : "Hear pronunciation",
                      systemImage: speech.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                    .frame(minHeight: 36)
            }
            .buttonStyle(.bordered)
            if let notice = speech.notice {
                Text(notice).font(.footnote).foregroundStyle(Palette.secondary)
            }
        }
    }

    @ViewBuilder private func explanation(_ insight: SelectionInsight) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("AI explanation", systemImage: "sparkles")
                .font(.caption).foregroundStyle(Palette.secondary)
            insightSection("Meaning", insight.generalMeaning)
            insightSection("Meaning here", insight.contextMeaning)
            insightSection("Grammar", insight.grammar)
            insightSection("Usage", insight.usage)
            insightSection("Remember", insight.tip)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .studyCard()

        let forms = insight.estonianPrincipalForms
        if !forms.nominative.isEmpty || !forms.genitive.isEmpty || !forms.partitive.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "Estonian principal forms")
                insightSection("Nominative", forms.nominative)
                insightSection("Genitive", forms.genitive)
                insightSection("Partitive", forms.partitive)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .studyCard()
        }

        if let verb = insight.verbConjugation,
           !verb.lemma.isEmpty || !verb.summary.isEmpty || !verb.groups.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "Verb forms")
                if !verb.lemma.isEmpty { Text(verb.lemma).font(.title3.weight(.semibold)).textSelection(.enabled) }
                if !verb.summary.isEmpty { Text(verb.summary).textSelection(.enabled) }
                ForEach(Array(verb.groups.enumerated()), id: \.offset) { row in
                    insightSection(row.element.label, row.element.forms)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .studyCard()
        }
    }

    @ViewBuilder private func insightSection(_ title: String, _ text: String) -> some View {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondary)
                Text(text).textSelection(.enabled)
            }
        }
    }

    private func saveButton(_ insight: SelectionInsight) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { save(insight) } label: {
                if isSavingSelection {
                    HStack {
                        ProgressView().tint(Palette.background)
                        Text("Saving…")
                    }
                } else {
                    Label(isSaved ? "Saved to your words" : "Save to your words",
                          systemImage: isSaved ? "bookmark.fill" : "bookmark")
                }
            }
            .buttonStyle(StudyButtonStyle())
            .disabled(isSaved || isSavingSelection || store.isSaving)
            if didAttemptSave, let notice = store.notice {
                Label(notice, systemImage: "exclamationmark.circle")
                    .font(.footnote).foregroundStyle(Palette.secondary)
            }
        }
    }

    private func followUp(_ insight: SelectionInsight) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(text: "Ask about this")
            ForEach(Array(conversation.enumerated()), id: \.offset) { row in
                VStack(alignment: .leading, spacing: 8) {
                    Text(row.element.question).font(.subheadline.weight(.semibold))
                    Text(row.element.answer).textSelection(.enabled)
                }
                .padding(.bottom, 6)
            }
            TextField("Why is this form used here?", text: $question, axis: .vertical)
                .lineLimit(2...5)
                .padding(14)
                .background(Palette.background, in: RoundedRectangle(cornerRadius: 12))
                .focused($questionFocused)
                .disabled(isAsking)
                .accessibilityLabel("Question about this word or phrase")
            if trimmedQuestion.utf16.count > 600 {
                Text("Please shorten your question to 600 characters or fewer.")
                    .font(.footnote).foregroundStyle(Palette.secondary)
            }
            if let askError {
                Label(askError, systemImage: "exclamationmark.circle")
                    .font(.footnote).foregroundStyle(Palette.secondary)
            }
            Button { ask(insight) } label: {
                if isAsking {
                    HStack {
                        ProgressView().tint(Palette.background)
                        Text("Thinking…")
                    }
                } else {
                    Label(askError == nil ? "Ask" : "Try again", systemImage: "arrow.up")
                }
            }
            .buttonStyle(StudyButtonStyle())
            .disabled(!canAsk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .studyCard()
    }

    private func loadInsight() async {
        let generation = UUID()
        lookupGeneration = generation
        cancelAsking()
        conversation = []
        question = ""
        askError = nil
        insight = nil
        lookupError = nil
        isLoading = true
        defer { if lookupGeneration == generation { isLoading = false } }
        guard validSelection else {
            lookupError = "Select a shorter word or phrase, up to 800 characters, to get an explanation."
            return
        }
        do {
            let request = InsightDefineRequest(selection: selection.text, context: requestContext,
                                               language: lesson.languageName, dialect: lesson.dialect, scope: scope)
            let response: InsightDefineResponse = try await store.api.post("/api/define", body: request)
            try Task.checkCancellation()
            guard lookupGeneration == generation else { return }
            insight = response.insight
        } catch is CancellationError {
            // SwiftUI cancels this task when the selected passage or sheet changes.
        } catch {
            guard !Task.isCancelled, lookupGeneration == generation else { return }
            lookupError = error.localizedDescription
        }
    }

    private func save(_ insight: SelectionInsight) {
        guard !isSaved, !isSavingSelection, !store.isSaving else { return }
        didAttemptSave = true
        isSavingSelection = true
        let note = [insight.grammar, insight.usage, insight.tip]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n\n")
        let draft = MobileWordDraft(term: selection.text, meaning: insight.generalMeaning,
                                    note: note, context: requestContext, languageCode: lesson.languageCode,
                                    dialect: lesson.dialect, kind: scope, sourceLessonID: lesson.id,
                                    sourceLessonTitle: InsightText.prefix(lesson.title, utf16Limit: 500),
                                    pronunciation: insight.pronunciation, partOfSpeech: insight.partOfSpeech,
                                    status: "learning")
        saveTask = Task {
            defer { isSavingSelection = false; saveTask = nil }
            guard !Task.isCancelled else { return }
            await store.saveWord(draft)
        }
    }

    private func ask(_ insight: SelectionInsight) {
        guard canAsk, validSelection else { return }
        let generation = UUID()
        askGeneration = generation
        questionFocused = false
        askError = nil
        isAsking = true
        let submittedQuestion = trimmedQuestion
        var request = InsightAskRequest(selection: selection.text, context: requestContext,
                                        language: lesson.languageName, dialect: lesson.dialect, scope: scope,
                                        entry: insight, question: submittedQuestion,
                                        history: conversation.suffix(4).map {
            InsightExchange(question: InsightText.prefix($0.question, utf16Limit: 600),
                            answer: InsightText.prefix($0.answer, utf16Limit: 2_000))
        })
        askTask = Task {
            defer {
                if askGeneration == generation { isAsking = false; askTask = nil }
            }
            do {
                // The server also caps the UTF-8 body. Keep the current entry intact and
                // discard only the oldest history if multilingual text fills that budget.
                while try JSONEncoder().encode(request).count > 28_000, !request.history.isEmpty {
                    request.history.removeFirst()
                }
                guard try JSONEncoder().encode(request).count <= 28_000 else {
                    throw InsightRequestError.tooLarge
                }
                let response: InsightAskResponse = try await store.api.post("/api/ask", body: request)
                try Task.checkCancellation()
                guard askGeneration == generation else { return }
                conversation.append(InsightExchange(question: submittedQuestion, answer: response.answer))
                question = ""
            } catch is CancellationError {
                // A dismissed sheet must not keep a follow-up request running.
            } catch {
                guard !Task.isCancelled, askGeneration == generation else { return }
                askError = error.localizedDescription
            }
        }
    }

    private func cancelAsking() {
        askGeneration = UUID()
        askTask?.cancel()
        askTask = nil
        isAsking = false
    }
}

private struct InsightDefineRequest: Encodable {
    let selection: String
    let context: String
    let language: String
    let dialect: String?
    let scope: String
}

private struct InsightDefineResponse: Decodable { let insight: SelectionInsight }
private struct InsightAskResponse: Decodable { let answer: String }

private struct InsightAskRequest: Encodable {
    let selection: String
    let context: String
    let language: String
    let dialect: String?
    let scope: String
    let entry: SelectionInsight
    let question: String
    var history: [InsightExchange]
}

private struct InsightExchange: Codable {
    let question: String
    let answer: String
}

private struct SelectionInsight: Codable {
    let generalMeaning: String
    let contextMeaning: String
    let grammar: String
    let usage: String
    let partOfSpeech: String
    let pronunciation: String
    let tip: String
    let estonianPrincipalForms: PrincipalForms
    let verbConjugation: VerbConjugation?

    struct PrincipalForms: Codable {
        let nominative: String
        let genitive: String
        let partitive: String
    }

    struct VerbConjugation: Codable {
        let lemma: String
        let summary: String
        let groups: [Group]

        struct Group: Codable {
            let label: String
            let forms: String
        }
    }
}

private enum InsightRequestError: LocalizedError {
    case tooLarge
    var errorDescription: String? {
        "This explanation is too long to include in a follow-up. Try selecting a shorter passage."
    }
}

private enum InsightText {
    static func normalizedTerm(_ value: String, language: String) -> String {
        value.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: Locale(identifier: language))
    }

    static func normalizedDialect(_ value: String?) -> String {
        (value ?? "").precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: Locale(identifier: "en-US"))
    }

    static func prefix(_ value: String, utf16Limit: Int) -> String {
        guard value.utf16.count > utf16Limit else { return value }
        var result = ""
        var count = 0
        for character in value {
            let next = String(character)
            let length = next.utf16.count
            guard count + length <= utf16Limit else { break }
            result.append(character)
            count += length
        }
        return result
    }

    static func context(around selection: PassageSelection, utf16Limit: Int) -> String {
        let source = selection.context as NSString
        guard source.length > utf16Limit else { return selection.context }
        guard selection.range.length <= utf16Limit else { return prefix(selection.text, utf16Limit: utf16Limit) }
        let spare = utf16Limit - selection.range.length
        let desiredStart = max(0, selection.range.location - spare / 2)
        let end = min(source.length, desiredStart + utf16Limit)
        let start = max(0, end - utf16Limit)

        // Round inward to composed-character boundaries without cutting the selected text.
        let firstCharacter = source.rangeOfComposedCharacterSequence(at: start)
        let safeStart = firstCharacter.location == start ? start : NSMaxRange(firstCharacter)
        let safeEnd = end == source.length ? end : source.rangeOfComposedCharacterSequence(at: end).location
        guard safeStart <= selection.range.location, safeEnd >= NSMaxRange(selection.range), safeStart < safeEnd else {
            return prefix(selection.text, utf16Limit: utf16Limit)
        }
        return source.substring(with: NSRange(location: safeStart, length: safeEnd - safeStart))
    }
}
