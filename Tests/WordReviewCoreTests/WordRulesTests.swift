import XCTest
#if SWIFT_PACKAGE
@testable import WordReviewCore
#endif
final class WordRulesTests: XCTestCase {
    func testPhrasesAndColumns() { XCTAssertEqual(WordRules.extract("child rearing  in retrospect"), ["child rearing", "in retrospect"]) }
    func testDefinitionsNotSentences() { XCTAssertEqual(WordRules.extract("Vocabulary\n1. abandon v. 放弃\nThey abandon the plan.\nresilient /abc/ 有韧性的"), ["abandon", "resilient"]) }
    func testEditedWordsDeduplicate() { XCTAssertEqual(WordRules.edited("look up\nacquire\nACQUIRE"), ["look up", "acquire"]) }
    func testEllipsisAndHyphen() { XCTAssertEqual(WordRules.phrase("either … or"), "either ... or"); XCTAssertEqual(WordRules.phrase("round-the-clock"), "round-the-clock"); XCTAssertNil(WordRules.phrase("A sentence.")) }
    func testGridKeepsPhrasesAndSkipsMeanings() {
        var lines: [GridWords.Line] = []
        for x in stride(from: 0.0, through: 400, by: 100) { lines.append(.init(x, 0, x, 75)) }
        for y in stride(from: 0.0, through: 75, by: 25) { lines.append(.init(0, y, 400, y)) }
        func g(_ s: String, _ x: Double, _ y: Double) -> GridWords.Glyph { .init(text: s, x: x, y: y, width: 80, space: 4) }
        let glyphs = [g("English", 5, 15), g("Meaning", 105, 15), g("English", 205, 15), g("child rearing", 5, 40), g("bringing up children", 105, 40), g("is it any", 205, 34), g("wonder that", 205, 45), g("either ... or", 5, 65), g("present", 205, 65)]
        XCTAssertEqual(GridWords.extract(glyphs, lines), ["child rearing", "either ... or", "is it any wonder that", "present"])
    }
    func testSubsetFontSpacing() {
        let glyphs: [GridWords.Glyph] = [.init(text: "rough", x: 5, y: 15, width: 25, space: 10), .init(text: "guide", x: 32.5, y: 15, width: 25, space: 10)]
        XCTAssertEqual(GridWords.cell(glyphs, 0, 100, 0, 25), "rough guide")
    }
}
