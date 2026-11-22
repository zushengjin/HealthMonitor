import Foundation

/// DRAFT alert thresholds.
///
/// These are starting points to tune against your own data (spec build
/// step 5: run them against the last 3 months of HealthKit history until
/// false flags are rare and no obvious sick stretch is missed). Nothing
/// here is a settled decision.
enum AlertThresholds {
    /// Rolling baseline window, in days.
    static let baselineWindowDays = 30

    /// Resting heart rate more than this fraction above the 30-day median
    /// counts as off. DRAFT range from the spec: 15-20%.
    static let restingHeartRateFractionAboveMedian = 0.15

    /// ...or more than this many standard deviations above the median.
    /// DRAFT: 2 standard deviations.
    static let restingHeartRateStandardDeviations = 2.0

    /// HRV more than this fraction below the 30-day median counts as off.
    /// DRAFT range from the spec: 20-25%.
    static let heartRateVariabilityFractionBelowMedian = 0.20

    /// Sleep more than this many hours below the usual counts as off.
    /// DRAFT: 1.5 hours.
    static let sleepHoursBelowUsual = 1.5

    /// Sleep under this many hours counts as off even if it is near the
    /// usual. DRAFT: 6 hours.
    static let sleepHoursAbsoluteFloor = 6.0

    /// A single metric this far off counts as "far outside its range" and
    /// can fire a real alert on its own. DRAFT values.
    static let farOutsideRestingHeartRateFraction = 0.30
    static let farOutsideHeartRateVariabilityFraction = 0.40
    static let farOutsideSleepHours = 3.0

    /// Consecutive off days before a two-signal agreement becomes a real
    /// alert. DRAFT: 3 days, inside the spec's 2-3 day range.
    static let daysBeforeAlert = 3

    /// Consecutive off days before a far-outside metric becomes a real
    /// alert on its own. DRAFT: 2 days.
    static let farOutsideDaysBeforeAlert = 2
}
