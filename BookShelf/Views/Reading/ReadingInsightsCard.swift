import SwiftUI

struct ReadingInsightsCard: View {
    @Bindable var viewModel: BookshelfViewModel

    var body: some View {
        let insights = gatherInsights()
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Insights")
                    .font(AppTheme.Typography.cardTitle)

                ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: insight.icon)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 16)
                        Text(insight.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .themedCard()
        }
    }

    private struct Insight {
        let icon: String
        let text: String
    }

    private func gatherInsights() -> [Insight] {
        var results: [Insight] = []

        if let avgPace = viewModel.averagePagesPerDay, avgPace > 0 {
            results.append(Insight(icon: "speedometer", text: "Average pace: \(Int(avgPace)) pages/day"))
        }

        if let bestWeek = viewModel.bestReadingWeek() {
            results.append(Insight(icon: "trophy.fill", text: "Best week: \(bestWeek) pages"))
        }

        if let preferred = viewModel.preferredReadingTime() {
            results.append(Insight(icon: "clock", text: "You usually read in the \(preferred)"))
        }

        let currentBooks = viewModel.books.filter { $0.readStatus == .currentlyReading }
        for book in currentBooks.prefix(2) {
            if let date = viewModel.estimatedCompletionDate(for: book) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                results.append(Insight(icon: "calendar", text: "\(book.title) - finish ~\(formatter.string(from: date))"))
            }
        }

        return results
    }
}

#if DEBUG
#Preview("Reading Insights") {
    ReadingInsightsCard(viewModel: BookshelfViewModel())
        .padding()
}
#endif
