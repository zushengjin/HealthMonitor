import SwiftUI
import SwiftData

/// The morning summary. Layout, decided 2026-11-21: the status first
/// (Clear / Watch / Alert), then the numbers with their "vs. your usual"
/// values, then a 30-day trend line per metric.
///
/// Answers one question: "am I normal today?"
struct MorningSummaryView: View {
    @Environment(HealthStore.self) private var healthStore
    @Query(sort: \DayStatusRecord.date, order: .reverse) private var records: [DayStatusRecord]

    @State private var series: [DailyMetrics] = []
    @State private var isRefreshing = false

    private var todayRecord: DayStatusRecord? {
        records.first(where: { Calendar.current.isDateInToday($0.date) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusSection

                    if healthStore.authorizationStatus == .denied {
                        accessDeniedSection
                    }

                    if let record = todayRecord {
                        metricsSection(record: record)
                        chartsSection
                    } else {
                        Text("Checking this morning's numbers…")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                Button {
                    isRefreshing = true
                    Task {
                        await runCheck()
                        isRefreshing = false
                    }
                } label: {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing)
            }
            .task {
                await runCheck()
            }
        }
    }

    // MARK: - Status first

    @ViewBuilder
    private var statusSection: some View {
        let status = todayRecord?.status ?? .noData
        VStack(alignment: .leading, spacing: 6) {
            Text(status.displayName)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(statusColor(status))

            if let note = todayRecord?.note, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if status == .clear {
                Text("Your heart and sleep look like your usual.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if status == .noData {
                Text("No data from the Watch today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let record = todayRecord {
                Text(record.date, format: .dateTime.weekday(.wide).month().day())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusColor(_ status: DayStatus) -> Color {
        switch status {
        case .clear: return .green
        case .watch: return .orange
        case .alert: return .red
        case .noData: return .gray
        }
    }

    // MARK: - Numbers

    @ViewBuilder
    private func metricsSection(record: DayStatusRecord) -> some View {
        VStack(spacing: 12) {
            MetricRowView(
                title: "Sleep",
                todayText: record.sleepHours.map { AlertEngine.formatHours($0) } ?? "—",
                usualText: record.sleepHoursMedian.map { "Usual \(AlertEngine.formatHours($0))" } ?? "No usual yet",
                deltaText: deltaHours(today: record.sleepHours, usual: record.sleepHoursMedian),
                isOff: record.status != .clear && record.sleepHours != nil && record.sleepHoursMedian != nil
                    && isSleepOff(today: record.sleepHours, usual: record.sleepHoursMedian)
            )

            MetricRowView(
                title: "Resting heart rate",
                todayText: record.restingHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "—",
                usualText: record.restingHeartRateMedian.map { "Usual \(Int($0.rounded())) bpm" } ?? "No usual yet",
                deltaText: deltaPercent(today: record.restingHeartRate, usual: record.restingHeartRateMedian),
                isOff: record.status != .clear && record.restingHeartRate != nil && record.restingHeartRateMedian != nil
                    && isRestingHeartRateOff(today: record.restingHeartRate, usual: record.restingHeartRateMedian)
            )

            MetricRowView(
                title: "Heart rate variability",
                todayText: record.heartRateVariability.map { "\(Int($0.rounded())) ms" } ?? "—",
                usualText: record.heartRateVariabilityMedian.map { "Usual \(Int($0.rounded())) ms" } ?? "No usual yet",
                deltaText: deltaPercent(today: record.heartRateVariability, usual: record.heartRateVariabilityMedian, inverted: true),
                isOff: record.status != .clear && record.heartRateVariability != nil && record.heartRateVariabilityMedian != nil
                    && isHeartRateVariabilityOff(today: record.heartRateVariability, usual: record.heartRateVariabilityMedian)
            )
        }
    }

    // MARK: - Trend lines

    @ViewBuilder
    private var chartsSection: some View {
        let restingPoints = series.compactMap { day -> (date: Date, value: Double)? in
            guard let value = day.restingHeartRate else { return nil }
            return (day.date, value)
        }
        let hrvPoints = series.compactMap { day -> (date: Date, value: Double)? in
            guard let value = day.heartRateVariability else { return nil }
            return (day.date, value)
        }
        let sleepPoints = series.compactMap { day -> (date: Date, value: Double)? in
            guard let value = day.sleepHours else { return nil }
            return (day.date, value)
        }

        VStack(spacing: 20) {
            TrendChartView(
                title: "Resting heart rate — last 30 days",
                values: restingPoints,
                median: todayRecord?.restingHeartRateMedian,
                unitLabel: "bpm"
            )
            TrendChartView(
                title: "Heart rate variability — last 30 days",
                values: hrvPoints,
                median: todayRecord?.heartRateVariabilityMedian,
                unitLabel: "ms"
            )
            TrendChartView(
                title: "Sleep — last 30 days",
                values: sleepPoints,
                median: todayRecord?.sleepHoursMedian,
                unitLabel: "hours"
            )
        }
    }

    // MARK: - Access denied

    private var accessDeniedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Health access is off")
                .font(.headline)
            Text("This app cannot read your heart or sleep data until access is turned on. Open Settings, go to Privacy & Security, then Health, and allow HealthMonitor to read heart rate, heart rate variability, and sleep.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func runCheck() async {
        await MorningCheckCoordinator.shared.runMorningCheck(healthStore: healthStore)
        do {
            series = try await healthStore.fetchDailyMetrics(days: AlertThresholds.baselineWindowDays)
        } catch {
            series = []
        }
    }

    private func deltaPercent(today: Double?, usual: Double?, inverted: Bool = false) -> String? {
        guard let today, let usual, usual != 0 else { return nil }
        let percent = (today - usual) / usual * 100
        let sign = percent >= 0 ? "+" : ""
        return "\(sign)\(Int(percent.rounded()))% vs usual"
    }

    private func deltaHours(today: Double?, usual: Double?) -> String? {
        guard let today, let usual else { return nil }
        let diff = today - usual
        let sign = diff >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", diff))h vs usual"
    }

    private func isRestingHeartRateOff(today: Double?, usual: Double?) -> Bool {
        guard let today, let usual else { return false }
        return today > usual * (1 + AlertThresholds.restingHeartRateFractionAboveMedian)
    }

    private func isHeartRateVariabilityOff(today: Double?, usual: Double?) -> Bool {
        guard let today, let usual else { return false }
        return today < usual * (1 - AlertThresholds.heartRateVariabilityFractionBelowMedian)
    }

    private func isSleepOff(today: Double?, usual: Double?) -> Bool {
        guard let today, let usual else { return false }
        return today < usual - AlertThresholds.sleepHoursBelowUsual || today < AlertThresholds.sleepHoursAbsoluteFloor
    }
}
