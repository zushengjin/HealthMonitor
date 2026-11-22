import SwiftUI
import SwiftData

/// The log of past Watch/Alert days, newest first. Kept on-device in
/// SwiftData, per the spec: the history is what lets you spot patterns
/// over time ("three Watch days in a row always comes before I get sick").
struct HistoryView: View {
    @Query(sort: \DayStatusRecord.date, order: .reverse) private var records: [DayStatusRecord]

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    VStack(spacing: 8) {
                        Text("No days logged yet.")
                            .font(.headline)
                        Text("Days appear here once the morning check has run. Days with no Watch data show as \"No data\".")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List(records) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle()
                                    .fill(statusColor(record.status))
                                    .frame(width: 10, height: 10)
                                Text(record.status.displayName)
                                    .bold()
                                Spacer()
                                Text(record.date, format: .dateTime.month().day().year())
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 12) {
                                if let resting = record.restingHeartRate {
                                    Text("HR \(Int(resting.rounded()))")
                                }
                                if let hrv = record.heartRateVariability {
                                    Text("HRV \(Int(hrv.rounded())) ms")
                                }
                                if let sleep = record.sleepHours {
                                    Text("Sleep \(AlertEngine.formatHours(sleep))")
                                }
                                if record.status == .noData {
                                    Text("No data from the Watch.")
                                }
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                            if !record.note.isEmpty {
                                Text(record.note)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("History")
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
}
