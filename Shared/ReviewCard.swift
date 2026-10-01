import SwiftUI
import AppIntents

struct ReviewCard: View {
    var state: ReviewState?
    var widget = false
    var onMark: (String, String) -> Void = { _, _ in }
    var onRestart: (String) -> Void = { _ in }
    var openPDF: () -> Void = {}
    private let ink = Color(red: 0.09, green: 0.14, blue: 0.22)
    private let green = Color(red: 0.12, green: 0.65, blue: 0.41)
    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text("今日单词").font(.system(size: 14, weight: .bold))
                Spacer()
                Text(state.map { "已复习 \($0.checked.count)/\($0.words.count)" } ?? "待导入")
                    .font(.system(size: 12)).monospacedDigit()
            }.frame(height: 22)
            if let state = state {
                if state.complete && !state.hasFeedback {
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark.circle").font(.title).foregroundStyle(green)
                    Text("今日单词已复习 \(state.rounds) 次").font(.system(size: 16, weight: .medium))
                    if widget {
                        Button(intent: RestartReviewIntent(token: state.token)) { restartLabel }.buttonStyle(.plain)
                    } else {
                        Button { onRestart(state.token) } label: { restartLabel }.buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                } else {
                    ForEach(0..<3, id: \.self) { index in
                        let word = state.slots[index], checked = state.until[index] > 0
                        HStack(spacing: 8) {
                            if widget {
                                Link(destination: AppConfig.readerURL) { wordLabel(word, checked: checked) }
                            } else {
                                Button(action: openPDF) { wordLabel(word, checked: checked) }.buttonStyle(.plain)
                            }
                            if widget {
                                Button(intent: MarkWordIntent(word: word, token: state.token)) { checkbox(checked) }.buttonStyle(.plain)
                                    .disabled(word.isEmpty || checked).invalidatableContent()
                                    .accessibilityLabel(checked ? "已认识 \(word)" : "认识 \(word)")
                            } else {
                                Button { onMark(word, state.token) } label: { checkbox(checked) }.buttonStyle(.plain)
                                    .disabled(word.isEmpty || checked).accessibilityLabel(checked ? "已认识 \(word)" : "认识 \(word)")
                            }
                        }.frame(maxHeight: .infinity).opacity(word.isEmpty ? 0 : 1)
                        if index < 2 { Rectangle().fill(ink.opacity(0.07)).frame(height: 0.5) }
                    }
                }
            } else {
                Spacer()
                Text("打开词页复习\n导入 PDF 或连接资料链接").multilineTextAlignment(.center).font(.subheadline)
                Spacer()
            }
        }.foregroundStyle(ink).environment(\.layoutDirection, .leftToRight)
    }
    private var restartLabel: some View {
        Text("重新复习").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
            .padding(.horizontal, 22).padding(.vertical, 8).background(green, in: Capsule())
    }
    private func wordLabel(_ word: String, checked: Bool) -> some View {
        Text(word).font(.system(size: word.count > 22 ? 16 : word.count > 15 ? 19 : 22))
            .lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .foregroundStyle(ink.opacity(checked ? 0.6 : 1))
            .overlay { if checked { Rectangle().fill(ink.opacity(0.33)).frame(height: 0.7) } }
            .contentShape(Rectangle()).animation(.easeInOut(duration: 0.2), value: word)
    }
    private func checkbox(_ checked: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).stroke(checked ? green : ink, lineWidth: 1.4).frame(width: 23, height: 23)
            if checked { Image(systemName: "checkmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(green) }
        }.frame(width: 44).frame(maxHeight: .infinity).contentShape(Rectangle())
    }
}
