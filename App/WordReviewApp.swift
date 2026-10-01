import SwiftUI
import BackgroundTasks
import WidgetKit

enum BackgroundRefresh {
    static func schedule() {
        guard (try? SharedStore().read().source.isEmpty) == false else { return }
        let request = BGAppRefreshTaskRequest(identifier: AppConfig.backgroundID)
        request.earliestBeginDate = Date().addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
@main struct WordReviewApp: App {
    @StateObject private var model = ReviewModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .onOpenURL { url in if url.scheme == "wordreview", url.host == "reader" { model.refresh(); model.showPDF = true } }
                .task { model.refresh(); await model.sync(force: false) }
                .onChange(of: phase) { _, newPhase in
                    if newPhase == .active { model.refresh(); Task { await model.sync(force: false) } }
                    if newPhase == .background { BackgroundRefresh.schedule(); WidgetCenter.shared.reloadTimelines(ofKind: AppConfig.widgetKind) }
                }
        }
        .backgroundTask(.appRefresh(AppConfig.backgroundID)) {
            BackgroundRefresh.schedule()
            try? await SyncEngine.shared.sync()
            WidgetCenter.shared.reloadTimelines(ofKind: AppConfig.widgetKind)
        }
    }
}
