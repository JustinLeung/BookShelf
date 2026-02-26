import SwiftUI

struct StatsSummaryCard: View {
    @Bindable var viewModel: BookshelfViewModel

    private var streak: Int { viewModel.currentStreak() }
    private var totalBooks: Int { viewModel.totalBooksRead }
    private var totalPages: Int { viewModel.totalPagesRead }

    private var hasStats: Bool {
        totalBooks > 0 || !viewModel.fetchAllProgressEntries().isEmpty
    }

    var body: some View {
        if hasStats {
            VStack(alignment: .leading, spacing: 10) {
                // Streak
                if streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color.accentColor)
                        Text("\(streak)-day streak")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }

                // Lifetime summary
                HStack(spacing: 0) {
                    if totalBooks > 0 {
                        Text("\(totalBooks) book\(totalBooks == 1 ? "" : "s")")
                    }
                    if totalPages > 0 {
                        if totalBooks > 0 { Text("  ·  ") }
                        Text("\(totalPages.formatted()) pages")
                    }
                    if let avgPace = viewModel.averagePagesPerDay {
                        Text("  ·  ")
                        Text("\(Int(avgPace)) pg/day")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Daily goal progress
                if let progress = viewModel.dailyGoalProgress() {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today: \(progress.pagesRead)/\(progress.goal) pages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(.systemGray4))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.accentColor)
                                    .frame(width: geo.size.width * min(1.0, Double(progress.pagesRead) / Double(progress.goal)))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

#if DEBUG
#Preview("Stats Summary Card") {
    StatsSummaryCard(viewModel: BookshelfViewModel())
        .modelContainer(Book.previewContainer)
        .padding()
}
#endif
