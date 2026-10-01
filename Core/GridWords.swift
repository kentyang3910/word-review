import Foundation

enum GridWords {
    struct Glyph { var text: String; var x: Double; var y: Double; var width: Double; var space: Double }
    struct Line {
        var x1: Double; var y1: Double; var x2: Double; var y2: Double
        init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
            self.x1 = min(x1, x2); self.x2 = max(x1, x2); self.y1 = min(y1, y2); self.y2 = max(y1, y2)
        }
    }
    static func unique(_ values: [Double]) -> [Double] {
        values.sorted().reduce(into: []) { out, v in if out.last.map({ v - $0 > 2 }) ?? true { out.append(v) } }
    }
    static func cell(_ glyphs: [Glyph], _ left: Double, _ right: Double, _ top: Double, _ bottom: Double) -> String {
        let selected = glyphs.filter { $0.x + $0.width / 2 > left && $0.x + $0.width / 2 < right && $0.y > top && $0.y < bottom }.sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
        var rows: [[Glyph]] = []
        for g in selected {
            if rows.last.map({ abs($0[0].y - g.y) > 2 }) ?? true { rows.append([]) }
            rows[rows.count - 1].append(g)
        }
        var strings: [String] = []
        for row in rows {
            var s = ""; var previous: Glyph?
            for g in row.sorted(by: { $0.x < $1.x }) {
                if let prev = previous {
                    let width = max(prev.width / Double(max(1, prev.text.count)), g.width / Double(max(1, g.text.count)))
                    let threshold = max(0.8, min(abs(g.space) * 0.45, width * 0.3))
                    if g.x - (prev.x + prev.width) > threshold && !s.hasSuffix(" ") { s += " " }
                }
                s += g.text; previous = g
            }
            strings.append(s)
        }
        return WordRules.replace(strings.joined(separator: " "), "\\s+", " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func extract(_ glyphs: [Glyph], _ lines: [Line]) -> [String] {
        let xs = unique(lines.filter { $0.x2 - $0.x1 < 1.5 && $0.y2 - $0.y1 > 5 }.map(\.x1))
        let ys = unique(lines.filter { $0.y2 - $0.y1 < 1.5 && $0.x2 - $0.x1 > 5 }.map(\.y1))
        guard xs.count >= 2, ys.count >= 2 else { return [] }
        var result: [String] = []
        func horizontal(_ a: Double, _ b: Double, _ y: Double) -> Bool { lines.contains { $0.y2 - $0.y1 < 1.5 && abs($0.y1 - y) < 2 && $0.x1 <= a + 2 && $0.x2 >= b - 2 } }
        func vertical(_ x: Double, _ a: Double, _ b: Double) -> Bool { lines.contains { $0.x2 - $0.x1 < 1.5 && abs($0.x1 - x) < 2 && $0.y1 <= a + 2 && $0.y2 >= b - 2 } }
        for col in 0..<(xs.count - 1) {
            var english = false
            for row in 0..<(ys.count - 1) {
                let l = xs[col], r = xs[col + 1], t = ys[row], b = ys[row + 1]
                guard horizontal(l, r, t), horizontal(l, r, b), vertical(l, t, b), vertical(r, t, b) else { english = false; continue }
                let text = cell(glyphs, l, r, t, b)
                if ["english", "word", "words", "vocabulary", "phrase", "phrases"].contains(text.lowercased()) { english = true; continue }
                if english, let phrase = WordRules.phrase(text) { result.append(phrase) }
            }
        }
        return Array(WordRules.unique(result).prefix(1000))
    }
}
