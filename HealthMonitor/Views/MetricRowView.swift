import SwiftUI

/// One metric on the morning summary: today's value, the usual (the
/// 30-day median), and how far today sits from it.
struct MetricRowView: View {
    let title: String
    let todayText: String
    let usualText: String
    let deltaText: String?
    let isOff: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(todayText)
                    .font(.title3)
                    .bold()
                Text(usualText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let deltaText {
                Text(deltaText)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(isOff ? .orange : .secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
