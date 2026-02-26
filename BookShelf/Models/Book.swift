import Foundation
import SwiftData

enum ReadStatus: String, Codable, CaseIterable {
    case wantToRead = "want_to_read"
    case currentlyReading = "currently_reading"
    case read = "read"

    var displayName: String {
        switch self {
        case .wantToRead: return "Want to Read"
        case .currentlyReading: return "Currently Reading"
        case .read: return "Read"
        }
    }

    var icon: String {
        switch self {
        case .wantToRead: return "bookmark.fill"
        case .currentlyReading: return "book.fill"
        case .read: return "checkmark.circle.fill"
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
    var rating: Int?
    var dateStarted: Date?
    var dateFinished: Date?

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
        readStatus: ReadStatus = .wantToRead,
        rating: Int? = nil,
        dateStarted: Date? = nil,
        dateFinished: Date? = nil
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
        self.rating = rating
        self.dateStarted = dateStarted
        self.dateFinished = dateFinished
    }

    var daysToRead: Int? {
        guard let start = dateStarted, let finish = dateFinished else { return nil }
        return Calendar.current.dateComponents([.day], from: start, to: finish).day
    }

    var ratingDisplay: String {
        guard let rating else { return "" }
        return String(repeating: "★", count: rating) + String(repeating: "☆", count: 5 - rating)
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

// MARK: - Preview Sample Data

#if DEBUG
extension Book {
    static var sampleWantToRead: Book {
        Book(
            isbn: "9780547928227",
            title: "The Hobbit",
            authors: ["J.R.R. Tolkien"],
            publisher: "Mariner Books",
            publishDate: "2012",
            pageCount: 300,
            bookDescription: "Bilbo Baggins is a hobbit who enjoys a comfortable, unambitious life. But his contentment is disturbed when the wizard Gandalf and a company of thirteen dwarves arrive on his doorstep."
        )
    }

    static var sampleCurrentlyReading: Book {
        Book(
            isbn: "9780451524935",
            title: "1984",
            authors: ["George Orwell"],
            publisher: "Signet Classic",
            publishDate: "1961",
            pageCount: 328,
            bookDescription: "Among the seminal texts of the 20th century, Nineteen Eighty-Four is a rare work that grows more haunting as its prophecies are fulfilled.",
            readStatus: .currentlyReading,
            dateStarted: Calendar.current.date(byAdding: .day, value: -14, to: Date())
        )
    }

    static var sampleReadWithRating: Book {
        Book(
            isbn: "9780061120084",
            title: "To Kill a Mockingbird",
            authors: ["Harper Lee"],
            publisher: "Harper Perennial",
            publishDate: "2006",
            pageCount: 336,
            bookDescription: "The unforgettable novel of a childhood in a sleepy Southern town and the crisis of conscience that rocked it.",
            readStatus: .read,
            rating: 5,
            dateStarted: Calendar.current.date(byAdding: .day, value: -60, to: Date()),
            dateFinished: Calendar.current.date(byAdding: .day, value: -30, to: Date())
        )
    }

    static var sampleReadNoRating: Book {
        Book(
            isbn: "9780743273565",
            title: "The Great Gatsby",
            authors: ["F. Scott Fitzgerald"],
            publisher: "Scribner",
            publishDate: "2004",
            pageCount: 180,
            bookDescription: "The story of the mysteriously wealthy Jay Gatsby and his love for the beautiful Daisy Buchanan.",
            readStatus: .read,
            dateStarted: Calendar.current.date(byAdding: .day, value: -90, to: Date()),
            dateFinished: Calendar.current.date(byAdding: .day, value: -75, to: Date())
        )
    }

    static var sampleLongTitle: Book {
        Book(
            isbn: "9780062316110",
            title: "Sapiens: A Brief History of Humankind",
            authors: ["Yuval Noah Harari"],
            publisher: "Harper",
            publishDate: "2015",
            pageCount: 464,
            bookDescription: "A brief history of humankind, exploring the ways in which biology and history have defined us."
        )
    }

    static var sampleBooks: [Book] {
        [sampleWantToRead, sampleCurrentlyReading, sampleReadWithRating, sampleReadNoRating, sampleLongTitle]
    }

    @MainActor
    static var previewContainer: ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(for: Book.self, configurations: config)
        for book in sampleBooks {
            container.mainContext.insert(book)
        }
        return container
    }
}

extension BookSearchResult {
    static var sampleResults: [BookSearchResult] {
        [
            BookSearchResult(
                isbn: "9780547928227",
                title: "The Hobbit",
                authors: ["J.R.R. Tolkien"],
                publisher: "Mariner Books",
                publishDate: "2012",
                pageCount: 300,
                description: "A great adventure story.",
                coverURL: nil
            ),
            BookSearchResult(
                isbn: "9780451524935",
                title: "1984",
                authors: ["George Orwell"],
                publisher: "Signet Classic",
                publishDate: "1961",
                pageCount: 328,
                description: "A dystopian novel.",
                coverURL: nil
            )
        ]
    }
}
#endif

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
