import Foundation
import SwiftData
import BackgroundTasks

/// Runs the once-a-day morning check: fetch the last 31 days from
/// HealthKit, refresh the 30-day baselines, evaluate today, store the
/// day's record, and notify only if a real alert fired and one has not
/// already been sent for today.
///
/// Called from two places, per the spec: whenever the app opens (the
/// reliable path) and from the morning background refresh (best effort:
/// iOS decides when the background slot actually runs, so alerts are
/// never promised in real time).
final class MorningCheckCoordinator {
    static let shared = MorningCheckCoordinator()

    static let backgroundTaskIdentifier = "com.healthmonitor.morningcheck"

    private init() {}

    /// A second container on the same on-device store, so the background
    /// refresh can write records even when the UI is not running.
    private lazy var container: ModelContainer = {
        // The default store is shared with the UI's container.
        // swiftlint:disable:next force_try
        try! ModelContainer(for: Baseline.self, DayStatusRecord.self)
    }()

    /// Ask iOS for a background slot tomorrow morning. Best effort: iOS
    /// may refuse, and the slot is never guaranteed to run.
    func scheduleNextMorningCheck() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        var components = DateComponents()
        components.hour = 6
        components.minute = 30
        if let next = Calendar.current.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) {
            request.earliestBeginDate = next
        }
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Best effort only; the on-open check is the reliable path.
        }
    }

    @MainActor
    func runMorningCheck(healthStore: HealthStore) async {
        guard healthStore.isAuthorized else { return }

        let context = ModelContext(container)
        do {
            let metrics = try await healthStore.fetchDailyMetrics(days: AlertThresholds.baselineWindowDays + 1)
            try BaselineEngine.updateBaselines(from: metrics, context: context)
            let baselines = try BaselineEngine.loadBaselines(context: context)

            guard let today = metrics.last else { return }
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            guard calendar.isDate(today.date, inSameDayAs: todayStart) else { return }

            // How many days immediately before today were Watch or Alert.
            let recentRecords = try loadRecentRecords(context: context, days: 7)
            let consecutiveOffDays = countConsecutiveOffDays(in: recentRecords, before: todayStart)

            if !today.hasAnyData {
                // Gap day: skipped, shown as "No data", not counted.
                try upsertRecord(
                    for: todayStart,
                    status: .noData,
                    evaluation: nil,
                    note: "No data from the Watch today.",
                    context: context
                )
                try context.save()
                scheduleNextMorningCheck()
                return
            }

            let evaluation = BaselineEngine.evaluate(today, baselines: baselines)
            let decision = AlertEngine.decide(evaluation: evaluation, consecutiveOffDays: consecutiveOffDays)

            switch decision {
            case .clear:
                try upsertRecord(for: todayStart, status: .clear, evaluation: evaluation, note: "", context: context)
            case .watch(let note):
                try upsertRecord(for: todayStart, status: .watch, evaluation: evaluation, note: note, context: context)
            case .alert(let title, let message):
                let alreadySent = recentRecords.first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?.alertSent ?? false
                try upsertRecord(for: todayStart, status: .alert, evaluation: evaluation, note: message, context: context)
                if !alreadySent {
                    await NotificationService.shared.sendAlert(title: title, body: message)
                    try markAlertSent(for: todayStart, context: context)
                }
            }

            try context.save()
        } catch {
            // A failed check leaves yesterday's record in place and tries
            // again next time the app opens. Nothing is half-written: the
            // save above is the only write.
        }
        scheduleNextMorningCheck()
    }

    // MARK: - Private

    private func loadRecentRecords(context: ModelContext, days: Int) throws -> [DayStatusRecord] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: Date())) ?? Date()
        let descriptor = FetchDescriptor<DayStatusRecord>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    private func countConsecutiveOffDays(in records: [DayStatusRecord], before today: Date) -> Int {
        let calendar = Calendar.current
        var count = 0
        var day = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        while let record = records.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
            guard record.status == .watch || record.status == .alert else { break }
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    private func upsertRecord(
        for date: Date,
        status: DayStatus,
        evaluation: DayEvaluation?,
        note: String,
        context: ModelContext
    ) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dayKey = formatter.string(from: date)

        let descriptor = FetchDescriptor<DayStatusRecord>(
            predicate: #Predicate { $0.dayKey == dayKey }
        )
        let existing = try context.fetch(descriptor).first

        if let existing {
            existing.status = status
            existing.restingHeartRate = evaluation?.restingHeartRate.todayValue
            existing.restingHeartRateMedian = evaluation?.restingHeartRate.median
            existing.heartRateVariability = evaluation?.heartRateVariability.todayValue
            existing.heartRateVariabilityMedian = evaluation?.heartRateVariability.median
            existing.sleepHours = evaluation?.sleep.todayValue
            existing.sleepHoursMedian = evaluation?.sleep.median
            existing.note = note
        } else {
            context.insert(DayStatusRecord(
                date: date,
                status: status,
                restingHeartRate: evaluation?.restingHeartRate.todayValue,
                restingHeartRateMedian: evaluation?.restingHeartRate.median,
                heartRateVariability: evaluation?.heartRateVariability.todayValue,
                heartRateVariabilityMedian: evaluation?.heartRateVariability.median,
                sleepHours: evaluation?.sleep.todayValue,
                sleepHoursMedian: evaluation?.sleep.median,
                note: note
            ))
        }
    }

    private func markAlertSent(for date: Date, context: ModelContext) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dayKey = formatter.string(from: date)
        let descriptor = FetchDescriptor<DayStatusRecord>(
            predicate: #Predicate { $0.dayKey == dayKey }
        )
        if let record = try context.fetch(descriptor).first {
            record.alertSent = true
            try context.save()
        }
    }
}
