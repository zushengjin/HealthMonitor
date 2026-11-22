import Foundation
import SwiftData

/// One day's status: clear, watch, alert, or no data.
enum DayStatus: String, Codable, CaseIterable {
    case clear
    case watch
    case alert
    case noData

    var displayName: String {
        switch self {
        case .clear: return "Clear"
        case .watch: return "Watch"
        case .alert: return "Alert"
        case .noData: return "No data"
        }
    }
}

/// The stored record for one day: the status, the day's numbers, the
/// baselines they were compared against, the note shown in the app, and
/// whether a local notification was already sent for this day.
@Model
final class DayStatusRecord {
    /// "yyyy-MM-dd" in the current calendar. Unique: one record per day.
    @Attribute(.unique) var dayKey: String

    /// Start of the calendar day.
    var date: Date

    var statusRaw: String

    var restingHeartRate: Double?
    var restingHeartRateMedian: Double?
    var heartRateVariability: Double?
    var heartRateVariabilityMedian: Double?
    var sleepHours: Double?
    var sleepHoursMedian: Double?

    /// The note shown in the app for this day. Numbers plus general
    /// context only, never a diagnosis.
    var note: String

    /// True once a local notification has been sent for this day, so a
    /// re-run of the morning check never notifies twice.
    var alertSent: Bool

    var status: DayStatus {
        get { DayStatus(rawValue: statusRaw) ?? .noData }
        set { statusRaw = newValue.rawValue }
    }

    init(
        date: Date,
        status: DayStatus,
        restingHeartRate: Double? = nil,
        restingHeartRateMedian: Double? = nil,
        heartRateVariability: Double? = nil,
        heartRateVariabilityMedian: Double? = nil,
        sleepHours: Double? = nil,
        sleepHoursMedian: Double? = nil,
        note: String = "",
        alertSent: Bool = false
    ) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.dayKey = formatter.string(from: date)
        self.date = date
        self.statusRaw = status.rawValue
        self.restingHeartRate = restingHeartRate
        self.restingHeartRateMedian = restingHeartRateMedian
        self.heartRateVariability = heartRateVariability
        self.heartRateVariabilityMedian = heartRateVariabilityMedian
        self.sleepHours = sleepHours
        self.sleepHoursMedian = sleepHoursMedian
        self.note = note
        self.alertSent = alertSent
    }
}
