import SwiftUI

struct ProgressScreen: View {
    @EnvironmentObject private var store: StudyStore
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: "One story at a time")
                Text("Your practice,\ntaking shape.")
                    .font(.system(.largeTitle, design: .serif))
                HStack(alignment: .top, spacing: 12) {
                    metric(store.completedLessonIDs.count, label: "Lessons completed", symbol: "checkmark.circle")
                    metric(store.savedWords.count, label: "Expressions saved", symbol: "bookmark")
                }
                ForEach(store.catalog.courses) { course in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(course.title).font(.title3.weight(.semibold))
                        ProgressView(value: store.completionFraction(for: course)).tint(Palette.ink)
                            .accessibilityLabel("Collection completion")
                        ForEach(course.lessons) { lesson in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: store.completedLessonIDs.contains(lesson.id) ? "checkmark.circle.fill" : "circle")
                                    .padding(.top, 3).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(lesson.title).font(.body)
                                    if let score = store.bestScore(for: lesson) {
                                        Text("Best result: \(score)/\(lesson.questions.count)")
                                            .font(.subheadline.monospaced()).foregroundStyle(Palette.secondary)
                                    } else {
                                        Text(store.lastParagraph(for: lesson) == nil ? "Ready when you are" : "Reading in progress")
                                            .font(.subheadline).foregroundStyle(Palette.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .studyCard()
                }
                VStack(alignment: .leading, spacing: 12) {
                    Label("On this device", systemImage: "iphone")
                        .font(.headline)
                    Text("This first version keeps your saved words and lesson progress here. It does not connect to your Plurifold account yet.")
                        .font(.body).foregroundStyle(Palette.secondary)
                    Button("Reset lesson progress", role: .destructive) { confirmReset = true }
                        .frame(minHeight: 44)
                }
                .studyCard()
            }
            .padding(20)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .studyBackground()
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Reset lesson progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset progress", role: .destructive) { store.resetProgress() }
        } message: {
            Text("Your reading position and quiz results will be cleared. Your saved expressions will stay.")
        }
    }

    private func metric(_ value: Int, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.title2)
            Text("\(value)").font(.system(.largeTitle, design: .monospaced))
            Text(label).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .studyCard()
    }
}
