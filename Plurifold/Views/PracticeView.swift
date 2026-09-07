import SwiftUI

struct PracticeView: View {
    let lesson: Lesson
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss
    @State private var questionIndex = 0
    @State private var selectedAnswer: Int?
    @State private var score = 0
    @State private var finished = false

    private var question: PracticeQuestion { lesson.questions[questionIndex] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if finished {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 48, weight: .light))
                        .padding(.top, 24)
                    Eyebrow(text: "Lesson complete")
                    Text("A little more understood.")
                        .font(.system(.largeTitle, design: .serif))
                    Text("You answered \(score) of \(lesson.questions.count) questions correctly.")
                        .font(.title3)
                    Text("Your progress has been saved on this device. You can revisit the story or try the questions again.")
                        .foregroundStyle(Palette.secondary)
                    Button("Back to the story") { dismiss() }
                        .buttonStyle(StudyButtonStyle())
                    Button("Try again") {
                        questionIndex = 0
                        selectedAnswer = nil
                        score = 0
                        finished = false
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Eyebrow(text: "Question \(questionIndex + 1) of \(lesson.questions.count)")
                    ProgressView(value: Double(questionIndex), total: Double(lesson.questions.count))
                        .tint(Palette.ink)
                    Text(question.prompt).font(.system(.title, design: .serif))
                    VStack(spacing: 12) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                            Button {
                                guard selectedAnswer == nil else { return }
                                selectedAnswer = index
                                if index == question.answerIndex { score += 1 }
                            } label: {
                                HStack(alignment: .center, spacing: 14) {
                                    Text(option).font(.body).multilineTextAlignment(.leading)
                                    Spacer(minLength: 4)
                                    Image(systemName: answerSymbol(for: index))
                                        .accessibilityHidden(true)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding(16)
                                .background(selectedAnswer != nil && index == question.answerIndex ? Palette.field : Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(selectedAnswer == index ? Palette.ink : Palette.line, lineWidth: selectedAnswer == index ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedAnswer != nil)
                            .accessibilityLabel(option + answerAccessibility(for: index))
                        }
                    }
                    if let selectedAnswer {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(selectedAnswer == question.answerIndex ? "That's right" : "Keep this one in mind", systemImage: selectedAnswer == question.answerIndex ? "checkmark.circle" : "lightbulb")
                                .font(.headline)
                            Text(question.explanation).foregroundStyle(Palette.secondary)
                        }
                        .studyCard()
                        .accessibilityElement(children: .combine)
                        Button(questionIndex == lesson.questions.count - 1 ? "Finish lesson" : "Next question") {
                            guard self.selectedAnswer != nil, !finished else { return }
                            if questionIndex == lesson.questions.count - 1 {
                                store.complete(lesson, score: score)
                                finished = true
                            } else {
                                questionIndex += 1
                                self.selectedAnswer = nil
                            }
                        }
                        .buttonStyle(StudyButtonStyle())
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .studyBackground()
        .navigationTitle("Understanding")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func answerSymbol(for index: Int) -> String {
        guard let selectedAnswer else { return "circle" }
        if index == question.answerIndex { return "checkmark.circle.fill" }
        return index == selectedAnswer ? "xmark.circle" : "circle"
    }

    private func answerAccessibility(for index: Int) -> String {
        guard let selectedAnswer else { return "" }
        if index == question.answerIndex { return ", correct answer" }
        return index == selectedAnswer ? ", your answer, incorrect" : ""
    }
}
