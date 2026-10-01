import SwiftUI
import PDFKit

struct ReaderView: View {
    let state: ReviewState?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if let state = state, let store = try? SharedStore() {
                    PDFReader(url: store.pdfURL(state)).ignoresSafeArea(edges: .bottom)
                } else { ContentUnavailableView("还没有 PDF", systemImage: "doc", description: Text("请先导入资料或连接远程链接。")) }
            }
            .navigationTitle(state?.title ?? "完整 PDF").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { if let state = state { Text("已复习 \(state.checked.count)/\(state.words.count)").font(.caption).monospacedDigit() } }
            }
        }
    }
}
private struct PDFReader: UIViewRepresentable {
    var url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView(); view.autoScales = true; view.displayMode = .singlePageContinuous; view.displayDirection = .vertical
        view.document = PDFDocument(url: url); return view
    }
    func updateUIView(_ view: PDFView, context: Context) { if view.document?.documentURL != url { view.document = PDFDocument(url: url) } }
}
