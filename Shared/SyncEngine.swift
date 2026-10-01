import Foundation
import WidgetKit

private final class HTTPSRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url.flatMap { try? SyncEngine.secureURL($0.absoluteString) } == nil ? nil : request)
    }
}
actor SyncEngine {
    static let shared = SyncEngine()
    private var running = false
    private struct Manifest: Decodable { var title: String?; var pdf_url: String; var words: [String]? }
    nonisolated static func secureURL(_ value: String) throws -> URL {
        guard let url = URL(string: value), url.scheme?.lowercased() == "https", url.host != nil, url.user == nil, url.password == nil else {
            throw ReviewError.message("请填写可以直接访问的 HTTPS PDF 或 deck.json 链接。")
        }
        return url
    }
    private func fetch(_ url: URL, limit: Int, etag: String? = nil, modified: String? = nil) async throws -> (Data, HTTPURLResponse) {
        let config = URLSessionConfiguration.ephemeral; config.timeoutIntervalForRequest = 20; config.timeoutIntervalForResource = 50
        let session = URLSession(configuration: config, delegate: HTTPSRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url); request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("WordReview-iOS/0.1", forHTTPHeaderField: "User-Agent")
        request.setValue(etag, forHTTPHeaderField: "If-None-Match"); request.setValue(modified, forHTTPHeaderField: "If-Modified-Since")
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw ReviewError.message("无效服务器响应。") }
        guard response.statusCode == 200 || response.statusCode == 304 else { throw ReviewError.message("服务器返回 \(response.statusCode)，保留旧资料。") }
        guard response.expectedContentLength <= Int64(limit) else { throw ReviewError.message("远程文件超过大小限制。") }
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit else { throw ReviewError.message("远程文件超过大小限制。") }
            data.append(byte)
        }
        return (data, response)
    }
    func sync(force: Bool = false) async throws {
        guard !running else { return }; running = true; defer { running = false }
        let store = try SharedStore(), initial = try store.read()
        guard !initial.source.isEmpty else { return }
        if !force, let last = initial.lastSync, Date().timeIntervalSince(last) < 15 * 60 { return }
        do {
            let url = try Self.secureURL(initial.source)
            let isManifest = url.path.lowercased().hasSuffix(".json")
            let (data, response) = try await fetch(url, limit: isManifest ? 256 * 1024 : PDFExtractor.maxBytes, etag: initial.etag, modified: initial.modified)
            if response.statusCode == 304 { try recordUnchanged(store, initial); return }
            var pdf = data, title = "远程单词.pdf", words: [String]?, manifestHash: String?
            if isManifest || response.mimeType?.contains("json") == true {
                guard data.count <= 256 * 1024 else { throw ReviewError.message("资料清单过大。") }
                manifestHash = SharedStore.digest(data)
                if manifestHash == initial.manifestHash { try recordUnchanged(store, initial); return }
                let manifest = try JSONDecoder().decode(Manifest.self, from: data)
                guard let relative = URL(string: manifest.pdf_url, relativeTo: response.url ?? url)?.absoluteURL else { throw ReviewError.message("清单的 PDF 地址无效。") }
                let pdfURL = try Self.secureURL(relative.absoluteString)
                (pdf, _) = try await fetch(pdfURL, limit: PDFExtractor.maxBytes)
                title = manifest.title ?? title; words = manifest.words.map(WordRules.unique)
            }
            let extracted = try PDFExtractor.extract(pdf)
            try store.install(data: pdf, title: title, words: words ?? extracted, remote: initial,
                              etag: response.value(forHTTPHeaderField: "ETag"), modified: response.value(forHTTPHeaderField: "Last-Modified"), manifestHash: manifestHash)
            WidgetCenter.shared.reloadTimelines(ofKind: AppConfig.widgetKind)
        } catch {
            try? store.transaction { record in if record.sourceGeneration == initial.sourceGeneration { record.status = "同步失败：\(error.localizedDescription)" } }
            throw error
        }
    }
    private func recordUnchanged(_ store: SharedStore, _ initial: SharedRecord) throws {
        try store.transaction { record in
            if record.sourceGeneration == initial.sourceGeneration { record.lastSync = Date(); record.status = "已是最新资料" }
        }
    }
}
