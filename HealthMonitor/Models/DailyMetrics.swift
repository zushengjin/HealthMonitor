import Foundation

/// One day of aggregated HealthKit values.
///
/// A day with no Watch data has every value nil. Gap days are skipped:
/// they get no status and do not count toward the baseline.
struct DailyMetrics: Identifiable {
    var id: Date { date }

    /// Start of the calendar day these values belong to.
    let date: Date

    /// Beats per minute. One value most days, computed overnight by the Watch.
    var restingHeartRate: Double?

    /// SDNN heart rate variability, milliseconds.
    var heartRateVariability: Double?

    /// Total asleep time (core + deep + REM), hours.
    var sleepHours: Double?

    /// Deep sleep only, hours.
    var deepSleepHours: Double?

    /// Beats per minute. Context only, never an alert trigger for v1.
    var walkingHeartRateAverage: Double?

    /// Daytime heart rate average, beats per minute. Context only.
    var daytimeHeartRateAverage: Double?

    var hasAnyData: Bool {
        restingHeartRate != nil || heartRateVariability != nil || sleepHours != nil
    }
}
