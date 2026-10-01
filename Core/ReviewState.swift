import Foundation

struct ReviewState: Codable, Equatable {
    var deckID: String
    var title: String
    var pdfName: String
    var day: String
    var words: [String]
    var checked: Set<String> = []
    var rounds = 0
    var slots = ["", "", ""]
    var until: [TimeInterval] = [0, 0, 0]
    static let feedbackSeconds = 0.7

    init(deckID: String, title: String, pdfName: String, words: [String], day: String) {
        self.deckID = deckID; self.title = title; self.pdfName = pdfName; self.day = day
        self.words = WordRules.unique(words)
        fill()
    }
    static func today(_ date: Date = Date()) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
    var token: String { "\(deckID):\(day):\(rounds)" }
    var complete: Bool { !words.isEmpty && checked.count == words.count }
    var hasFeedback: Bool { until.contains { $0 > 0 } }
    var remaining: Int { words.count - checked.count }
    var nextDeadline: Date? { until.filter { $0 > 0 }.min().map(Date.init(timeIntervalSince1970:)) }
    mutating func fill() {
        for i in 0..<3 where slots[i].isEmpty {
            if let word = words.first(where: { !checked.contains($0) && !slots.contains($0) }) { slots[i] = word }
        }
    }
    mutating func resetSlots() { slots = ["", "", ""]; until = [0, 0, 0]; fill() }
    mutating func rollDay(_ today: String) {
        if day != today { day = today; checked = []; rounds = 0; resetSlots() }
    }
    @discardableResult mutating func settle(_ date: Date) -> Bool {
        var changed = false
        for i in 0..<3 where until[i] > 0 && until[i] <= date.timeIntervalSince1970 {
            slots[i] = ""; until[i] = 0; changed = true
        }
        if changed { fill() }
        if remaining <= 3 {
            var target = 0
            for i in 0..<3 where !slots[i].isEmpty {
                if i != target {
                    slots[target] = slots[i]; until[target] = until[i]
                    slots[i] = ""; until[i] = 0; changed = true
                }
                target += 1
            }
        }
        return changed
    }
    @discardableResult mutating func mark(_ word: String, token: String, now: Date = Date()) -> Bool {
        rollDay(Self.today(now)); settle(now)
        guard token == self.token, !complete, !word.isEmpty, !checked.contains(word),
              let index = slots.firstIndex(of: word) else { return false }
        checked.insert(word); until[index] = now.timeIntervalSince1970 + Self.feedbackSeconds
        if complete { rounds += 1 }
        return true
    }
    @discardableResult mutating func restart(token: String, now: Date = Date()) -> Bool {
        rollDay(Self.today(now)); settle(now)
        guard token == self.token, complete, !hasFeedback else { return false }
        checked = []; resetSlots(); return true
    }
    /// Reject damaged shared state rather than letting a widget index outside its three slots.
    var valid: Bool {
        slots.count == 3 && until.count == 3 && rounds >= 0 && words.count <= 1000 &&
        Set(words).count == words.count && checked.isSubset(of: Set(words)) &&
        slots.allSatisfy { $0.isEmpty || words.contains($0) } &&
        Set(slots.filter { !$0.isEmpty }).count == slots.filter { !$0.isEmpty }.count &&
        until.allSatisfy { $0.isFinite && $0 >= 0 }
    }
}
