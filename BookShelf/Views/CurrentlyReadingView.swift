import SwiftUI

struct CurrentlyReadingView: View {
    @Bindable var viewModel: BookshelfViewModel
    @Bindable var timerViewModel: ReadingTimerViewModel
    @State private var showAddBook = false

    private var currentlyReadingBooks: [Book] {
        viewModel.books.filter { $0.readStatus == .currentlyReading }
    }

    private var pausedBooks: [Book] {
        viewModel.books.filter { $0.readStatus == .paused }
    }

    var body: some View {
        NavigationStack {
            Group {
                if currentlyReadingBooks.isEmpty && pausedBooks.isEmpty {
                    emptyState
                } else {
                    dashboardContent
                }
            }
            .navigationTitle("Reading")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddBook = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView(viewModel: viewModel)
            }
        }
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                DailyGoalBanner(viewModel: viewModel)

                StreakBadge(viewModel: viewModel)

                QuoteOfTheDayCard(viewModel: viewModel)

                // Currently Reading Books
                ForEach(currentlyReadingBooks) { book in
                    CurrentlyReadingCard(
                        book: book,
                        viewModel: viewModel,
                        timerViewModel: timerViewModel
                    )
                }

                // Paused Books Section
                if !pausedBooks.isEmpty {
                    DisclosureGroup {
                        ForEach(pausedBooks) { book in
                            HStack(spacing: 12) {
                                BookCoverView(coverData: book.coverImageData, title: book.title, cornerRadius: 4)
                                    .frame(width: 36, height: 48)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(book.title)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    if let progress = book.calculatedProgress {
                                        Text("\(Int(progress * 100))% complete")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Button("Resume") {
                                    viewModel.setReadStatus(book, status: .currentlyReading)
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pause.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Paused (\(pausedBooks.count))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                WeeklyActivityChart(viewModel: viewModel)

                WeeklySummaryCard(viewModel: viewModel)

                ReadingInsightsCard(viewModel: viewModel)
            }
            .padding()
        }
        .refreshable {
            viewModel.fetchBooks()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.accentColor)
                .frame(width: 80, height: 80)
                .background(Circle().fill(Color.accentColor.opacity(0.08)))

            Text("No Books in Progress")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Start reading a book from your library to see it here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showAddBook = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add a Book")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
#Preview("Currently Reading") {
    CurrentlyReadingView(viewModel: BookshelfViewModel(), timerViewModel: ReadingTimerViewModel())
        .modelContainer(Book.previewContainer)
}

#Preview("Empty") {
    CurrentlyReadingView(viewModel: BookshelfViewModel(), timerViewModel: ReadingTimerViewModel())
        .modelContainer(for: Book.self, inMemory: true)
}
#endif
