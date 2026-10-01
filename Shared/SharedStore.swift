import Foundation
import CryptoKit
import Darwin

enum ReviewError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}
enum AppConfig {
    static let widgetKind = "WordReviewWidget"
    static let readerURL = URL(string: "wordreview://reader")!
    static let defaultSource = "https://kentyang3910.github.io/word-review/deck.json"
    static var groupID: String {
        let configured = (Bundle.main.object(forInfoDictionaryKey: "ReviewAppGroup") as? String) ?? "group.cn.wordreview.ios"
        return resolvedGroup(configured: configured, signedGroups: Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? [])
    }
    /// AltStore writes the provisioned App Groups into each bundle after re-signing.
    /// This app declares exactly one shared group; never pick an arbitrary group if several are present.
    static func resolvedGroup(configured: String, signedGroups: [String]) -> String {
        let groups = Array(Set(signedGroups.filter { $0.hasPrefix("group.") }))
        if groups.count == 1 { return groups[0] }
        if groups.contains(configured) { return configured }
        let matches = groups.filter { $0.hasPrefix(configured + ".") }
        return matches.count == 1 ? matches[0] : configured
    }
    static var backgroundID: String { (Bundle.main.object(forInfoDictionaryKey: "ReviewRefreshIdentifier") as? String) ?? "cn.wordreview.ios.refresh" }
}
struct SharedRecord: Codable {
    var state: ReviewState?
    var source = ""
    var sourceGeneration = UUID().uuidString
    var lastSync: Date?
    var status = "导入 PDF 或连接远程资料"
    var etag: String?
    var modified: String?
    var manifestHash: String?
}
struct SharedStore {
    let root: URL
    init(root: URL) { self.root = root }
    init() throws {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.groupID) else {
            throw ReviewError.message("共享资料空间不可用，请检查应用和小组件的 App Groups 签名配置。")
        }
        self.root = root
    }
    /// A process-wide serial actor is insufficient: app and widget are separate processes.
    /// flock protects the entire read-modify-atomic-write transaction across both.
    func transaction<T>(_ block: (inout SharedRecord) throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fd = open(root.appendingPathComponent("review.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw ReviewError.message("无法打开资料锁。") }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw ReviewError.message("无法锁定资料。") }
        defer { flock(fd, LOCK_UN) }
        let url = root.appendingPathComponent("review.json")
        var record: SharedRecord
        if FileManager.default.fileExists(atPath: url.path) {
            record = try JSONDecoder().decode(SharedRecord.self, from: Data(contentsOf: url))
            guard record.state?.valid ?? true else { throw ReviewError.message("复习状态损坏；请重新导入资料。") }
        } else { record = SharedRecord() }
        record.state?.rollDay(ReviewState.today()); record.state?.settle(Date())
        let result = try block(&record)
        try JSONEncoder().encode(record).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return result
    }
    func read() throws -> SharedRecord { try transaction { $0 } }
    func mark(_ word: String, token: String) throws { try transaction { record in _ = record.state?.mark(word, token: token) } }
    func restart(token: String) throws { try transaction { record in _ = record.state?.restart(token: token) } }
    func setSource(_ value: String) throws {
        try transaction { record in
            if record.source != value {
                record.source = value; record.sourceGeneration = UUID().uuidString
                record.etag = nil; record.modified = nil; record.manifestHash = nil; record.lastSync = nil
            }
            record.status = value.isEmpty ? "使用本地资料" : "等待同步"
        }
    }
    func pdfURL(_ state: ReviewState) -> URL { root.appendingPathComponent(state.pdfName).appendingPathExtension("pdf") }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    func install(data: Data, title: String, words: [String], remote: SharedRecord? = nil, etag: String? = nil, modified: String? = nil, manifestHash: String? = nil) throws {
        let words = WordRules.unique(words)
        guard !words.isEmpty, words.count <= 1000 else { throw ReviewError.message("请提供 1 至 1000 个词条。") }
        let hash = Self.digest(data), id = hash + "-" + String(Self.digest(Data(words.joined(separator: "\n").utf8)).prefix(12))
        try transaction { record in
            if let remote = remote, record.sourceGeneration != remote.sourceGeneration { throw ReviewError.message("资料来源已更改，已忽略此次下载。") }
            let pdf = root.appendingPathComponent(hash).appendingPathExtension("pdf")
            if !FileManager.default.fileExists(atPath: pdf.path) { try data.write(to: pdf, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
            if record.state?.deckID != id { record.state = ReviewState(deckID: id, title: title, pdfName: hash, words: words, day: ReviewState.today()) }
            if remote == nil { record.source = ""; record.sourceGeneration = UUID().uuidString }
            record.etag = etag; record.modified = modified; record.manifestHash = manifestHash
            record.lastSync = Date(); record.status = remote == nil ? "本地资料已保存" : "同步成功"
        }
    }
}
