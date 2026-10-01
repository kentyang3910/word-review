import XCTest
import Foundation

final class PDFAndStoreTests: XCTestCase {
    func testResignedGroupUsesProvisionedIdentifier() {
        XCTAssertEqual(AppConfig.resolvedGroup(configured: "group.review", signedGroups: ["group.review.TEAM"]), "group.review.TEAM")
        XCTAssertEqual(AppConfig.resolvedGroup(configured: "group.review", signedGroups: []), "group.review")
    }
    func testAmbiguousResignedGroupsDoNotSelectUnrelatedContainer() {
        XCTAssertEqual(AppConfig.resolvedGroup(configured: "group.review", signedGroups: ["group.other", "group.another"]), "group.review")
        XCTAssertEqual(AppConfig.resolvedGroup(configured: "group.review", signedGroups: ["group.other", "group.review.TEAM"]), "group.review.TEAM")
    }
    func fixture() throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "table", withExtension: "pdf"))
        return try Data(contentsOf: url)
    }
    func testPDFKitExtractsTwoColumnPhrasesAndDeduplicatesPages() throws {
        let expected = "provocative|child rearing|anything less than|either ... or|measured|past-tense|soul-crushingly|in the moment|dampen|cover|newsstands|adoptive|practically|celebrates|procreation|is it any wonder that|is equivalent to|provoked|are bothered with|present|unrealistic|lean on|on their own|round-the-clock|a piece of cake|dumb|glamorous|haircut|in the same way that|in retrospect".components(separatedBy: "|")
        XCTAssertEqual(try PDFExtractor.extract(fixture()), expected)
    }
    func testInvalidPDFRejected() { XCTAssertThrowsError(try PDFExtractor.extract(Data("not a pdf".utf8))) }
    func testSameContentPreservesProgressAndChangedDeckResets() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SharedStore(root: root), data = try fixture()
        try store.install(data: data, title: "Test", words: ["one", "two", "three", "four"])
        let initial = try XCTUnwrap(store.read().state); try store.mark("two", token: initial.token)
        try store.install(data: data, title: "Test", words: initial.words)
        XCTAssertEqual(try store.read().state?.checked, ["two"])
        try store.install(data: data, title: "Test", words: ["changed"])
        XCTAssertEqual(try store.read().state?.checked.count, 0)
    }
    func testOldSourceCannotReplaceNewSource() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SharedStore(root: root)
        try store.setSource("https://example.com/a.json"); let original = try store.read()
        try store.setSource("https://example.com/b.json")
        XCTAssertThrowsError(try store.install(data: fixture(), title: "old", words: ["old"], remote: original))
        XCTAssertNil(try store.read().state)
    }
}
