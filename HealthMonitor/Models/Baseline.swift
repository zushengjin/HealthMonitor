import Foundation
import SwiftData

/// The three metrics v1 watches. Raw HealthKit values stay in HealthKit;
/// only the computed baselines are stored here.
enum Metric: String, CaseIterable, Codable {
    case restingHeartRate
    case heartRateVariability
    case sleepHours

    var displayName: String {
        switch self {
        case .restingHeartRate: return "Resting heart rate"
        case .heartRateVariability: return "Heart rate variability"
        case .sleepHours: return "Sleep"
        }
    }
}

/// A rolling baseline for one metric: the median (and spread) of the last
/// 30 days of that metric, computed on-device.
@Model
final class Baseline {
    @Attribute(.unique) var metric: String
    var median: Double
    var standardDeviation: Double
    var sampleCount: Int
    var computedAt: Date

    init(metric: Metric, median: Double, standardDeviation: Double, sampleCount: Int, computedAt: Date = Date()) {
        self.metric = metric.rawValue
        self.median = median
        self.standardDeviation = standardDeviation
        self.sampleCount = sampleCount
        self.computedAt = computedAt
    }

    var metricEnum: Metric { Metric(rawValue: metric) ?? .restingHeartRate }
}
