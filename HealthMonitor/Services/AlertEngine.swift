import Foundation

/// The outcome of one day's evaluation.
enum AlertDecision {
    /// Nothing off today.
    case clear
    /// Something is off, but only as a quiet note inside the app. No push.
    case watch(note: String)
    /// A real alert: local notification, numbers plus general context.
    case alert(title: String, message: String)
}

/// Decides Watch vs. Alert from one day's evaluation plus the recent
/// record history (for the persistence rule).
///
/// The combination rule, decided 2026-11-21: one metric alone fires a
/// quiet watch note; a real alert needs two signals agreeing or one
/// metric far outside its range. The tiered rule: a watch note appears
/// on day one, and the real alert only fires once the qualifying
/// condition has persisted (see AlertThresholds for the DRAFT day counts).
///
/// Wording rule, from the spec: numbers first, then general context.
/// Never name a condition, never tell the user to do a specific thing.
enum AlertEngine {

    /// - Parameters:
    ///   - evaluation: today's values against the baselines.
    ///   - consecutiveOffDays: how many days immediately before today
    ///     were Watch or Alert days (0 if yesterday was Clear or had no data).
    static func decide(evaluation: DayEvaluation, consecutiveOffDays: Int) -> AlertDecision {
        let off = evaluation.offMetrics
        let farOff = evaluation.farOffMetrics

        guard !off.isEmpty else {
            return .clear
        }

        // A real alert needs a qualifying condition that has persisted.
        // Far outside its range qualifies on its own, after 2 days.
        // Two signals agreeing qualify after 3 days.
        if !farOff.isEmpty && consecutiveOffDays + 1 >= AlertThresholds.farOutsideDaysBeforeAlert {
            return .alert(
                title: "HealthMonitor: something to pay attention to",
                message: alertMessage(for: evaluation, streakDays: consecutiveOffDays + 1)
            )
        }
        if off.count >= 2 && consecutiveOffDays + 1 >= AlertThresholds.daysBeforeAlert {
            return .alert(
                title: "HealthMonitor: something to pay attention to",
                message: alertMessage(for: evaluation, streakDays: consecutiveOffDays + 1)
            )
        }

        return .watch(note: watchNote(for: evaluation))
    }

    // MARK: - Wording

    /// Quiet in-app note. Example from the spec: "Resting HR 78 — your
    /// usual is 62. HRV also down. Keeping an eye on it."
    static func watchNote(for evaluation: DayEvaluation) -> String {
        var parts: [String] = []
        if evaluation.restingHeartRate.isOff,
           let value = evaluation.restingHeartRate.todayValue,
           let median = evaluation.restingHeartRate.median {
            parts.append("Resting HR \(Int(value.rounded())) — your usual is \(Int(median.rounded()))")
        }
        if evaluation.heartRateVariability.isOff,
           let value = evaluation.heartRateVariability.todayValue,
           let median = evaluation.heartRateVariability.median {
            parts.append("HRV \(Int(value.rounded())) ms — your usual is \(Int(median.rounded())) ms")
        }
        if evaluation.sleep.isOff,
           let value = evaluation.sleep.todayValue,
           let median = evaluation.sleep.median {
            parts.append("Sleep \(formatHours(value)) — your usual is \(formatHours(median))")
        }
        return parts.joined(separator: ". ") + ". Keeping an eye on it."
    }

    /// Real-alert message. Numbers first, then the same general context
    /// the spec drafts: worth paying attention to, consider checking in
    /// with a doctor, especially if feeling unwell.
    static func alertMessage(for evaluation: DayEvaluation, streakDays: Int) -> String {
        var parts: [String] = []
        if evaluation.restingHeartRate.isOff,
           let value = evaluation.restingHeartRate.todayValue,
           let median = evaluation.restingHeartRate.median {
            parts.append("resting heart rate \(Int(value.rounded())) (usual \(Int(median.rounded())))")
        }
        if evaluation.heartRateVariability.isOff,
           let value = evaluation.heartRateVariability.todayValue,
           let median = evaluation.heartRateVariability.median {
            parts.append("HRV \(Int(value.rounded())) ms (usual \(Int(median.rounded())) ms)")
        }
        if evaluation.sleep.isOff,
           let value = evaluation.sleep.todayValue,
           let median = evaluation.sleep.median {
            parts.append("sleep \(formatHours(value)) (usual \(formatHours(median)))")
        }
        let dayWord = streakDays == 1 ? "day" : "days"
        return "Your \(parts.joined(separator: ", ")) has been off your usual for \(streakDays) \(dayWord). "
            + "That's worth paying attention to — consider checking in with your doctor, especially if you feel unwell."
    }

    static func formatHours(_ hours: Double) -> String {
        let whole = Int(hours)
        let minutes = Int((hours - Double(whole)) * 60)
        return "\(whole)h \(minutes)m"
    }
}
