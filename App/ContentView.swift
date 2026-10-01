import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: ReviewModel
    @State private var importing = false
    @State private var help = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("把复习放到桌面，一次记住三个单词。").foregroundStyle(.secondary)
                    if let s = model.record.state { Text("\(s.title) · \(s.words.count) 个词条").font(.subheadline).foregroundStyle(.secondary) }
                    ReviewCard(state: model.record.state, onMark: model.mark, onRestart: model.restart, openPDF: { model.showPDF = true })
                        .padding(16).frame(height: 200).background(.white, in: RoundedRectangle(cornerRadius: 24))
                    HStack {
                        Button("添加桌面小组件") { help = true }.buttonStyle(.borderedProminent)
                        Button("打开完整 PDF") { model.showPDF = true }.buttonStyle(.bordered).disabled(model.record.state == nil)
                    }
                    GroupBox("我的 PDF") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("导入后可校对单词和短语。图片扫描版需要手动填写词表。").font(.footnote).foregroundStyle(.secondary)
                            Button("导入 PDF") { importing = true }
                            Button("校对当前词表", action: model.editCurrent).disabled(model.record.state == nil)
                            if model.record.state == nil { Button("体验示例", action: model.demo) }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GroupBox("远程更新") {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("https://…/deck.json", text: $model.sourceText)
                                .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).textFieldStyle(.roundedBorder)
                            HStack {
                                Button("连接并同步") { Task { await model.connect() } }
                                Spacer()
                                Button("立即检查更新") { Task { await model.sync(force: true) } }.disabled(model.record.source.isEmpty)
                            }
                            Button("停止远程同步", action: model.stopRemote).disabled(model.record.source.isEmpty)
                            Text(model.record.status).font(.footnote).foregroundStyle(.secondary)
                            Text("新 PDF 或新词表会重置本轮进度和今日次数。后台检查由 iOS 安排，断网保留已下载资料。").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Text("认识：点右侧方框。超过三个时原位补词，最后三个向上补位。\n不认识：点单词查看完整 PDF。全部勾选后累计一次，可重新复习。\niPhone 小组件由系统刷新，勾选反馈时长可能与应用内不同。").font(.footnote).foregroundStyle(.secondary)
                }.padding(20).disabled(model.busy)
            }.background(Color(red: 0.95, green: 0.97, blue: 0.98)).navigationTitle("词页复习")
                .overlay { if model.busy { ProgressView("正在处理…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)) } }
        }
        .preferredColorScheme(.light)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { result in
            switch result { case .success(let url): Task { await model.importPDF(url) }; case .failure(let error): model.message = error.localizedDescription }
        }
        .sheet(item: $model.draft) { draft in WordEditor(draft: draft, save: model.save) }
        .sheet(isPresented: $model.showPDF) { ReaderView(state: model.record.state) }
        .alert("添加到桌面", isPresented: $help) {
            Button("知道了", role: .cancel) {}
        } message: { Text("回到主屏幕，长按空白处，进入“编辑”或“添加小组件”，搜索“词页复习”，选择中号或大号，再点“添加小组件”。") }
        .alert("提示", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("知道了", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
        .task(id: model.record.state?.nextDeadline) {
            guard let deadline = model.record.state?.nextDeadline else { return }
            do { try await Task.sleep(for: .seconds(max(0.05, deadline.timeIntervalSinceNow + 0.05))) } catch { return }
            model.refresh()
        }
    }
}
private struct WordEditor: View {
    @State var draft: ImportDraft
    var save: (ImportDraft) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                TextField("资料名称", text: $draft.title).textFieldStyle(.roundedBorder)
                Text("每行一个词或短语。保存后停止远程同步；词表变化会重置复习进度。").font(.footnote).foregroundStyle(.secondary)
                TextEditor(text: $draft.words).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("\(WordRules.edited(draft.words).count) 个词条").font(.footnote)
            }.padding().navigationTitle("校对词表")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("保存") { save(draft) }.disabled(WordRules.edited(draft.words).isEmpty) } }
        }
    }
}
