import XCTest
#if SWIFT_PACKAGE
@testable import WordReviewCore
#endif

final class ReviewStateTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_790_827_200)
    func state(_ words: [String] = ["a", "b", "c", "d", "e", "f"]) -> ReviewState {
        ReviewState(deckID: "pdf-v1", title: "test", pdfName: "test", words: words, day: ReviewState.today(now))
    }
    func finish(_ s: inout ReviewState, at start: Date) {
        let token = s.token; var time = start
        while !s.complete { for word in s.slots where !word.isEmpty { XCTAssertTrue(s.mark(word, token: token, now: time)) }; time.addTimeInterval(1); s.settle(time) }
    }
    func testAllRowsRefillInPlace() {
        for row in 0..<3 {
            var s = state(), expected = ["a", "b", "c"]
            XCTAssertTrue(s.mark(expected[row], token: s.token, now: now)); XCTAssertTrue(s.hasFeedback)
            XCTAssertFalse(s.settle(now.addingTimeInterval(0.69))); XCTAssertEqual(s.slots, expected)
            XCTAssertTrue(s.settle(now.addingTimeInterval(0.71))); expected[row] = "d"; XCTAssertEqual(s.slots, expected)
        }
    }
    func testDuplicateClickDoesNotSkip() {
        var s = state(); let token = s.token
        XCTAssertTrue(s.mark("b", token: token, now: now)); XCTAssertFalse(s.mark("b", token: token, now: now.addingTimeInterval(0.1)))
        s.settle(now.addingTimeInterval(1)); XCTAssertFalse(s.mark("b", token: token, now: now.addingTimeInterval(2)))
        XCTAssertEqual(s.checked.count, 1); XCTAssertEqual(s.slots, ["a", "d", "c"])
    }
    func testCannotMarkHiddenWord() { var s = state(); XCTAssertFalse(s.mark("f", token: s.token, now: now)) }
    func testLastThreeCompactEveryRow() {
        for row in 0..<3 {
            var s = state(["a", "b", "c"]), expected = ["a", "b", "c"]
            XCTAssertTrue(s.mark(expected[row], token: s.token, now: now)); XCTAssertEqual(s.slots, expected)
            s.settle(now.addingTimeInterval(1)); expected.remove(at: row); expected.append(""); XCTAssertEqual(s.slots, expected)
        }
    }
    func testLastTwoCompact() {
        for row in 0..<2 { var s = state(["a", "b"]); s.mark(s.slots[row], token: s.token, now: now); s.settle(now.addingTimeInterval(1)); XCTAssertEqual(s.slots, [row == 0 ? "b" : "a", "", ""]) }
    }
    func testTransitionToTailKeepsVisibleOrder() {
        var s = state(["a", "b", "c", "d"]); let token = s.token
        s.mark("b", token: token, now: now); s.settle(now.addingTimeInterval(1)); XCTAssertEqual(s.slots, ["a", "d", "c"])
        s.mark("a", token: token, now: now.addingTimeInterval(2)); s.settle(now.addingTimeInterval(3)); XCTAssertEqual(s.slots, ["d", "c", ""])
    }
    func testPendingFeedbackMovesWithWordAndSurvivesRestart() throws {
        var s = state(["a", "b", "c"]); let token = s.token
        s.mark("a", token: token, now: now); s.mark("b", token: token, now: now.addingTimeInterval(0.3)); s.settle(now.addingTimeInterval(0.8))
        XCTAssertEqual(s.slots, ["b", "c", ""]); XCTAssertGreaterThan(s.until[0], 0); XCTAssertEqual(s.until[1], 0)
        s = try JSONDecoder().decode(ReviewState.self, from: JSONEncoder().encode(s))
        XCTAssertFalse(s.mark("b", token: token, now: now.addingTimeInterval(0.9)))
        s.settle(now.addingTimeInterval(1.1)); XCTAssertEqual(s.slots, ["c", "", ""]); XCTAssertEqual(s.checked.count, 2)
    }
    func testFinalCheckAndTwoRounds() {
        var s = state(["a"]); let old = s.token
        XCTAssertTrue(s.mark("a", token: old, now: now)); XCTAssertEqual(s.rounds, 1); XCTAssertTrue(s.hasFeedback)
        XCTAssertFalse(s.restart(token: s.token, now: now.addingTimeInterval(0.2)))
        XCTAssertTrue(s.restart(token: s.token, now: now.addingTimeInterval(1)))
        XCTAssertFalse(s.mark("a", token: old, now: now.addingTimeInterval(2)))
        finish(&s, at: now.addingTimeInterval(3)); XCTAssertEqual(s.rounds, 2)
    }
    func testDayChangeClearsRoundsAndFeedback() {
        var s = state(); let old = s.token; s.mark("a", token: old, now: now)
        let tomorrow = now.addingTimeInterval(86400); s.rollDay(ReviewState.today(tomorrow))
        XCTAssertFalse(s.hasFeedback); XCTAssertEqual(s.checked.count, 0); XCTAssertEqual(s.rounds, 0)
        XCTAssertFalse(s.mark("a", token: old, now: tomorrow)); XCTAssertEqual(s.slots, ["a", "b", "c"])
    }
    func testDeckChangeRejectsOldToken() { var s = state(); let old = s.token; s.deckID = "different"; XCTAssertFalse(s.mark("a", token: old, now: now)) }
    func testEmptyDeckNeverCompletes() { let s = state([]); XCTAssertFalse(s.complete); XCTAssertTrue(s.valid) }
    func testDamagedSlotsRejected() { var s = state(); s.slots = ["a"]; XCTAssertFalse(s.valid) }
    func testFullDeckTwoRounds() { var s = state(); finish(&s, at: now); XCTAssertEqual(s.rounds, 1); XCTAssertTrue(s.restart(token: s.token, now: now.addingTimeInterval(10))); finish(&s, at: now.addingTimeInterval(11)); XCTAssertEqual(s.rounds, 2) }
}
