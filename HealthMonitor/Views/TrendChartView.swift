import SwiftUI
import Charts

/// A 30-day trend line for one metric, with a dashed line marking the
/// usual (the 30-day median).
struct TrendChartView: View {
    let title: String
    let values: [(date: Date, value: Double)]
    let median: Double?
    let unitLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if values.isEmpty {
                Text("Not enough data yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(values, id: \.date) { point in
                        LineMark(
                            x: .value("Day", point.date),
                            y: .value(unitLabel, point.value)
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    if let median {
                        RuleMark(y: .value("Usual", median))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 120)
            }
        }
    }
}
