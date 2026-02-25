import SwiftUI
import SwiftData

struct BookshelfView: View {
    @Environment(\.modelContext) private var modelContext
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
                if viewModel.books.isEmpty {
                    emptyStateView
                } else {
                    booksListView
                }
            }
            .navigationTitle("Bookshelf")
            .onAppear {
                viewModel.setModelContext(modelContext)
            }
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
        ContentUnavailableView {
            Label("No Books Yet", systemImage: "books.vertical")
        } description: {
            Text("Scan a book barcode or search to add books to your shelf")
        }
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
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text("\(books.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
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

    var body: some View {
        VStack(spacing: 8) {
            bookCover
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

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
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var bookCover: some View {
        if let data = book.coverImageData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))

                VStack {
                    Image(systemName: "book.closed.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.accentColor)

                    Text(book.title)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                        .lineLimit(3)
                }
                .padding(8)
            }
        }
    }
}
