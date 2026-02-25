import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
class BookshelfViewModel {
    var books: [Book] = []
    var searchResults: [BookSearchResult] = []
    var isLoading = false
    var errorMessage: String?
    var showError = false

    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchBooks()
    }

    func fetchBooks() {
        guard let modelContext else { return }

        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])

        do {
            books = try modelContext.fetch(descriptor)
        } catch {
            showError(message: "Failed to fetch books: \(error.localizedDescription)")
        }
    }

    func lookupBook(isbn: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // Try Google Books first for ISBN lookup
            if let result = try await GoogleBooksService.shared.searchByISBN(isbn) {
                await addBookFromResult(result)
            } else {
                // Fallback to Open Library
                let result = try await BookAPIService.shared.fetchBook(isbn: isbn)
                await addBookFromResult(result)
            }
        } catch {
            showError(message: error.localizedDescription)
        }

        isLoading = false
    }

    func searchBooks(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Use smart search (Google Books primary, Open Library fallback)
            searchResults = try await BookAPIService.shared.smartSearch(query: query)
        } catch {
            showError(message: error.localizedDescription)
        }

        isLoading = false
    }

    func addBookFromResult(_ result: BookSearchResult) async {
        guard let modelContext else { return }

        // Check if book already exists
        let isbn = result.isbn
        let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.isbn == isbn })
        if let existingBooks = try? modelContext.fetch(descriptor), !existingBooks.isEmpty {
            showError(message: "This book is already in your shelf")
            return
        }

        // Fetch cover image
        var coverData: Data?
        if let coverURL = result.coverURL {
            do {
                coverData = try await BookAPIService.shared.fetchCoverImage(url: coverURL)
                if let data = coverData {
                    await ImageCacheService.shared.cacheImage(data, for: result.isbn)
                }
            } catch {
                // Cover fetch failed, continue without cover
            }
        }

        let book = result.toBook(coverData: coverData)
        modelContext.insert(book)

        do {
            try modelContext.save()
            fetchBooks()
        } catch {
            showError(message: "Failed to save book: \(error.localizedDescription)")
        }
    }

    func deleteBook(_ book: Book) {
        guard let modelContext else { return }

        modelContext.delete(book)

        do {
            try modelContext.save()
            fetchBooks()
        } catch {
            showError(message: "Failed to delete book: \(error.localizedDescription)")
        }
    }

    func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            deleteBook(books[index])
        }
    }

    func toggleReadStatus(_ book: Book) {
        let newStatus: ReadStatus
        switch book.readStatus {
        case .wantToRead: newStatus = .currentlyReading
        case .currentlyReading: newStatus = .read
        case .read: newStatus = .wantToRead
        }
        setReadStatus(book, status: newStatus)
    }

    func setReadStatus(_ book: Book, status: ReadStatus) {
        guard let modelContext else { return }

        book.readStatus = status

        // Auto-set dates on status transitions
        switch status {
        case .currentlyReading:
            if book.dateStarted == nil {
                book.dateStarted = Date()
            }
            book.dateFinished = nil
        case .read:
            if book.dateStarted == nil {
                book.dateStarted = Date()
            }
            if book.dateFinished == nil {
                book.dateFinished = Date()
            }
        case .wantToRead:
            book.dateStarted = nil
            book.dateFinished = nil
        }

        // Clear rating when not "read"
        if status != .read {
            book.rating = nil
        }

        do {
            try modelContext.save()
            fetchBooks()
        } catch {
            showError(message: "Failed to update book: \(error.localizedDescription)")
        }
    }

    func updateDateStarted(_ book: Book, date: Date?) {
        guard let modelContext else { return }
        book.dateStarted = date
        do {
            try modelContext.save()
            fetchBooks()
        } catch {
            showError(message: "Failed to update date: \(error.localizedDescription)")
        }
    }

    func updateDateFinished(_ book: Book, date: Date?) {
        guard let modelContext else { return }
        book.dateFinished = date
        do {
            try modelContext.save()
            fetchBooks()
        } catch {
            showError(message: "Failed to update date: \(error.localizedDescription)")
        }
    }

    func setRating(_ book: Book, rating: Int?) {
        guard let modelContext else { return }
        guard book.readStatus == .read else { return }

        if let rating {
            book.rating = max(1, min(5, rating))
        } else {
            book.rating = nil
        }

        do {
            try modelContext.save()
            fetchBooks()
        } catch {
            showError(message: "Failed to update rating: \(error.localizedDescription)")
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    func clearSearch() {
        searchResults = []
    }

    func isBookInShelf(isbn: String) -> Bool {
        books.contains { $0.isbn == isbn }
    }
}
