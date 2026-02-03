import Foundation

actor GoogleBooksService {
    static let shared = GoogleBooksService()

    private let baseURL = "https://www.googleapis.com/books/v1/volumes"

    private init() {}

    // MARK: - Search Methods

    /// Search with a general query string - Google Books handles fuzzy matching well
    func searchBooks(query: String) async throws -> [BookSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)?q=\(encodedQuery)&maxResults=15&printType=books"

        return try await performSearch(urlString: urlString)
    }

    /// Search with separate title and author - uses Google's search operators for better precision
    func searchBooks(title: String?, author: String?) async throws -> [BookSearchResult] {
        var queryParts: [String] = []

        if let title = title, !title.isEmpty {
            // Use intitle: for title-specific search
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            queryParts.append("intitle:\(cleanTitle)")
        }

        if let author = author, !author.isEmpty {
            // Use inauthor: for author-specific search
            let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
            queryParts.append("inauthor:\(cleanAuthor)")
        }

        guard !queryParts.isEmpty else {
            return []
        }

        let query = queryParts.joined(separator: "+")
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)?q=\(encodedQuery)&maxResults=15&printType=books"

        return try await performSearch(urlString: urlString)
    }

    /// Search by ISBN
    func searchByISBN(_ isbn: String) async throws -> BookSearchResult? {
        let cleanISBN = isbn.replacingOccurrences(of: "-", with: "")
        let urlString = "\(baseURL)?q=isbn:\(cleanISBN)&maxResults=1"

        let results = try await performSearch(urlString: urlString)
        return results.first
    }

    // MARK: - Private Methods

    private func performSearch(urlString: String) async throws -> [BookSearchResult] {
        guard let url = URL(string: urlString) else {
            throw GoogleBooksError.invalidURL
        }

        print("[GoogleBooks] Searching: \(urlString)")

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleBooksError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            print("[GoogleBooks] Error status: \(httpResponse.statusCode)")
            throw GoogleBooksError.requestFailed(httpResponse.statusCode)
        }

        let searchResponse = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)

        guard let items = searchResponse.items else {
            print("[GoogleBooks] No items found")
            return []
        }

        print("[GoogleBooks] Found \(items.count) results")

        return items.compactMap { item -> BookSearchResult? in
            let volumeInfo = item.volumeInfo

            // Try to get ISBN - prefer ISBN-13, fallback to ISBN-10
            let isbn = extractISBN(from: volumeInfo.industryIdentifiers)

            // Skip books without ISBN (we need it for our data model)
            guard let bookISBN = isbn else {
                return nil
            }

            // Build cover URL - prefer larger images
            let coverURL = buildCoverURL(from: volumeInfo.imageLinks)

            return BookSearchResult(
                isbn: bookISBN,
                title: volumeInfo.title,
                authors: volumeInfo.authors ?? [],
                publisher: volumeInfo.publisher,
                publishDate: volumeInfo.publishedDate,
                pageCount: volumeInfo.pageCount,
                description: volumeInfo.description,
                coverURL: coverURL
            )
        }
    }

    private func extractISBN(from identifiers: [GoogleBooksIdentifier]?) -> String? {
        guard let identifiers = identifiers else { return nil }

        // Prefer ISBN-13
        if let isbn13 = identifiers.first(where: { $0.type == "ISBN_13" })?.identifier {
            return isbn13
        }

        // Fallback to ISBN-10
        if let isbn10 = identifiers.first(where: { $0.type == "ISBN_10" })?.identifier {
            return isbn10
        }

        return nil
    }

    private func buildCoverURL(from imageLinks: GoogleBooksImageLinks?) -> URL? {
        guard let imageLinks = imageLinks else { return nil }

        // Try to get the best quality image available
        // Google Books provides different sizes: smallThumbnail, thumbnail, small, medium, large, extraLarge
        let urlString = imageLinks.thumbnail ?? imageLinks.smallThumbnail

        guard var urlString = urlString else { return nil }

        // Google Books returns HTTP URLs, convert to HTTPS
        if urlString.hasPrefix("http://") {
            urlString = urlString.replacingOccurrences(of: "http://", with: "https://")
        }

        // Request a larger image by modifying the zoom parameter
        urlString = urlString.replacingOccurrences(of: "zoom=1", with: "zoom=2")

        return URL(string: urlString)
    }
}

// MARK: - Google Books API Models

struct GoogleBooksResponse: Decodable {
    let totalItems: Int
    let items: [GoogleBooksItem]?
}

struct GoogleBooksItem: Decodable {
    let volumeInfo: GoogleBooksVolumeInfo
}

struct GoogleBooksVolumeInfo: Decodable {
    let title: String
    let authors: [String]?
    let publisher: String?
    let publishedDate: String?
    let description: String?
    let pageCount: Int?
    let industryIdentifiers: [GoogleBooksIdentifier]?
    let imageLinks: GoogleBooksImageLinks?
}

struct GoogleBooksIdentifier: Decodable {
    let type: String
    let identifier: String
}

struct GoogleBooksImageLinks: Decodable {
    let smallThumbnail: String?
    let thumbnail: String?
}

// MARK: - Errors

enum GoogleBooksError: LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(Int)
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from Google Books"
        case .requestFailed(let code):
            return "Request failed with status code \(code)"
        case .noResults:
            return "No books found"
        }
    }
}
