import Foundation

@main struct PDFSmokeCheck {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: "Tests/Fixtures/table.pdf"))
        let words = try PDFExtractor.extract(data, diagnostics: { FileHandle.standardError.write(Data(($0 + "\n").utf8)) })
        FileHandle.standardError.write(Data("EXTRACTED: \(words)\n".utf8))
        guard words.count == 30 else { throw ReviewError.message("Expected 30 fixture words, got \(words.count)") }
    }
}
