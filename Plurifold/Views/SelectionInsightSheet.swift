import Foundation
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
    @State private var isLoadingDictionary = true
    @State private var dictionaryTask: Task<Void, Never>?
    @State private var dictionary: WordDictionaryResponse?
    @State private var dictionaryError: String?
    @State private var insightSource: String?
    @State private var isGeneratingInsight = false
    @State private var generateTask: Task<Void, Never>?
    @State private var lookupError: String?
    @State private var lookupGeneration = UUID()
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
    @State private var questionFieldFrame: CGRect = .null

    private var savedKind: String {
        DefinitionSelection.kind(for: selection.text, languageCode: lesson.languageCode)
    }

    private var dictionaryTerm: String? {
        DefinitionSelection.dictionaryTerm(for: selection.text, languageCode: lesson.languageCode)
    }

    private var scope: String {
        InsightText.scope(kind: savedKind, selection: selection.text, context: selection.context)
    }
    private var requestContext: String { InsightText.context(around: selection, utf16Limit: 1_200) }
    private var cacheContext: String { InsightText.context(around: selection, utf16Limit: 2_400) }
    private var selectionMessage: String? {
        if DefinitionSelection.exceedsExplanationWordLimit(selection.text, languageCode: lesson.languageCode) {
            return DefinitionSelection.wordLimitMessage
        }
        guard !selection.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              selection.text.utf16.count <= 800 else {
            return "Select a shorter word or phrase, up to 800 characters, to get an explanation."
        }
        return nil
    }
    private var validSelection: Bool {
        selectionMessage == nil
    }
    private var trimmedQuestion: String { question.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canAsk: Bool { !trimmedQuestion.isEmpty && trimmedQuestion.utf16.count <= 600 && !isAsking }

    private var savedDefinition: MobileSavedWord? {
        SavedDefinitionMatcher.find(in: store.words, term: selection.text, languageCode: lesson.languageCode,
                                    dialect: lesson.dialect, kind: savedKind)
    }
    private var isSaved: Bool { savedDefinition != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    heading
                    pronunciationButton

                    if let selectionMessage {
                        Label(selectionMessage, systemImage: "text.alignleft")
                            .foregroundStyle(Palette.secondary)
                    } else if savedKind == "word" {
                        dictionaryCard
                    }

                    if let savedDefinition {
                        savedDefinitionCard(savedDefinition)
                    }

                    if insight == nil, validSelection { aiExplanationButton }

                    if let lookupError {
                        Label(lookupError, systemImage: "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(Palette.secondary)
                    }
                    if let insight {
                        explanation(insight)
                        saveButton(insight)
                        followUp(insight)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .coordinateSpace(name: "wordDetailsContent")
                .onPreferenceChange(QuestionFieldFrameKey.self) { questionFieldFrame = $0 }
                .simultaneousGesture(
                    SpatialTapGesture(coordinateSpace: .named("wordDetailsContent"))
                        .onEnded { tap in
                            // A simultaneous gesture leaves links and buttons active.
                            // Taps inside the editor must keep its keyboard open.
                            if questionFocused, !questionFieldFrame.contains(tap.location) {
                                questionFocused = false
                            }
                        }
                )
            }
            .scrollDismissesKeyboard(.interactively)
            .studyBackground()
            .navigationTitle(scope == "sentence" ? "Sentence details" : savedKind == "phrase" ? "Phrase details" : "Word details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { questionFocused = false }
                }
            }
            .task(id: selection.id) { await loadSources() }
            .onDisappear {
                lookupGeneration = UUID()
                cancelAsking()
                generateTask?.cancel()
                generateTask = nil
                dictionaryTask?.cancel()
                dictionaryTask = nil
                saveTask?.cancel()
                saveTask = nil
                questionFocused = false
                speech.stop()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { speech.stop() }
            }
        }
        .tint(Palette.ink)
    }

    private func savedDefinitionCard(_ word: MobileSavedWord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Your saved definition", systemImage: "bookmark.fill")
                .font(.subheadline.weight(.semibold))
            Text(verbatim: word.meaning).textSelection(.enabled)
            if !word.note.isEmpty {
                Text(verbatim: word.note).font(.subheadline).textSelection(.enabled)
            }
            if !word.context.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "Saved context")
                    Text(verbatim: word.context).font(.subheadline).textSelection(.enabled)
                    if let title = word.sourceLessonTitle, !title.isEmpty {
                        Text(verbatim: title).font(.caption).foregroundStyle(Palette.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .studyCard()
    }

    private var dictionaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Dictionary", systemImage: "book.closed")
                .font(.subheadline.weight(.semibold))
            if isLoadingDictionary {
                ProgressView("Looking in Wiktionary…")
            } else if let dictionary, !dictionary.displayEntries.isEmpty {
                ForEach(Array(dictionary.displayEntries.enumerated()), id: \.offset) { item in
                    let entry = item.element
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(verbatim: entry.term).font(.headline)
                            if !entry.partOfSpeech.isEmpty {
                                Text(verbatim: entry.partOfSpeech)
                                    .font(.subheadline.italic()).foregroundStyle(Palette.secondary)
                            }
                        }
                        ForEach(Array(entry.definitions.enumerated()), id: \.offset) { sense in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(verbatim: sense.element).textSelection(.enabled)
                                if !isSaved {
                                    Button("Save this meaning") { saveDictionary(entry, meaning: sense.element) }
                                        .buttonStyle(.bordered).controlSize(.small)
                                        .disabled(isSavingSelection || store.isSaving)
                                }
                            }
                        }
                        if let source = entry.safeSourceURL {
                            Link("Read entry on Wiktionary", destination: source).font(.footnote)
                        }
                    }
                }
                Text("Wiktionary contributors. Community-edited dictionary; senses may describe different uses.")
                    .font(.caption).foregroundStyle(Palette.secondary)
                Text("Definitions excerpted; formatting removed.")
                    .font(.caption).foregroundStyle(Palette.secondary)
                Link("CC BY-SA 4.0", destination: WordDictionaryResponse.attributionLicenseURL)
                    .font(.caption)
                if isSaved {
                    Text("Your existing saved definition is kept below.")
                        .font(.footnote).foregroundStyle(Palette.secondary)
                }
            } else {
                Text(dictionaryMessage).font(.subheadline).foregroundStyle(Palette.secondary)
                if dictionaryTerm != nil, validSelection {
                    Button("Try dictionary again") { retryDictionary() }
                        .buttonStyle(.bordered).controlSize(.small)
                }
                if let source = dictionaryFallbackURL {
                    Link("Open in Wiktionary", destination: source).font(.footnote)
                }
            }
            if isSavingSelection { ProgressView("Saving…") }
            if didAttemptSave, let notice = store.notice {
                Label(notice, systemImage: "exclamationmark.circle")
                    .font(.footnote).foregroundStyle(Palette.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .studyCard()
    }

    private var dictionaryMessage: String {
        guard validSelection else { return "Select a shorter word or phrase, up to 800 characters." }
        guard dictionaryTerm != nil else {
            return savedKind == "phrase"
                ? "Dictionary lookup is for individual words. Select one word to see its entry, or use AI for this phrase."
                : "This selection could not be looked up as an individual word. Try selecting just the word, or request an AI explanation."
        }
        if let dictionaryError { return dictionaryError }
        switch dictionary?.status {
        case .notFound, .found:
            return "No matching dictionary entry was found for this form. AI can explain it in this passage."
        case .notApplicable:
            return "Dictionary lookup is not available for this word or language yet. You can request an AI explanation."
        case .unavailable, .none:
            return "Wiktionary is unavailable right now. You can still request an AI explanation."
        }
    }

    /// The fallback is constructed from a bounded lexical term, not a server URL.
    /// It remains useful if the dictionary service fails while the public entry works.
    private var dictionaryFallbackURL: URL? {
        guard validSelection, let term = dictionaryTerm,
              let language = ["it": "Italian", "es": "Spanish", "et": "Estonian",
                              "ka": "Georgian", "ru": "Russian", "uk": "Ukrainian",
                              "ja": "Japanese"][String(lesson.languageCode.lowercased().prefix(2))] else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "en.wiktionary.org"
        components.path = "/wiki/\(term)"
        components.fragment = language
        return components.url
    }

    private var aiExplanationButton: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { generateInsight() } label: {
                if isGeneratingInsight {
                    HStack {
                        ProgressView().tint(Palette.background)
                        Text("Explaining…")
                    }
                } else {
                    Label(lookupError == nil ? "Explain with AI" : "Try AI explanation again", systemImage: "sparkles")
                }
            }
            .buttonStyle(StudyButtonStyle())
            .disabled(!validSelection || isGeneratingInsight)
            Text("Meaning and grammar for this passage.")
                .font(.footnote).foregroundStyle(Palette.secondary)
        }
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
            Label(insightSource == "previous-ai" ? "Earlier AI explanation from your account"
                  : insightSource == "cached-ai" ? "Previously generated AI explanation" : "AI explanation",
                  systemImage: "sparkles")
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
                    Label(isSaved ? "Already in your words" : "Save to your words",
                          systemImage: isSaved ? "bookmark.fill" : "bookmark")
                }
            }
            .buttonStyle(StudyButtonStyle())
            .disabled(isSaved || isSavingSelection || store.isSaving)
            if isSaved {
                Text("Your existing saved definition has been kept.")
                    .font(.footnote).foregroundStyle(Palette.secondary)
            }
            if didAttemptSave, let notice = store.notice {
                Label(notice, systemImage: "exclamationmark.circle")
                    .font(.footnote).foregroundStyle(Palette.secondary)
            }
        }
    }

    private func followUp(_ insight: SelectionInsight) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Eyebrow(text: "Ask about this")
                Spacer()
                if questionFocused {
                    Button { questionFocused = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss question keyboard")
                    .accessibilityHint("Keeps your draft and word details open.")
                }
            }
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
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: QuestionFieldFrameKey.self,
                                               value: geometry.frame(in: .named("wordDetailsContent")))
                    }
                }
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

    private func loadSources() async {
        let generation = UUID()
        lookupGeneration = generation
        generateTask?.cancel()
        generateTask = nil
        dictionaryTask?.cancel()
        dictionaryTask = nil
        isGeneratingInsight = false
        cancelAsking()
        conversation = []
        question = ""
        askError = nil
        insight = nil
        insightSource = nil
        dictionary = nil
        lookupError = nil
        dictionaryError = nil
        isLoadingDictionary = dictionaryTerm != nil
        guard validSelection else {
            isLoadingDictionary = false
            return
        }
        guard !Task.isCancelled else { isLoadingDictionary = false; return }
        if DefinitionSelection.shouldAutomaticallyExplain(selection.text, languageCode: lesson.languageCode) {
            // A finished 2–14 word selection opens its contextual explanation once.
            // Single words stay dictionary-first, with AI behind an explicit button.
            isLoadingDictionary = false
            generateInsight()
        } else {
            await loadDictionary(generation: generation)
        }
    }

    private func retryDictionary() {
        guard !isLoadingDictionary, validSelection, dictionaryTerm != nil else { return }
        dictionary = nil
        dictionaryError = nil
        isLoadingDictionary = true
        let generation = lookupGeneration
        dictionaryTask = Task {
            await loadDictionary(generation: generation)
            if lookupGeneration == generation { dictionaryTask = nil }
        }
    }

    private func loadDictionary(generation: UUID) async {
        defer { if lookupGeneration == generation { isLoadingDictionary = false } }
        guard let dictionaryTerm else { return }
        do {
            let request = WordDictionaryRequest(term: dictionaryTerm, languageCode: lesson.languageCode)
            let response: WordDictionaryResponse = try await store.api.post("/api/mobile/dictionary", body: request)
            try Task.checkCancellation()
            guard lookupGeneration == generation else { return }
            dictionary = response
        } catch is CancellationError {
            // The selected passage or account changed.
        } catch {
            guard !Task.isCancelled, lookupGeneration == generation else { return }
            dictionaryError = "The dictionary is unavailable right now. You can still request an AI explanation."
        }
    }

    private func generateInsight() {
        guard validSelection, !isGeneratingInsight else { return }
        let generation = lookupGeneration
        lookupError = nil
        isGeneratingInsight = true
        generateTask = Task {
            defer {
                if lookupGeneration == generation { isGeneratingInsight = false; generateTask = nil }
            }
            do {
                let request = InsightDefineRequest(selection: selection.text, context: requestContext,
                                                   language: lesson.languageName, dialect: lesson.dialect,
                                                   scope: scope, cacheContext: cacheContext, lookupOnly: false)
                let response: InsightDefineResponse = try await store.api.post("/api/define", body: request)
                try Task.checkCancellation()
                guard lookupGeneration == generation else { return }
                guard let answer = response.insight else { throw PlurifoldAPIError.invalidResponse }
                insight = answer
                insightSource = response.source
            } catch is CancellationError {
                // A dismissed sheet must not keep a generation request running.
            } catch {
                guard !Task.isCancelled, lookupGeneration == generation else { return }
                lookupError = error.localizedDescription
            }
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
                                    dialect: lesson.dialect, kind: savedKind, sourceLessonID: lesson.id,
                                    sourceLessonTitle: InsightText.prefix(lesson.title, utf16Limit: 500),
                                    pronunciation: insight.pronunciation, partOfSpeech: insight.partOfSpeech,
                                    status: "learning")
        saveTask = Task {
            defer { isSavingSelection = false; saveTask = nil }
            guard !Task.isCancelled else { return }
            await store.saveWord(draft)
        }
    }

    private func saveDictionary(_ entry: WordDictionaryEntry, meaning: String) {
        guard !isSaved, !isSavingSelection, !store.isSaving, entry.safeSourceURL != nil else { return }
        didAttemptSave = true
        isSavingSelection = true
        let draft = MobileWordDraft(term: selection.text,
                                    meaning: InsightText.prefix(meaning, utf16Limit: 2_000),
                                    note: InsightText.prefix(entry.savedAttribution, utf16Limit: 2_000),
                                    context: requestContext, languageCode: lesson.languageCode,
                                    dialect: lesson.dialect, kind: savedKind, sourceLessonID: lesson.id,
                                    sourceLessonTitle: InsightText.prefix(lesson.title, utf16Limit: 500),
                                    partOfSpeech: entry.partOfSpeech, status: "learning")
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
                                        history: conversation.suffix(2).map {
            InsightExchange(question: InsightText.prefix($0.question, utf16Limit: 600),
                            answer: InsightText.prefix($0.answer, utf16Limit: 900))
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

private struct QuestionFieldFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .null

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct InsightDefineRequest: Encodable {
    let profile = "mobile-lite"
    let selection: String
    let context: String
    let language: String
    let dialect: String?
    let scope: String
    let cacheContext: String
    let lookupOnly: Bool
}

struct InsightDefineResponse: Decodable {
    let insight: SelectionInsight?
    let source: String?
}
private struct InsightAskResponse: Decodable { let answer: String }

private struct InsightAskRequest: Encodable {
    let profile = "mobile-lite"
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

struct SelectionInsight: Codable {
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

enum InsightText {
    static func scope(kind: String, selection: String, context: String) -> String {
        let selected = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        let passage = context.trimmingCharacters(in: .whitespacesAndNewlines)
        return kind == "phrase" && !selected.isEmpty && selected == passage ? "sentence" : kind
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
