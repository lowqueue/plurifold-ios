import XCTest
@testable import Plurifold

final class MobileCourseContentTests: XCTestCase {
    func testOlderLessonWithoutCourseContentStillDecodesItsReadingText() throws {
        let json = """
        {
          "id":"old-course-activity","title":"Greetings","subtitle":"A first conversation",
          "languageCode":"et-EE","languageName":"Estonian","dialect":null,
          "paragraphCount":1,"kind":"course","channel":null,
          "paragraphs":[{"id":"greeting","text":"Tere! Mina olen Kristel.","translation":null,"start":null,"end":null}],
          "media":[],"resources":[],"vocabulary":[]
        }
        """
        let lesson = try JSONDecoder().decode(MobileLesson.self, from: Data(json.utf8))

        XCTAssertNil(lesson.courseContent)
        XCTAssertEqual(lesson.kind, "course")
        XCTAssertEqual(lesson.paragraphs.first?.text, "Tere! Mina olen Kristel.")
        XCTAssertFalse(try XCTUnwrap(lesson.paragraphs.first).text.isEmpty)
    }

    func testDecodesStructuredCourseWithImagesReferenceRowsAndExercise() throws {
        let json = """
        {
          "courseID": "estonian-foundations",
          "courseTitle": "Estonian Foundations",
          "unitTitle": "Greetings",
          "position": 2,
          "total": 8,
          "originalInstruction": "Complete the greeting.",
          "sourceAttribution": "Course companion",
          "images": [{"id":"scene","title":"At school","url":"https://example.com/scene.png"}],
          "sections": [{
            "id":"greetings","title":"Useful phrases","body":"Use these when meeting someone.",
            "rows":[{"id":"hello","text":"Tere!","meaning":"Hello!","note":"A greeting."}]
          }],
          "exercise": {
            "kind":"choice","title":"Choose the greeting",
            "items":[{
              "id":"question-1","prompt":"Hello!","answers":["Tere!"],
              "options":[{"id":"a","label":"Tere!"},{"id":"b","label":"Head aega!"}],
              "correctOptionIDs":["a"],"multiple":false
            }]
          }
        }
        """
        let content = try JSONDecoder().decode(MobileCourseContent.self, from: Data(json.utf8))

        XCTAssertEqual(content.courseID, "estonian-foundations")
        XCTAssertEqual(content.courseTitle, "Estonian Foundations")
        XCTAssertEqual(content.unitTitle, "Greetings")
        XCTAssertEqual(content.position, 2)
        XCTAssertEqual(content.total, 8)
        XCTAssertEqual(content.originalInstruction, "Complete the greeting.")
        XCTAssertEqual(content.sourceAttribution, "Course companion")
        XCTAssertEqual(content.images.first?.url, "https://example.com/scene.png")
        XCTAssertEqual(content.sections.first?.rows.first?.meaning, "Hello!")
        let exercise = try XCTUnwrap(content.exercise)
        XCTAssertEqual(exercise.kind, "choice")
        let item = try XCTUnwrap(exercise.items.first)
        XCTAssertEqual(item.answers, ["Tere!"])
        XCTAssertEqual(item.options.map(\.label), ["Tere!", "Head aega!"])
        XCTAssertEqual(item.correctOptionIDs, ["a"])
        XCTAssertFalse(item.multiple)

        let encoded = try JSONEncoder().encode(content)
        XCTAssertEqual(try JSONDecoder().decode(MobileCourseContent.self, from: encoded), content)
    }

    func testDecodesReferenceMaterialWithoutOptionalFieldsOrExercise() throws {
        let json = """
        {
          "courseID":"georgian-foundations","courseTitle":"Georgian Foundations",
          "position":1,"total":3,"images":[],
          "sections":[{"id":"alphabet","title":"Alphabet","rows":[{"id":"a","text":"ა"}]}]
        }
        """
        let content = try JSONDecoder().decode(MobileCourseContent.self, from: Data(json.utf8))

        XCTAssertNil(content.unitTitle)
        XCTAssertNil(content.originalInstruction)
        XCTAssertNil(content.sourceAttribution)
        XCTAssertNil(content.exercise)
        XCTAssertTrue(content.images.isEmpty)
        let section = try XCTUnwrap(content.sections.first)
        XCTAssertNil(section.body)
        XCTAssertEqual(section.rows.first?.text, "ა")
        XCTAssertNil(section.rows.first?.meaning)
        XCTAssertNil(section.rows.first?.note)
    }

