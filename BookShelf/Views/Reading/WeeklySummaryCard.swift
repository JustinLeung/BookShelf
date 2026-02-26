import SwiftUI

struct WeeklySummaryCard: View {
    @Bindable var viewModel: BookshelfViewModel

    private var weekPages: Int {
        viewModel.pagesReadInPeriod(viewModel.thisWeekInterval)
    }

    private var weekBooks: Int {
        viewModel.booksFinished(in: viewModel.thisWeekInterval).count
    }

    private var booksInProgress: Int {
        viewModel.books.filter { $0.readStatus == .currentlyReading }.count
    }

    var body: some View {
        let hasStats = weekPages > 0 || weekBooks > 0

        if hasStats {
            VStack(alignment: .leading, spacing: 8) {
                Text("Weekly Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 0) {
                    summaryItem(value: "\(weekPages)", label: "Pages")
                    Divider().frame(height: 30)
                    summaryItem(value: "\(weekBooks)", label: "Finished")
                    Divider().frame(height: 30)
                    summaryItem(value: "\(booksInProgress)", label: "In Progress")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func summaryItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview("Weekly Summary") {
    WeeklySummaryCard(viewModel: BookshelfViewModel())
        .padding()
}
#endif
