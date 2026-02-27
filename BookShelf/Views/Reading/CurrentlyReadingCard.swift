import SwiftUI

struct CurrentlyReadingCard: View {
    let book: Book
    @Bindable var viewModel: BookshelfViewModel
    @Bindable var timerViewModel: ReadingTimerViewModel
    @State private var showProgressUpdate = false
    @State private var showTimerView = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    if let progress = book.calculatedProgress {
                        CircularProgressRing(
                            progress: progress,
                            size: 80,
                            lineWidth: 5,
                            showPercentage: false
                        )
                    }

                    BookCoverView(coverData: book.coverImageData, title: book.title, cornerRadius: 6)
                        .frame(width: 56, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(AppTheme.Typography.cardTitle)
                        .lineLimit(2)

                    Text(book.authorsDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let page = book.currentPage, let total = book.pageCount {
                        Text("Page \(page) of \(total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let pace = viewModel.readingPace(for: book.isbn), pace > 0 {
                        if let current = book.currentPage, let total = book.pageCount, current < total {
                            let remaining = total - current
                            let daysLeft = Int(ceil(Double(remaining) / pace))
                            Text("~\(daysLeft) days left")
                                .font(.caption2)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    timerViewModel.startSession(for: book)
                    showTimerView = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                        Text("Read")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(AppTheme.Gradients.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button {
                    showProgressUpdate = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Update")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .themedCard()
        .sheet(isPresented: $showProgressUpdate) {
            let sessions = viewModel.fetchReadingSessions(for: book.isbn)
            ProgressUpdateView(
                book: book,
                previousPage: sessions.first?.page,
                readingPace: viewModel.readingPace(for: book.isbn)
            ) { page, percentage in
                viewModel.updateProgress(book, page: page, percentage: percentage)
            }
        }
        .sheet(isPresented: $showTimerView) {
            ReadingTimerView(timerViewModel: timerViewModel, viewModel: viewModel)
        }
    }
}

#if DEBUG
#Preview("Currently Reading Card") {
    CurrentlyReadingCard(
        book: .sampleCurrentlyReading,
        viewModel: BookshelfViewModel(),
        timerViewModel: ReadingTimerViewModel()
    )
    .padding()
}
#endif
