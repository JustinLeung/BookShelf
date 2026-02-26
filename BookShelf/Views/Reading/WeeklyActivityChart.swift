import SwiftUI

struct WeeklyActivityChart: View {
    @Bindable var viewModel: BookshelfViewModel

    private var weekData: [(day: String, pages: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
            let period = DateInterval(start: date, end: nextDay)
            let pages = viewModel.pagesReadInPeriod(period)
            let dayName = date.formatted(.dateTime.weekday(.abbreviated))
            return (day: dayName, pages: pages)
        }
    }

    private var maxPages: Int {
        max(weekData.map(\.pages).max() ?? 1, 1)
    }

    var body: some View {
        let data = weekData
        let hasData = data.contains { $0.pages > 0 }

        if hasData {
            VStack(alignment: .leading, spacing: 8) {
                Text("This Week")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.pages > 0 ? Color.accentColor : Color(.systemGray4))
                                .frame(height: max(4, CGFloat(item.pages) / CGFloat(maxPages) * 80))

                            Text(item.day)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#if DEBUG
#Preview("Weekly Activity") {
    WeeklyActivityChart(viewModel: BookshelfViewModel())
        .padding()
}
#endif
