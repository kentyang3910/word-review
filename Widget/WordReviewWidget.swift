import WidgetKit
import SwiftUI

struct ReviewEntry: TimelineEntry { var date: Date; var state: ReviewState? }
struct ReviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReviewEntry {
        ReviewEntry(date: Date(), state: ReviewState(deckID: "preview", title: "示例", pdfName: "", words: ["provocative", "child rearing", "in retrospect"], day: ReviewState.today()))
    }
    func getSnapshot(in context: Context, completion: @escaping (ReviewEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : ReviewEntry(date: Date(), state: try? SharedStore().read().state))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ReviewEntry>) -> Void) {
        Task {
            var state = try? SharedStore().read().state
            // A check must not wait behind a network request before feedback is rendered.
            if state?.hasFeedback != true { try? await SyncEngine.shared.sync(); state = try? SharedStore().read().state }
            let now = Date()
            var entries = [ReviewEntry(date: now, state: state)]
            if var next = state {
                for deadline in Set(next.until.filter { $0 > now.timeIntervalSince1970 }).sorted() {
                    let date = Date(timeIntervalSince1970: deadline + 0.05)
                    next.settle(date); entries.append(ReviewEntry(date: date, state: next))
                }
                if let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
                    next.rollDay(ReviewState.today(midnight)); entries.append(ReviewEntry(date: midnight, state: next))
                }
            }
            // Dates are requests, not a promise of a sub-second refresh by WidgetKit.
            completion(Timeline(entries: entries.sorted { $0.date < $1.date }, policy: .after(now.addingTimeInterval(30 * 60))))
        }
    }
}
struct WordReviewWidget: Widget {
    let kind = AppConfig.widgetKind
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReviewProvider()) { entry in
            ReviewCard(state: entry.state, widget: true)
                .containerBackground(.white, for: .widget)
                .widgetURL(AppConfig.readerURL)
        }
        .configurationDisplayName("词页复习")
        .description("右侧勾选认识的单词，点击单词查看完整 PDF。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
@main struct ReviewWidgetBundle: WidgetBundle {
    var body: some Widget { WordReviewWidget() }
}
