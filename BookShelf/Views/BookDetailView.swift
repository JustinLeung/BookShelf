import SwiftUI

struct BookDetailView: View {
    let book: Book
    @Bindable var viewModel: BookshelfViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showProgressUpdate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Cover Image
                    BookCoverView(coverData: book.coverImageData, title: book.title, cornerRadius: 12)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                    // Title and Author
                    VStack(spacing: 8) {
                        Text(book.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text(book.authorsDisplay)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Read Status Toggle
                    HStack(spacing: 12) {
                        ForEach(ReadStatus.allCases, id: \.self) { status in
                            Button {
                                viewModel.setReadStatus(book, status: status)
                            } label: {
                                HStack {
                                    Image(systemName: status.icon)
                                    Text(status.displayName)
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(book.readStatus == status ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(book.readStatus == status ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Reading Progress (only for currently reading)
                    if book.readStatus == .currentlyReading {
                        VStack(spacing: 12) {
                            if let progress = book.calculatedProgress {
                                HStack {
                                    if let page = book.currentPage, let total = book.pageCount {
                                        Text("Page \(page) of \(total)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(Int(progress * 100))%")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                }

                                ReadingProgressBar(progress: progress, height: 8)
                            }

                            Button {
                                showProgressUpdate = true
                            } label: {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                    Text("Update Progress")
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.horizontal)
                        .sheet(isPresented: $showProgressUpdate) {
                            ProgressUpdateView(book: book) { page, percentage in
                                viewModel.updateProgress(book, page: page, percentage: percentage)
                            }
                        }
                    }

                    // Star Rating (only for read books)
                    if book.readStatus == .read {
                        VStack(spacing: 4) {
                            Text("Your Rating")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            StarRatingView(
                                rating: book.rating,
                                interactive: true,
                                starSize: 32
                            ) { newRating in
                                viewModel.setRating(book, rating: newRating)
                            }
                        }
                    }

                    // Purchase Buttons
                    VStack(spacing: 12) {
                        if let amazonURL = book.amazonURL {
                            Link(destination: amazonURL) {
                                HStack {
                                    Image(systemName: "cart.fill")
                                    Text("Buy on Amazon")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        if let audibleURL = book.audibleURL {
                            Link(destination: audibleURL) {
                                HStack {
                                    Image(systemName: "headphones")
                                    Text("Find on Audible")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Book Details
                    VStack(alignment: .leading, spacing: 16) {
                        if let description = book.bookDescription {
                            DetailSection(title: "Description") {
                                Text(description)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }

                        DetailSection(title: "Details") {
                            VStack(alignment: .leading, spacing: 8) {
                                DetailRow(label: "ISBN", value: book.isbn)

                                if let publisher = book.publisher {
                                    DetailRow(label: "Publisher", value: publisher)
                                }

                                if let publishDate = book.publishDate {
                                    DetailRow(label: "Published", value: publishDate)
                                }

                                if let pageCount = book.pageCount {
                                    DetailRow(label: "Pages", value: "\(pageCount)")
                                }

                                if let _ = book.rating {
                                    DetailRow(label: "Rating", value: book.ratingDisplay)
                                }

                                if let dateStarted = book.dateStarted {
                                    DetailRow(label: "Started", value: dateStarted.formatted(date: .abbreviated, time: .omitted))
                                }

                                if let dateFinished = book.dateFinished {
                                    DetailRow(label: "Finished", value: dateFinished.formatted(date: .abbreviated, time: .omitted))
                                }

                                if let days = book.daysToRead {
                                    DetailRow(label: "Days to Read", value: "\(days) days")
                                }

                                DetailRow(label: "Added", value: book.dateAdded.formatted(date: .abbreviated, time: .omitted))
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 32)
                }
                .padding(.vertical)
            }
            .navigationTitle("Book Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        viewModel.deleteBook(book)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }
}

// MARK: - Helper Views

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Want to Read") {
    BookDetailView(book: .sampleWantToRead, viewModel: BookshelfViewModel())
}

#Preview("Currently Reading") {
    BookDetailView(book: .sampleCurrentlyReading, viewModel: BookshelfViewModel())
}

#Preview("Read with Rating") {
    BookDetailView(book: .sampleReadWithRating, viewModel: BookshelfViewModel())
}

#Preview("Read without Rating") {
    BookDetailView(book: .sampleReadNoRating, viewModel: BookshelfViewModel())
}

#Preview("Detail Section") {
    DetailSection(title: "Description") {
        Text("A sample description of a book that spans multiple lines to show how the section looks with longer content.")
    }
    .padding()
}

#Preview("Detail Row") {
    DetailRow(label: "Publisher", value: "Harper Perennial")
        .padding()
}
#endif
