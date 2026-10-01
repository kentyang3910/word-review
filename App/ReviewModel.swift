import SwiftUI
import UIKit
import WidgetKit
import PDFKit

struct ImportDraft: Identifiable {
    let id = UUID()
    var data: Data
    var title: String
    var words: String
}
@MainActor final class ReviewModel: ObservableObject {
    @Published var record = SharedRecord()
    @Published var sourceText = AppConfig.defaultSource
    @Published var busy = false
    @Published var message: String?
    @Published var draft: ImportDraft?
    @Published var showPDF = false
    private var loadedSource = false
    func refresh() {
        do {
            record = try SharedStore().read()
            if !loadedSource { sourceText = record.source.isEmpty ? AppConfig.defaultSource : record.source; loadedSource = true }
        } catch { message = error.localizedDescription }
    }
    func mark(_ word: String, _ token: String) {
        do { try SharedStore().mark(word, token: token); refresh(); WidgetCenter.shared.reloadTimelines(ofKind: AppConfig.widgetKind) }
        catch { message = error.localizedDescription }
    }
    func restart(_ token: String) {
        do { try SharedStore().restart(token: token); refresh(); WidgetCenter.shared.reloadTimelines(ofKind: AppConfig.widgetKind) }
        catch { message = error.localizedDescription }
    }
    func sync(force: Bool) async {
        guard !busy else { return }; busy = true; defer { busy = false; refresh() }
        do { try await SyncEngine.shared.sync(force: force) } catch { message = error.localizedDescription }
    }
    func connect() async {
        do {
            let value = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try SyncEngine.secureURL(value); try SharedStore().setSource(value); BackgroundRefresh.schedule()
            await sync(force: true)
        } catch { message = error.localizedDescription }
    }
    func stopRemote() {
        do { try SharedStore().setSource(""); refresh() } catch { message = error.localizedDescription }
    }
    func importPDF(_ url: URL) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            let result = try await Task.detached(priority: .userInitiated) { () -> ImportDraft in
                let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let count = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard count <= PDFExtractor.maxBytes else { throw ReviewError.message("PDF 超过 20 MB。") }
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let words = try PDFExtractor.extract(data)
                return ImportDraft(data: data, title: url.lastPathComponent, words: words.joined(separator: "\n"))
            }.value
            draft = result
        } catch { message = error.localizedDescription }
    }
    func editCurrent() {
        guard let state = record.state else { return }
        do { let store = try SharedStore(); draft = ImportDraft(data: try Data(contentsOf: store.pdfURL(state)), title: state.title, words: state.words.joined(separator: "\n")) }
        catch { message = error.localizedDescription }
    }
    func save(_ draft: ImportDraft) {
        do {
            let words = WordRules.edited(draft.words)
            try SharedStore().install(data: draft.data, title: draft.title, words: words)
            self.draft = nil; refresh(); WidgetCenter.shared.reloadTimelines(ofKind: AppConfig.widgetKind)
        } catch { message = error.localizedDescription }
    }
    func demo() {
        let words = ["provocative", "child rearing", "in retrospect", "lean on", "round-the-clock", "a piece of cake"]
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)).pdfData { context in
            context.beginPage()
            ("Vocabulary Review" as NSString).draw(at: CGPoint(x: 50, y: 50), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 24)])
            for (i, word) in words.enumerated() { (word as NSString).draw(at: CGPoint(x: 50, y: CGFloat(120 + i * 60)), withAttributes: [.font: UIFont.systemFont(ofSize: 20)]) }
        }
        save(ImportDraft(data: data, title: "示例单词.pdf", words: words.joined(separator: "\n")))
    }
}
