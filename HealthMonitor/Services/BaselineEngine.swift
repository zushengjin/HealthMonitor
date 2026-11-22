import Foundation
import SwiftData

/// How far one day's value sits from its own usual range.
struct MetricDeviation {
    enum Level {
        case normal
        case off
        case farOff
    }

    let level: Level
    let todayValue: Double?
    let median: Double?
    let standardDeviation: Double?

    var isOff: Bool { level != .normal }
    var isFarOff: Bool { level == .farOff }
}

/// One day's values compared against its baselines.
struct DayEvaluation {
    let date: Date
    let restingHeartRate: MetricDeviation
    let heartRateVariability: MetricDeviation
    let sleep: MetricDeviation

    /// Metrics that are off today (any level).
    var offMetrics: [Metric] {
        var off: [Metric] = []
        if restingHeartRate.isOff { off.append(.restingHeartRate) }
        if heartRateVariability.isOff { off.append(.heartRateVariability) }
        if sleep.isOff { off.append(.sleepHours) }
        return off
    }

    /// Metrics that are far outside their usual range today.
    var farOffMetrics: [Metric] {
        var far: [Metric] = []
        if restingHeartRate.isFarOff { far.append(.restingHeartRate) }
        if heartRateVariability.isFarOff { far.append(.heartRateVariability) }
        if sleep.isFarOff { far.append(.sleepHours) }
        return far
    }
}

/// Computes rolling 30-day medians from daily metrics and evaluates one day
/// against them. Pure logic: no HealthKit, no UI, so it can be tested
/// against recorded history without the app running.
enum BaselineEngine {

    /// Median of the values. Median, not mean: one bad night should not
    /// move the baseline.
    static func median(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        if sorted.count % 2 == 1 {
            return sorted[sorted.count / 2]
        }
        let middle = sorted.count / 2
        return (sorted[middle - 1] + sorted[middle]) / 2
    }

    /// Population standard deviation of the values.
    static func standardDeviation(of values: [Double]) -> Double? {
        guard values.count > 1 else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance.squareRoot()
    }

    /// Recompute the baselines from the given days and store them in
    /// SwiftData. The baseline for each metric uses the 30 days ending
    /// yesterday, so today is judged against its own past, not itself.
    /// Days with no data for a metric are skipped for that metric.
    static func updateBaselines(from metrics: [DailyMetrics], context: ModelContext) throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let history = metrics.filter { $0.date < today }

        let window = Array(history.suffix(AlertThresholds.baselineWindowDays))

        let valuesByMetric: [Metric: [Double]] = [
            .restingHeartRate: window.compactMap(\.restingHeartRate),
            .heartRateVariability: window.compactMap(\.heartRateVariability),
            .sleepHours: window.compactMap(\.sleepHours),
        ]

        for metric in Metric.allCases {
            guard let values = valuesByMetric[metric],
                  let medianValue = median(of: values) else {
                continue
            }
            let deviation = standardDeviation(of: values) ?? 0
            let metricKey = metric.rawValue

            let descriptor = FetchDescriptor<Baseline>(
                predicate: #Predicate { $0.metric == metricKey }
            )
            if let existing = try context.fetch(descriptor).first {
                existing.median = medianValue
                existing.standardDeviation = deviation
                existing.sampleCount = values.count
                existing.computedAt = Date()
            } else {
                context.insert(Baseline(
                    metric: metric,
                    median: medianValue,
                    standardDeviation: deviation,
                    sampleCount: values.count
                ))
            }
        }
        try context.save()
    }

    /// The stored baselines, keyed by metric.
    static func loadBaselines(context: ModelContext) throws -> [Metric: Baseline] {
        let descriptor = FetchDescriptor<Baseline>()
        let stored = try context.fetch(descriptor)
        var result: [Metric: Baseline] = [:]
        for baseline in stored {
            result[baseline.metricEnum] = baseline
        }
        return result
    }

    /// Compare one day against the baselines. A metric with no value today,
    /// or no baseline yet, counts as normal: missing data is never treated
    /// as abnormal.
    static func evaluate(_ today: DailyMetrics, baselines: [Metric: Baseline]) -> DayEvaluation {
        DayEvaluation(
            date: today.date,
            restingHeartRate: evaluateRestingHeartRate(today.restingHeartRate, baseline: baselines[.restingHeartRate]),
            heartRateVariability: evaluateHeartRateVariability(today.heartRateVariability, baseline: baselines[.heartRateVariability]),
            sleep: evaluateSleep(today.sleepHours, baseline: baselines[.sleepHours])
        )
    }

    // MARK: - Per-metric rules (DRAFT thresholds, see AlertThresholds)

    private static func evaluateRestingHeartRate(_ value: Double?, baseline: Baseline?) -> MetricDeviation {
        guard let value, let baseline else {
            return MetricDeviation(level: .normal, todayValue: value, median: baseline?.median, standardDeviation: baseline?.standardDeviation)
        }
        let median = baseline.median
        if value > median * (1 + AlertThresholds.farOutsideRestingHeartRateFraction) {
            return MetricDeviation(level: .farOff, todayValue: value, median: median, standardDeviation: baseline.standardDeviation)
        }
        let aboveMedian = value > median * (1 + AlertThresholds.restingHeartRateFractionAboveMedian)
        let aboveDeviations = baseline.standardDeviation > 0
            && value > median + AlertThresholds.restingHeartRateStandardDeviations * baseline.standardDeviation
        if aboveMedian || aboveDeviations {
            return MetricDeviation(level: .off, todayValue: value, median: median, standardDeviation: baseline.standardDeviation)
        }
        return MetricDeviation(level: .normal, todayValue: value, median: median, standardDeviation: baseline.standardDeviation)
    }

    private static func evaluateHeartRateVariability(_ value: Double?, baseline: Baseline?) -> MetricDeviation {
        guard let value, let baseline else {
            return MetricDeviation(level: .normal, todayValue: value, median: baseline?.median, standardDeviation: baseline?.standardDeviation)
        }
        let median = baseline.median
        if value < median * (1 - AlertThresholds.farOutsideHeartRateVariabilityFraction) {
            return MetricDeviation(level: .farOff, todayValue: value, median: median, standardDeviation: baseline.standardDeviation)
        }
        if value < median * (1 - AlertThresholds.heartRateVariabilityFractionBelowMedian) {
            return MetricDeviation(level: .off, todayValue: value, median: median, standardDeviation: baseline.standardDeviation)
        }
        return MetricDeviation(level: .normal, todayValue: value, median: median, standardDeviation: baseline.standardDeviation)
    }

    private static func evaluateSleep(_ value: Double?, baseline: Baseline?) -> MetricDeviation {
        guard let value, let baseline else {
            return MetricDeviation(level: .normal, todayValue: value, median: baseline?.median, standardDeviation: baseline?.standardDeviation)
        }
        let median = baseline.median
        if value < median - AlertThresholds.farOutsideSleepHours {
            return MetricDeviation(level: .farOff, todayValue: value, median: median, standardDeviation: baseline.standardDeviation)
        }
        if value < median - AlertThresholds.sleepHoursBelowUsual || value < AlertThresholds.sleepHoursAbsoluteFloor {
            return MetricDeviation(level: .off, todayValue: value, median: median, standardDeviation: baseline.standardDeviation)
        }
        return MetricDeviation(level: .normal, todayValue: value, median: median, standardDeviation: baseline.standardDeviation)
    }
}
