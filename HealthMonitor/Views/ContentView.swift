import SwiftUI

/// Root view. Shows the one-time Health setup first, then the two tabs:
/// today's summary and the history log.
struct ContentView: View {
    @Environment(HealthStore.self) private var healthStore
    @AppStorage("didRequestHealthAuthorization") private var didRequestHealthAuthorization = false

    var body: some View {
        Group {
            if !didRequestHealthAuthorization {
                OnboardingView()
            } else {
                TabView {
                    MorningSummaryView()
                        .tabItem {
                            Label("Today", systemImage: "sunrise")
                        }
                    HistoryView()
                        .tabItem {
                            Label("History", systemImage: "list.bullet")
                        }
                }
            }
        }
        .task {
            MorningCheckCoordinator.shared.scheduleNextMorningCheck()
        }
    }
}
