import Foundation
import PDFKit
import CoreGraphics

enum PDFExtractor {
    static let maxBytes = 20 * 1024 * 1024
    static func extract(_ data: Data, diagnostics: ((String) -> Void)? = nil) throws -> [String] {
        guard data.count <= maxBytes, data.starts(with: Data("%PDF-".utf8)), let document = PDFDocument(data: data), !document.isLocked else {
            throw ReviewError.message("请选择有效、未加密且不超过 20 MB 的 PDF。")
        }
        guard document.pageCount > 0, document.pageCount <= 50 else { throw ReviewError.message("支持 1 至 50 页 PDF。") }
        var result: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let crop = page.bounds(for: .cropBox), text = page.string ?? ""
            let lines = page.rotation == 0 ? PDFBorders.lines(page) : []
            // PDFKit's page.string can insert line breaks that don't correspond to
            // characterBounds indices. Select each bounded cell directly instead.
            let table = GridWords.extract(lines) { left, right, top, bottom in
                let rect = CGRect(x: crop.minX + left, y: crop.maxY - bottom, width: right - left, height: bottom - top).insetBy(dx: 1, dy: 1)
                let value = page.selection(for: rect)?.string ?? ""
                diagnostics?("cell \(left),\(top): \(value)")
                return value
            }
            diagnostics?("page=\(index) borders=\(lines.count) words=\(table.count)")
            result.append(contentsOf: table.isEmpty ? WordRules.extract(text) : table)
        }
        return Array(WordRules.unique(result).prefix(1000))
    }
}

/// Collects painted table borders in PDF coordinates. It never executes PDF actions.
private final class PDFBorders {
    var transform = CGAffineTransform.identity
    var stack: [CGAffineTransform] = []
    var current = CGPoint.zero, start = CGPoint.zero
    var path: [GridWords.Line] = [], output: [GridWords.Line] = []
    let crop: CGRect
    init(crop: CGRect) { self.crop = crop }
    func move(_ p: CGPoint) { current = p.applying(transform); start = current }
    func line(_ p: CGPoint) { segment(to: p.applying(transform)) }
    func segment(to p: CGPoint) {
        if abs(current.x - p.x) < 1.5 || abs(current.y - p.y) < 1.5 {
            path.append(.init(current.x - crop.minX, crop.maxY - current.y, p.x - crop.minX, crop.maxY - p.y))
        }
        current = p
    }
    func close() { segment(to: start) }
    func stroke() { output.append(contentsOf: path); path.removeAll(keepingCapacity: true) }
    static func state(_ info: UnsafeMutableRawPointer?) -> PDFBorders { Unmanaged<PDFBorders>.fromOpaque(info!).takeUnretainedValue() }
    static func numbers(_ scanner: CGPDFScannerRef, _ count: Int) -> [CGFloat]? {
        var out: [CGFloat] = []
        for _ in 0..<count { var n: CGPDFReal = 0; guard CGPDFScannerPopNumber(scanner, &n) else { return nil }; out.append(n) }
        return Array(out.reversed())
    }
    static func lines(_ page: PDFPage) -> [GridWords.Line] {
        guard let ref = page.pageRef, let table = CGPDFOperatorTableCreate() else { return [] }
        defer { CGPDFOperatorTableRelease(table) }
        let collector = PDFBorders(crop: page.bounds(for: .cropBox))
        CGPDFOperatorTableSetCallback(table, "q") { _, info in let s = PDFBorders.state(info); s.stack.append(s.transform) }
        CGPDFOperatorTableSetCallback(table, "Q") { _, info in let s = PDFBorders.state(info); if let t = s.stack.popLast() { s.transform = t } }
        CGPDFOperatorTableSetCallback(table, "cm") { scanner, info in
            guard let n = PDFBorders.numbers(scanner, 6) else { return }; let s = PDFBorders.state(info)
            s.transform = CGAffineTransform(a: n[0], b: n[1], c: n[2], d: n[3], tx: n[4], ty: n[5]).concatenating(s.transform)
        }
        CGPDFOperatorTableSetCallback(table, "m") { scanner, info in if let n = PDFBorders.numbers(scanner, 2) { PDFBorders.state(info).move(CGPoint(x: n[0], y: n[1])) } }
        CGPDFOperatorTableSetCallback(table, "l") { scanner, info in if let n = PDFBorders.numbers(scanner, 2) { PDFBorders.state(info).line(CGPoint(x: n[0], y: n[1])) } }
        CGPDFOperatorTableSetCallback(table, "h") { _, info in PDFBorders.state(info).close() }
        CGPDFOperatorTableSetCallback(table, "re") { scanner, info in
            guard let n = PDFBorders.numbers(scanner, 4) else { return }; let s = PDFBorders.state(info)
            s.move(CGPoint(x: n[0], y: n[1])); s.line(CGPoint(x: n[0] + n[2], y: n[1])); s.line(CGPoint(x: n[0] + n[2], y: n[1] + n[3])); s.line(CGPoint(x: n[0], y: n[1] + n[3])); s.close()
        }
        CGPDFOperatorTableSetCallback(table, "c") { scanner, info in if let n = PDFBorders.numbers(scanner, 6) { let s = PDFBorders.state(info); s.current = CGPoint(x: n[4], y: n[5]).applying(s.transform) } }
        for name in ["v", "y"] { CGPDFOperatorTableSetCallback(table, name) { scanner, info in if let n = PDFBorders.numbers(scanner, 4) { let s = PDFBorders.state(info); s.current = CGPoint(x: n[2], y: n[3]).applying(s.transform) } } }
        for name in ["S", "B", "B*"] { CGPDFOperatorTableSetCallback(table, name) { _, info in PDFBorders.state(info).stroke() } }
        for name in ["s", "b", "b*"] { CGPDFOperatorTableSetCallback(table, name) { _, info in let s = PDFBorders.state(info); s.close(); s.stroke() } }
        for name in ["n", "f", "F", "f*"] { CGPDFOperatorTableSetCallback(table, name) { _, info in PDFBorders.state(info).path.removeAll(keepingCapacity: true) } }
        let stream = CGPDFContentStreamCreateWithPage(ref)
        defer { CGPDFContentStreamRelease(stream) }
        let scanner = CGPDFScannerCreate(stream, table, Unmanaged.passUnretained(collector).toOpaque())
        defer { CGPDFScannerRelease(scanner) }
        guard CGPDFScannerScan(scanner) else { return [] }
        return collector.output
    }
}
