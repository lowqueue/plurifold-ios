import SwiftUI

struct LiveReviewView: View {
    @EnvironmentObject private var store: LiveLibraryStore
    @EnvironmentObject private var studyScope: MobileStudyScope
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var review = MobileReviewSession()

    private var words: [MobileSavedWord] {
        MobileVocabularyIndex(words: store.words, languageCode: studyScope.language?.code).words
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let language = studyScope.language {
                        StudyLanguageHeader(language: language).studyCard()

                        if let notice = store.notice {
                            LibraryNoticeRow(notice: notice)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .studyCard()
                        }

                        if store.isLoading && words.isEmpty {
                            ProgressView("Loading your review…")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                        } else if words.isEmpty {
                            ContentUnavailableView("Build your \(language.name) review", systemImage: "rectangle.on.rectangle",
                                                   description: Text("Save words or phrases from your lessons, then come back to practice them here."))
                        } else if review.languageCode == MobileLanguageKey.normalized(language.code) {
                            if let word = review.current {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("\(review.completedIDs.count) of \(review.totalCount) completed")
                                        Spacer()
                                        Text("\(review.queue.count) to go")
                                    }
                                    .font(StudyTypography.font(.caption))
                                    .foregroundStyle(Palette.secondary)
                                    ProgressView(value: Double(review.completedIDs.count), total: Double(max(1, review.totalCount)))
                                        .tint(Palette.progress)
                                }
                                .studyCard()

                                reviewCard(word)
                                    .id(word.id)
                                    .transition(.opacity)

                                if review.isAnswerRevealed {
                                    HStack(spacing: 12) {
                                        Button {
                                            review.again()
                                        } label: {
                                            Label("Again", systemImage: "arrow.uturn.backward")
                                                .font(StudyTypography.font(.body, weight: .semibold))
                                                .frame(maxWidth: .infinity, minHeight: 48)
                                                .padding(.horizontal, 12)
                                                .foregroundStyle(Palette.navInk)
                                                .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: Palette.controlRadius, style: .continuous))
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: Palette.controlRadius, style: .continuous)
                                                        .strokeBorder(Palette.line, lineWidth: 1)
                                                }
                                        }
                                        .buttonStyle(GardenPressStyle())
                                        Button {
                                            review.gotIt()
                                        } label: {
                                            Label("Got it", systemImage: "checkmark")
                                        }
                                        .buttonStyle(StudyButtonStyle())
                                    }
                                    Text("Again brings this word back later in the round.")
                                        .font(StudyTypography.font(.footnote))
                                        .foregroundStyle(Palette.secondary)
                                } else {
                                    Button("Reveal meaning") { review.reveal() }
                                        .buttonStyle(StudyButtonStyle())
                                }
                            } else if review.totalCount > 0 {
                                ContentUnavailableView {
                                    Label("Round complete", systemImage: "checkmark.circle")
                                } description: {
                                    Text("You reviewed \(review.completedIDs.count) saved \(review.completedIDs.count == 1 ? "item" : "items") in \(language.name).")
                                } actions: {
                                    Button("Review again") {
                                        review.restart(words: words, languageCode: language.code)
                                    }
                                    .buttonStyle(StudyButtonStyle())
                                }
                            } else {
                                ProgressView("Preparing your review…").frame(maxWidth: .infinity)
                            }
                        }
                    } else {
                        ChooseStudyLanguageView()
                    }
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(Palette.isGarden ? 20 : 24)
                .frame(maxWidth: .infinity)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: review.current?.id)
            }
            .studyBackground()
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Palette.accent)
            .refreshable { await store.refresh() }
            .task { if !store.hasLoaded { await store.refresh() } }
            .onAppear { reconcileReview() }
            .onChange(of: words) { _, _ in reconcileReview() }
            .onChange(of: studyScope.language?.code) { _, _ in reconcileReview() }
        }
    }

    private func reviewCard(_ word: MobileSavedWord) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: word.kind == "phrase" ? "Phrase" : "Word")
                Text(word.term)
                    .font(StudyTypography.font(.largeTitle, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let pronunciation = word.pronunciation, !pronunciation.isEmpty {
                    Text(pronunciation).font(.subheadline.monospaced()).foregroundStyle(Palette.secondary)
                }
            }
            if review.isAnswerRevealed {
                Divider().overlay(Palette.line)
                Text(word.meaning.isEmpty ? "No meaning saved yet." : word.meaning)
                    .font(StudyTypography.font(.title3))
                    .textSelection(.enabled)
                if !word.note.isEmpty {
                    Text(word.note).font(StudyTypography.font(.body)).foregroundStyle(Palette.secondary)
                }
                if !word.context.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "In context")
                        Text(word.context).font(StudyTypography.font(.body)).foregroundStyle(Palette.secondary)
                    }
                }
                if let title = word.sourceLessonTitle, !title.isEmpty {
                    Text(title).font(StudyTypography.font(.caption)).foregroundStyle(Palette.secondary)
                }
            } else {
                Text("Can you remember the meaning?")
                    .font(StudyTypography.font(.body))
                    .foregroundStyle(Palette.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Palette.isGarden ? 250 : 220, alignment: .topLeading)
        .studyCard()
        .overlay(alignment: .topLeading) {
            Capsule().fill(Palette.warm).frame(width: 38, height: 4).padding(.leading, 20)
                .allowsHitTesting(false)
        }
    }

    private func reconcileReview() {
        review.reconcile(words: words, languageCode: studyScope.language?.code)
    }
}
