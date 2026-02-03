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
        guard let modelContext else { return }

        book.readStatus = book.readStatus == .wantToRead ? .read : .wantToRead

        do {
            try modelContext.save()
            fetchBooks()
        } catch {
            showError(message: "Failed to update book: \(error.localizedDescription)")
        }
    }

    func setReadStatus(_ book: Book, status: ReadStatus) {
        guard let modelContext else { return }

        book.readStatus = status

        do {
            try modelContext.save()
            fetchBooks()
        } catch {
            showError(message: "Failed to update book: \(error.localizedDescription)")
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
