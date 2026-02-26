import SwiftUI

struct BookshelfView: View {
    @Bindable var viewModel: BookshelfViewModel

    @State private var selectedBook: Book?
    @State private var showDeleteConfirmation = false
    @State private var bookToDelete: Book?

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    private var currentlyReadingBooks: [Book] {
        viewModel.books.filter { $0.readStatus == .currentlyReading }
    }

    private var wantToReadBooks: [Book] {
        viewModel.books.filter { $0.readStatus == .wantToRead }
    }

    private var readBooks: [Book] {
        viewModel.books.filter { $0.readStatus == .read }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.isInitialized {
                    ProgressView()
                } else if viewModel.books.isEmpty {
                    emptyStateView
                } else {
                    booksListView
                }
            }
            .navigationTitle("Bookshelf")
            .sheet(item: $selectedBook) { book in
                BookDetailView(book: book, viewModel: viewModel)
            }
            .confirmationDialog(
                "Delete Book",
                isPresented: $showDeleteConfirmation,
                presenting: bookToDelete
            ) { book in
                Button("Delete", role: .destructive) {
                    viewModel.deleteBook(book)
                }
                Button("Cancel", role: .cancel) {}
            } message: { book in
                Text("Are you sure you want to remove \"\(book.title)\" from your shelf?")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 36))
                .foregroundStyle(Color.accentColor)
                .frame(width: 80, height: 80)
                .background(Circle().fill(Color.accentColor.opacity(0.08)))

            Text("No Books Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Scan a book barcode or search to add books to your shelf")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var booksListView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Currently Reading section (shown first, most prominent)
                if !currentlyReadingBooks.isEmpty {
                    bookSection(title: "Currently Reading", books: currentlyReadingBooks)
                }

                // Want to Read section
                if !wantToReadBooks.isEmpty {
                    bookSection(title: "Want to Read", books: wantToReadBooks)
                }

                // Read section
                if !readBooks.isEmpty {
                    bookSection(title: "Read", books: readBooks)
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            viewModel.fetchBooks()
        }
    }

    private func bookSection(title: String, books: [Book]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 4, height: 22)

                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text("\(books.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(books) { book in
                    BookGridItem(book: book)
                        .onTapGesture {
                            selectedBook = book
                        }
                        .contextMenu {
                            Button {
                                selectedBook = book
                            } label: {
                                Label("View Details", systemImage: "info.circle")
                            }

                            // Show status options the book is NOT currently in
                            ForEach(ReadStatus.allCases.filter { $0 != book.readStatus }, id: \.self) { status in
                                Button {
                                    viewModel.setReadStatus(book, status: status)
                                } label: {
                                    Label(status.displayName, systemImage: status.icon)
                                }
                            }

                            Divider()

                            if let url = book.amazonURL {
                                Link(destination: url) {
                                    Label("Buy on Amazon", systemImage: "cart")
                                }
                            }

                            if let url = book.audibleURL {
                                Link(destination: url) {
                                    Label("Find on Audible", systemImage: "headphones")
                                }
                            }

                            Divider()

                            Button(role: .destructive) {
                                bookToDelete = book
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Book Grid Item

struct BookGridItem: View {
    let book: Book
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 8) {
            BookCoverView(coverData: book.coverImageData, title: book.title)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)

            if book.readStatus == .currentlyReading, let progress = book.calculatedProgress {
                ReadingProgressBar(progress: progress, height: 3)
            }

            VStack(spacing: 2) {
                Text(book.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(book.authorsDisplay)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if book.readStatus == .read, book.rating != nil {
                    StarRatingView(
                        rating: book.rating,
                        interactive: false,
                        starSize: 10
                    )
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Populated Bookshelf") {
    BookshelfView(viewModel: BookshelfViewModel())
        .modelContainer(Book.previewContainer)
}

#Preview("Empty Bookshelf") {
    BookshelfView(viewModel: BookshelfViewModel())
        .modelContainer(for: Book.self, inMemory: true)
}

#Preview("Book Grid Item - No Cover") {
    BookGridItem(book: .sampleWantToRead)
        .frame(width: 140)
        .padding()
}

#Preview("Book Grid Item - With Rating") {
    BookGridItem(book: .sampleReadWithRating)
        .frame(width: 140)
        .padding()
}

#Preview("Book Grid Item - Long Title") {
    BookGridItem(book: .sampleLongTitle)
        .frame(width: 140)
        .padding()
}
#endif
