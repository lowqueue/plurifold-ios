import SwiftUI

/// Immediate practice uses the course's answer key, with no AI request or
/// implicit completion write. Editing any answer clears its prior feedback.
struct CourseExerciseView: View {
    let exercise: MobileCourseExercise
    @State private var textAnswers: [String: String] = [:]
    @State private var choiceAnswers: [String: Set<String>] = [:]
    @State private var checkedAnswers: [String: Bool] = [:]
    @State private var revealsAnswers = false
    @FocusState private var focusedItem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.title).font(.headline.monospaced()).accessibilityAddTraits(.isHeader)
                Text("Try an answer, then check it.")
                    .font(.caption).foregroundStyle(Palette.secondary)
            }
            ForEach(Array(exercise.items.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(index + 1). \(item.prompt)")
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    if item.options.isEmpty {
                        TextField("Your answer", text: answerBinding(for: item.id), axis: .vertical)
                            .font(.body)
                            .lineLimit(1...5)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($focusedItem, equals: item.id)
                            .onSubmit { focusedItem = nil }
                            .padding(12)
                            .background(Palette.background, in: RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.line, lineWidth: 1))
                            .accessibilityLabel("Answer to \(item.prompt)")
                    } else {
                        if item.multiple {
                            Text("Choose all that apply.").font(.caption).foregroundStyle(Palette.secondary)
                        }
                        ForEach(item.options) { option in optionButton(option, item: item) }
                    }
                    if let correct = checkedAnswers[item.id], !revealsAnswers {
                        Label(correct ? "Correct" : "Try another answer",
                              systemImage: correct ? "checkmark.circle.fill" : "arrow.clockwise")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(correct ? Palette.green : Palette.secondary)
                            .accessibilityLabel(correct ? "Answer correct" : "Answer does not match. Try again.")
                    }
                    if revealsAnswers {
                        let expected = expectedAnswers(for: item)
                        if !expected.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Answer").font(.caption.weight(.semibold))
                                Text(expected.joined(separator: " / ")).font(.subheadline)
                            }
                            .foregroundStyle(Palette.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Palette.groupSurface, in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                if index < exercise.items.count - 1 {
                    Rectangle().fill(Palette.line.opacity(0.45)).frame(height: 1)
                }
            }
            Button {
                focusedItem = nil
                revealsAnswers = false
                checkAttemptedAnswers()
            } label: {
                Label("Check answers", systemImage: "checkmark")
            }
            .buttonStyle(StudyButtonStyle())
            .disabled(!hasAttemptedAnswer)
            .opacity(hasAttemptedAnswer ? 1 : 0.5)
            HStack(spacing: 20) {
                Button(revealsAnswers ? "Hide answers" : "Reveal answers") {
                    focusedItem = nil
                    revealsAnswers.toggle()
                    checkedAnswers = [:]
                }
                .frame(minHeight: 44)
                Spacer(minLength: 0)
                Button("Clear", systemImage: "arrow.counterclockwise") {
                    textAnswers = [:]
                    choiceAnswers = [:]
                    checkedAnswers = [:]
                    revealsAnswers = false
                    focusedItem = nil
                }
                .frame(minHeight: 44)
            }
            .font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .studyCard()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedItem = nil }
            }
        }
    }

    private var hasAttemptedAnswer: Bool {
        exercise.items.contains { item in
            item.options.isEmpty
                ? (!item.answers.isEmpty && !MobileCourseAnswerMatcher.normalized(textAnswers[item.id] ?? "").isEmpty)
                : (!item.correctOptionIDs.isEmpty && !(choiceAnswers[item.id] ?? []).isEmpty)
        }
    }

    private func answerBinding(for id: String) -> Binding<String> {
        Binding(get: { textAnswers[id] ?? "" }, set: { value in
            textAnswers[id] = value
            checkedAnswers.removeValue(forKey: id)
            revealsAnswers = false
        })
    }

    private func optionButton(_ option: MobileCourseExerciseOption,
                              item: MobileCourseExerciseItem) -> some View {
        let selected = (choiceAnswers[item.id] ?? []).contains(option.id)
        return Button {
            focusedItem = nil
            var values = choiceAnswers[item.id] ?? []
            if selected { values.remove(option.id) }
            else if item.multiple { values.insert(option.id) }
            else { values = [option.id] }
            choiceAnswers[item.id] = values
            checkedAnswers.removeValue(forKey: item.id)
            revealsAnswers = false
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: item.multiple
                      ? (selected ? "checkmark.square.fill" : "square")
                      : (selected ? "largecircle.fill.circle" : "circle"))
                Text(option.label)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(selected ? Palette.field : Palette.background,
                        in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4)
                .stroke(selected ? Palette.accent : Palette.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func checkAttemptedAnswers() {
        var results: [String: Bool] = [:]
        for item in exercise.items {
            if item.options.isEmpty {
                let answer = textAnswers[item.id] ?? ""
                guard !MobileCourseAnswerMatcher.normalized(answer).isEmpty,
                      !item.answers.isEmpty else { continue }
                results[item.id] = MobileCourseAnswerMatcher.matches(answer, answers: item.answers)
            } else {
                let answer = choiceAnswers[item.id] ?? []
                guard !answer.isEmpty, !item.correctOptionIDs.isEmpty else { continue }
                results[item.id] = MobileCourseAnswerMatcher.matches(
                    optionIDs: answer, correctOptionIDs: item.correctOptionIDs)
            }
        }
        checkedAnswers = results
    }

    private func expectedAnswers(for item: MobileCourseExerciseItem) -> [String] {
        guard !item.options.isEmpty else { return item.answers }
        let correct = Set(item.correctOptionIDs)
        return item.options.filter { correct.contains($0.id) }.map(\.label)
    }
}
