import Foundation

enum WordRules {
    static let headers: Set<String> = ["vocabulary", "words", "word", "english", "unit", "lesson", "chapter", "page", "example", "examples", "contents", "review", "definition", "meaning", "translation", "date"]
    static func replace(_ text: String, _ pattern: String, _ replacement: String) -> String {
        text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
    }
    static func matches(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: .regularExpression) != nil }
    static func unique(_ input: [String]) -> [String] {
        var seen = Set<String>()
        return input.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
    static func edited(_ text: String) -> [String] {
        unique(replace(text, "[\\r\\n,，;；]+", "\n").components(separatedBy: "\n")).filter { $0.count <= 80 }
    }
    static func phrase(_ text: String) -> String? {
        let s = replace(text.lowercased().replacingOccurrences(of: "’", with: "'").replacingOccurrences(of: "…", with: "..."), "\\s+", " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...80).contains(s.count), !headers.contains(s), matches(s, "^[a-z][a-z .'-]*[a-z]$") else { return nil }
        return s
    }
    static func extract(_ text: String) -> [String] {
        var words: [String] = []
        for raw in text.replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n") {
            let columns = matches(raw.trimmingCharacters(in: .whitespaces), "\\t| {2,}")
            for cell in replace(raw, "\\t+| {2,}", "\n").components(separatedBy: "\n") {
                let line = replace(replace(cell.trimmingCharacters(in: .whitespaces), "^[•·●☐□\\-–—]\\s*", ""), "^[（(]?\\d+[）).、:：]?\\s*", "")
                if columns, let p = phrase(line) { words.append(p); continue }
                guard let range = line.range(of: "^[A-Za-z]+(?:[-'][A-Za-z]+)*", options: .regularExpression) else { continue }
                let word = String(line[range]).lowercased(), rest = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                guard word.count >= 2, !headers.contains(word) else { continue }
                if rest.isEmpty || matches(rest, "^(?:[/\\[(（:：—–-]|\\p{Han}|(?:n|v|vt|vi|adj|adv|prep|pron|conj|int|art|num)\\.(?:\\s|$|[^A-Za-z]))") { words.append(word) }
            }
        }
        return Array(unique(words).prefix(1000))
    }
}
