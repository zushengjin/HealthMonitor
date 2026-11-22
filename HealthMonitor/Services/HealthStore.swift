import Foundation
import HealthKit

/// The only layer that talks to HealthKit. Everything here is read-only:
/// the app never writes health data, and nothing leaves the phone.
@Observable
final class HealthStore {
    private let store = HKHealthStore()

    /// The five HealthKit types v1 reads, per the spec.
    static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.heartRate),
        HKQuantityType(.walkingHeartRateAverage),
        HKCategoryType(.sleepAnalysis),
    ]

    var isAuthorized = false
    var authorizationError: Error?

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Whether the user has granted access. Note: HealthKit never tells the
    /// app which types were allowed, only that authorization was requested.
    var authorizationStatus: HKAuthorizationStatus {
        store.authorizationStatus(for: HKQuantityType(.restingHeartRate))
    }

    /// Asks for read access to the five types, with the usage text from
    /// Info.plist shown by the system. Returns true when the request
    /// completed without error.
    func requestAuthorization() async -> Bool {
        guard isHealthDataAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: Self.readTypes)
            isAuthorized = true
            return true
        } catch {
            authorizationError = error
            return false
        }
    }

    /// Daily aggregates for the last `days` days, oldest first, one entry
    /// per calendar day. Days with no Watch data come back with all values
    /// nil and are treated as gap days by the caller.
    func fetchDailyMetrics(days: Int) async throws -> [DailyMetrics] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -days, to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else {
            return []
        }

        async let restingSamples = fetchSamples(of: HKQuantityType(.restingHeartRate), start: start, end: end)
        async let hrvSamples = fetchSamples(of: HKQuantityType(.heartRateVariabilitySDNN), start: start, end: end)
        async let heartRateSamples = fetchSamples(of: HKQuantityType(.heartRate), start: start, end: end)
        async let walkingSamples = fetchSamples(of: HKQuantityType(.walkingHeartRateAverage), start: start, end: end)
        async let sleepSamples = fetchSamples(of: HKCategoryType(.sleepAnalysis), start: start, end: end)

        let (resting, hrv, heartRate, walking, sleep) = try await (restingSamples, hrvSamples, heartRateSamples, walkingSamples, sleepSamples)

        let restingUnit = HKUnit.count().unitDivided(by: .minute())
        let hrvUnit = HKUnit.secondUnit(with: .milli)

        // Group quantity samples by the day they were recorded.
        func dailyValues(from samples: [HKSample], unit: HKUnit) -> [Date: [Double]] {
            var grouped: [Date: [Double]] = [:]
            for sample in samples {
                guard let quantitySample = sample as? HKQuantitySample else { continue }
                let day = calendar.startOfDay(for: sample.startDate)
                grouped[day, default: []].append(quantitySample.quantity.doubleValue(for: unit))
            }
            return grouped
        }

        let restingByDay = dailyValues(from: resting, unit: restingUnit)
        let hrvByDay = dailyValues(from: hrv, unit: hrvUnit)
        let heartRateByDay = dailyValues(from: heartRate, unit: restingUnit)
        let walkingByDay = dailyValues(from: walking, unit: restingUnit)

        // Sleep: sum asleep time per night, attributed to the day the sleep
        // ends (the morning). Deep sleep is tracked separately.
        var sleepByDay: [Date: (total: Double, deep: Double)] = [:]
        for sample in sleep {
            guard let categorySample = sample as? HKCategorySample,
                  let stage = HKCategoryValueSleepAnalysis(rawValue: categorySample.value) else {
                continue
            }
            let hours = categorySample.endDate.timeIntervalSince(categorySample.startDate) / 3600
            let day = calendar.startOfDay(for: categorySample.endDate)
            var entry = sleepByDay[day] ?? (total: 0, deep: 0)
            switch stage {
            case .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified:
                entry.total += hours
                if stage == .asleepDeep {
                    entry.deep += hours
                }
            case .inBed, .awake:
                break
            @unknown default:
                break
            }
            sleepByDay[day] = entry
        }

        // One entry per day in the range, so gap days are visible as nils.
        var result: [DailyMetrics] = []
        var day = start
        while day < end {
            let restingValues = restingByDay[day] ?? []
            let hrvValues = hrvByDay[day] ?? []
            let heartRateValues = heartRateByDay[day] ?? []
            let walkingValues = walkingByDay[day] ?? []
            let sleepEntry = sleepByDay[day]

            result.append(DailyMetrics(
                date: day,
                restingHeartRate: restingValues.last,
                heartRateVariability: hrvValues.isEmpty ? nil : hrvValues.reduce(0, +) / Double(hrvValues.count),
                sleepHours: sleepEntry.flatMap { $0.total > 0 ? $0.total : nil },
                deepSleepHours: sleepEntry.flatMap { $0.deep > 0 ? $0.deep : nil },
                walkingHeartRateAverage: walkingValues.isEmpty ? nil : walkingValues.reduce(0, +) / Double(walkingValues.count),
                daytimeHeartRateAverage: heartRateValues.isEmpty ? nil : heartRateValues.reduce(0, +) / Double(heartRateValues.count)
            ))

            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    // MARK: - Private

    private func fetchSamples(of type: HKSampleType, start: Date, end: Date) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            self.store.execute(query)
        }
    }
}