    func testTypedAnswerIgnoresCasePunctuationAndWhitespace() {
        XCTAssertEqual(MobileCourseAnswerMatcher.normalized("  ‘TERE,’\n\tmaailm!  "), "tere maailm")
        XCTAssertTrue(MobileCourseAnswerMatcher.matches("Tere,   maailm!", answers: ["tere maailm"]))
        XCTAssertEqual(MobileCourseAnswerMatcher.normalized("L’amico"), "l amico")
        XCTAssertTrue(MobileCourseAnswerMatcher.matches("L’amico", answers: ["L'amico"]))
        XCTAssertTrue(MobileCourseAnswerMatcher.matches("tere,ma", answers: ["tere ma"]))
        XCTAssertTrue(MobileCourseAnswerMatcher.matches(" head\u{00A0}AEGA. ", answers: ["nägemist", "Head aega!"]))
        XCTAssertFalse(MobileCourseAnswerMatcher.matches("Tere", answers: ["Head aega"]))
    }

    func testCanonicalAccentsMatchButDiacriticsRemainMeaningful() {
        XCTAssertTrue(MobileCourseAnswerMatcher.matches("CAFFE\u{0300}", answers: ["caffè"]))
        XCTAssertEqual(MobileCourseAnswerMatcher.normalized("O\u{0303}UN"), "õun")
        XCTAssertTrue(MobileCourseAnswerMatcher.matches("ÕUN", answers: ["õun"]))
        XCTAssertFalse(MobileCourseAnswerMatcher.matches("oun", answers: ["õun"]))
        XCTAssertFalse(MobileCourseAnswerMatcher.matches("caffe", answers: ["caffè"]))
    }

    func testGeorgianAnswersKeepTheirScript() {
        XCTAssertEqual(MobileCourseAnswerMatcher.normalized("  გამარჯობა!  "), "გამარჯობა")
        XCTAssertTrue(MobileCourseAnswerMatcher.matches("გამარჯობა!", answers: ["გამარჯობა"]))
        XCTAssertFalse(MobileCourseAnswerMatcher.matches("ნახვამდის", answers: ["გამარჯობა"]))
    }

    func testEmptyAndPunctuationOnlyTypedAnswersAreNeverCorrect() {
        for answer in ["", " \n\t ", "…!?", "‘’"] {
            XCTAssertFalse(MobileCourseAnswerMatcher.matches(answer, answers: ["", "...", " "]))
        }
        XCTAssertFalse(MobileCourseAnswerMatcher.matches("Tere", answers: []))
    }

    func testChoiceRequiresExactNonemptyAnswerSetRegardlessOfOrder() {
        XCTAssertTrue(MobileCourseAnswerMatcher.matches(optionIDs: ["b", "a"], correctOptionIDs: ["a", "b"]))
        XCTAssertTrue(MobileCourseAnswerMatcher.matches(optionIDs: ["a"], correctOptionIDs: ["a"]))
        XCTAssertFalse(MobileCourseAnswerMatcher.matches(optionIDs: [], correctOptionIDs: []))
        XCTAssertFalse(MobileCourseAnswerMatcher.matches(optionIDs: [], correctOptionIDs: ["a"]))
        XCTAssertFalse(MobileCourseAnswerMatcher.matches(optionIDs: ["a"], correctOptionIDs: []))
        XCTAssertFalse(MobileCourseAnswerMatcher.matches(optionIDs: ["a"], correctOptionIDs: ["a", "b"]))
        XCTAssertFalse(MobileCourseAnswerMatcher.matches(optionIDs: ["a", "b"], correctOptionIDs: ["a"]))
    }
}
