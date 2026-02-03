import Foundation

actor BookAPIService {
    static let shared = BookAPIService()

    private init() {}

    // MARK: - Unified Search (Google Books primary, Open Library fallback)

    // swiftlint:disable cyclomatic_complexity
    /// Smart search that tries Google Books first, then falls back to Open Library
    /// Results are scored and sorted by relevance to the query
    func smartSearch(query: String, author: String? = nil) async throws -> [BookSearchResult] {
        print("[BookAPI] Smart search - query: '\(query)', author: '\(author ?? "nil")'")

        var results: [BookSearchResult] = []
        var seenISBNs = Set<String>()

        // Helper to add results without duplicates
        func addResults(_ newResults: [BookSearchResult]) {
            for result in newResults where !seenISBNs.contains(result.isbn) {
                seenISBNs.insert(result.isbn)
                results.append(result)
            }
        }

        // Strategy 1: If we have both author and title, search combined FIRST (most specific)
        if let author = author, !author.isEmpty {
            do {
                let combinedQuery = "\(author) \(query)"
                let combinedResults = try await GoogleBooksService.shared.searchBooks(query: combinedQuery)
                if !combinedResults.isEmpty {
                    print("[BookAPI] Google Books (author+title) found \(combinedResults.count) results")
                    addResults(combinedResults)
                }
            } catch {
                print("[BookAPI] Google Books (author+title) error: \(error)")
            }

            // Also try author alone to get more results
            if results.count < 10 {
                do {
                    let authorResults = try await GoogleBooksService.shared.searchBooks(query: author)
                    if !authorResults.isEmpty {
                        print("[BookAPI] Google Books (author only) found \(authorResults.count) results")
                        addResults(authorResults)
                    }
                } catch {
                    print("[BookAPI] Google Books (author only) error: \(error)")
                }
            }
        }

        // Strategy 2: Try the title/query alone
        if results.count < 5 {
            do {
                let googleResults = try await GoogleBooksService.shared.searchBooks(query: query)
                if !googleResults.isEmpty {
                    print("[BookAPI] Google Books (query only) found \(googleResults.count) results")
                    addResults(googleResults)
                }
            } catch {
                print("[BookAPI] Google Books (query only) error: \(error)")
            }
        }

        // Strategy 3: If still no/few results, try Open Library as fallback
        if results.count < 3 {
            do {
                let olQuery = author != nil ? "\(author!) \(query)" : query
                let openLibResults = try await searchBooksOpenLibrary(query: olQuery)
                if !openLibResults.isEmpty {
                    print("[BookAPI] Open Library fallback found \(openLibResults.count) results")
                    addResults(openLibResults)
                }
            } catch {
                print("[BookAPI] Open Library fallback error: \(error)")
            }
        }

        // Score and sort results by relevance to the query
        let scoredResults = scoreAndSortResults(results, query: query, author: author)

        print("[BookAPI] Total unique results: \(scoredResults.count)")
        return scoredResults
    }
    // swiftlint:enable cyclomatic_complexity

    /// Scores results based on how well they match the query and author
    private func scoreAndSortResults(_ results: [BookSearchResult], query: String, author: String?) -> [BookSearchResult] {
        let queryWords = Set(query.lowercased().components(separatedBy: .whitespaces).filter { $0.count >= 2 })
        let authorWords = author.map { Set($0.lowercased().components(separatedBy: .whitespaces).filter { $0.count >= 2 }) } ?? []

        let scored = results.map { result -> (result: BookSearchResult, score: Int) in
            var score = 0
            let titleLower = result.title.lowercased()
            let titleWords = Set(titleLower.components(separatedBy: .whitespaces))

            // Score based on title word matches
            for word in queryWords {
                if titleWords.contains(word) {
                    score += 10 // Exact word match in title
                } else if titleLower.contains(word) {
                    score += 5 // Partial match in title
                }
            }

            // Bonus for author match
            if !authorWords.isEmpty {
                let resultAuthorLower = result.authors.joined(separator: " ").lowercased()
                for word in authorWords where resultAuthorLower.contains(word) {
                    score += 8
                }
            }

            // Bonus for exact title match
            if queryWords.isSubset(of: titleWords) {
                score += 20
            }

            return (result: result, score: score)
        }

        // Sort by score descending
        let sorted = scored.sorted { $0.score > $1.score }

        print("[BookAPI] Top 3 scored results:")
        for (index, item) in sorted.prefix(3).enumerated() {
            print("  \(index + 1). '\(item.result.title)' - score: \(item.score)")
        }

        return sorted.map { $0.result }
    }

    // MARK: - Open Library API

    func fetchBook(isbn: String) async throws -> BookSearchResult {
        let cleanISBN = isbn.replacingOccurrences(of: "-", with: "")
        let urlString = "https://openlibrary.org/isbn/\(cleanISBN).json"

        guard let url = URL(string: urlString) else {
            throw BookAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BookAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw BookAPIError.notFound
        }

        let bookData = try JSONDecoder().decode(OpenLibraryBook.self, from: data)

        // Fetch additional details from works if available
        var description: String?
        if let worksKey = bookData.works?.first?["key"] as? String {
            description = try? await fetchWorkDescription(key: worksKey)
        }

        let coverURL = URL(string: "https://covers.openlibrary.org/b/isbn/\(cleanISBN)-L.jpg")

        // Fetch author names
        var authorNames: [String] = []
        if let authors = bookData.authors {
            for author in authors {
                if let key = author["key"] as? String {
                    if let name = try? await fetchAuthorName(key: key) {
                        authorNames.append(name)
                    }
                }
            }
        }

        return BookSearchResult(
            isbn: cleanISBN,
            title: bookData.title,
            authors: authorNames,
            publisher: bookData.publishers?.first,
            publishDate: bookData.publish_date,
            pageCount: bookData.number_of_pages,
            description: description,
            coverURL: coverURL
        )
    }

    /// Search using Open Library API (used as fallback)
    func searchBooksOpenLibrary(query: String) async throws -> [BookSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://openlibrary.org/search.json?q=\(encodedQuery)&limit=20"

        guard let url = URL(string: urlString) else {
            throw BookAPIError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let searchResponse = try JSONDecoder().decode(OpenLibrarySearchResponse.self, from: data)

        return searchResponse.docs.compactMap { doc -> BookSearchResult? in
            guard let isbn = doc.isbn?.first else { return nil }

            let coverURL = URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-M.jpg")

            return BookSearchResult(
                isbn: isbn,
                title: doc.title,
                authors: doc.author_name ?? [],
                publisher: doc.publisher?.first,
                publishDate: doc.first_publish_year.map { String($0) },
                pageCount: doc.number_of_pages_median,
                description: nil,
                coverURL: coverURL
            )
        }
    }

    private func fetchAuthorName(key: String) async throws -> String {
        let urlString = "https://openlibrary.org\(key).json"
        guard let url = URL(string: urlString) else {
            throw BookAPIError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let author = try JSONDecoder().decode(OpenLibraryAuthor.self, from: data)
        return author.name
    }

    private func fetchWorkDescription(key: String) async throws -> String? {
        let urlString = "https://openlibrary.org\(key).json"
        guard let url = URL(string: urlString) else {
            throw BookAPIError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let work = try JSONDecoder().decode(OpenLibraryWork.self, from: data)

        if let desc = work.description {
            switch desc {
            case .string(let value):
                return value
            case .object(let obj):
                return obj["value"]
            }
        }
        return nil
    }

    func fetchCoverImage(url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BookAPIError.invalidResponse
        }

        return data
    }
}

// MARK: - API Models

struct OpenLibraryBook: Decodable {
    let title: String
    let authors: [[String: Any]]?
    let publishers: [String]?
    let publish_date: String?
    let number_of_pages: Int?
    let works: [[String: Any]]?

    enum CodingKeys: String, CodingKey {
        case title, publishers, publish_date, number_of_pages, authors, works
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        publishers = try container.decodeIfPresent([String].self, forKey: .publishers)
        publish_date = try container.decodeIfPresent(String.self, forKey: .publish_date)
        number_of_pages = try container.decodeIfPresent(Int.self, forKey: .number_of_pages)

        // Decode authors as array of dictionaries
        if let authorsData = try? container.decodeIfPresent([[String: String]].self, forKey: .authors) {
            authors = authorsData.map { $0 as [String: Any] }
        } else {
            authors = nil
        }

        // Decode works as array of dictionaries
        if let worksData = try? container.decodeIfPresent([[String: String]].self, forKey: .works) {
            works = worksData.map { $0 as [String: Any] }
        } else {
            works = nil
        }
    }
}

struct OpenLibraryAuthor: Decodable {
    let name: String
}

struct OpenLibraryWork: Decodable {
    let description: DescriptionValue?

    enum DescriptionValue: Decodable {
        case string(String)
        case object([String: String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
            } else if let objectValue = try? container.decode([String: String].self) {
                self = .object(objectValue)
            } else {
                throw DecodingError.typeMismatch(
                    DescriptionValue.self,
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected string or object")
                )
            }
        }
    }
}

struct OpenLibrarySearchResponse: Decodable {
    let docs: [OpenLibrarySearchDoc]
}

struct OpenLibrarySearchDoc: Decodable {
    let title: String
    let author_name: [String]?
    let isbn: [String]?
    let publisher: [String]?
    let first_publish_year: Int?
    let number_of_pages_median: Int?
}

// MARK: - Errors

enum BookAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case notFound
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .notFound:
            return "Book not found"
        case .decodingError:
            return "Failed to decode book data"
        }
    }
}
