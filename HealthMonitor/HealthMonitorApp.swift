import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct HealthMonitorApp: App {
    @State private var healthStore = HealthStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Ask iOS for a morning background slot. Best effort: iOS decides
        // when it runs, and the on-open check is the reliable path.
        MorningCheckCoordinator.shared.scheduleNextMorningCheck()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthStore)
        }
        .modelContainer(for: [Baseline.self, DayStatusRecord.self])
        .backgroundTask(.appRefresh(MorningCheckCoordinator.backgroundTaskIdentifier)) {
            await MorningCheckCoordinator.shared.runMorningCheck(healthStore: healthStore)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await MorningCheckCoordinator.shared.runMorningCheck(healthStore: healthStore)
                }
            }
        }
    }
}
