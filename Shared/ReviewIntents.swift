import AppIntents
import WidgetKit

struct MarkWordIntent: AppIntent {
    static var title: LocalizedStringResource = "认识这个单词"
    static var openAppWhenRun = false
    @Parameter(title: "单词") var word: String
    @Parameter(title: "复习版本") var token: String
    init() {}
    init(word: String, token: String) { self.word = word; self.token = token }
    func perform() async throws -> some IntentResult {
        try SharedStore().mark(word, token: token)
        WidgetCenter.shared.reloadTimelines(ofKind: AppConfig.widgetKind)
        return .result()
    }
}
struct RestartReviewIntent: AppIntent {
    static var title: LocalizedStringResource = "重新复习"
    static var openAppWhenRun = false
    @Parameter(title: "复习版本") var token: String
    init() {}
    init(token: String) { self.token = token }
    func perform() async throws -> some IntentResult {
        try SharedStore().restart(token: token)
        WidgetCenter.shared.reloadTimelines(ofKind: AppConfig.widgetKind)
        return .result()
    }
}
