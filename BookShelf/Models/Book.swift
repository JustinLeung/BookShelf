import Foundation
import SwiftData

enum ReadStatus: String, Codable, CaseIterable {
    case wantToRead = "want_to_read"
    case read = "read"

    var displayName: String {
        switch self {
        case .wantToRead: return "Want to Read"
        case .read: return "Read"
        }
    }
}

@Model
final class Book {
    var isbn: String
    var title: String
    var authors: [String]
    var publisher: String?
    var publishDate: String?
    var pageCount: Int?
    var bookDescription: String?
    @Attribute(.externalStorage) var coverImageData: Data?
    var dateAdded: Date
    var readStatusRaw: String = ReadStatus.wantToRead.rawValue

    var readStatus: ReadStatus {
        get { ReadStatus(rawValue: readStatusRaw) ?? .wantToRead }
        set { readStatusRaw = newValue.rawValue }
    }

    init(
        isbn: String,
        title: String,
        authors: [String] = [],
        publisher: String? = nil,
        publishDate: String? = nil,
        pageCount: Int? = nil,
        bookDescription: String? = nil,
        coverImageData: Data? = nil,
        dateAdded: Date = Date(),
        readStatus: ReadStatus = .wantToRead
    ) {
        self.isbn = isbn
        self.title = title
        self.authors = authors
        self.publisher = publisher
        self.publishDate = publishDate
        self.pageCount = pageCount
        self.bookDescription = bookDescription
        self.coverImageData = coverImageData
        self.dateAdded = dateAdded
        self.readStatusRaw = readStatus.rawValue
    }

    var authorsDisplay: String {
        authors.isEmpty ? "Unknown Author" : authors.joined(separator: ", ")
    }

    var amazonURL: URL? {
        let cleanISBN = isbn.replacingOccurrences(of: "-", with: "")
        return URL(string: "https://www.amazon.com/dp/\(cleanISBN)")
    }

    var audibleURL: URL? {
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        return URL(string: "https://www.audible.com/search?keywords=\(encodedTitle)")
    }
}

struct BookSearchResult: Identifiable {
    let id = UUID()
    let isbn: String
    let title: String
    let authors: [String]
    let publisher: String?
    let publishDate: String?
    let pageCount: Int?
    let description: String?
    let coverURL: URL?

    func toBook(coverData: Data? = nil) -> Book {
        Book(
            isbn: isbn,
            title: title,
            authors: authors,
            publisher: publisher,
            publishDate: publishDate,
            pageCount: pageCount,
            bookDescription: description,
            coverImageData: coverData
        )
    }
}
