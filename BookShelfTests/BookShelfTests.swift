import Foundation
import Testing
@testable import BookShelf

// MARK: - ReadStatus Tests

@Suite("ReadStatus")
struct ReadStatusTests {
    @Test("rawValue round-trips through init")
    func rawValueRoundTrip() {
        for status in ReadStatus.allCases {
            let restored = ReadStatus(rawValue: status.rawValue)
            #expect(restored == status)
        }
    }

    @Test("rawValue strings match expected values")
    func rawValues() {
        #expect(ReadStatus.wantToRead.rawValue == "want_to_read")
        #expect(ReadStatus.read.rawValue == "read")
    }

    @Test("displayName returns human-readable text")
    func displayName() {
        #expect(ReadStatus.wantToRead.displayName == "Want to Read")
        #expect(ReadStatus.read.displayName == "Read")
    }
}

// MARK: - Book Tests

@Suite("Book")
struct BookTests {
    @Test("authorsDisplay joins multiple authors")
    func authorsDisplayMultiple() {
        let book = Book(isbn: "1234567890", title: "Test", authors: ["Alice", "Bob"])
        #expect(book.authorsDisplay == "Alice, Bob")
    }

    @Test("authorsDisplay returns placeholder when empty")
    func authorsDisplayEmpty() {
        let book = Book(isbn: "1234567890", title: "Test", authors: [])
        #expect(book.authorsDisplay == "Unknown Author")
    }

    @Test("amazonURL uses ISBN with hyphens removed")
    func amazonURL() {
        let book = Book(isbn: "978-0-13-468599-1", title: "Test")
        #expect(book.amazonURL?.absoluteString == "https://www.amazon.com/dp/9780134685991")
    }

    @Test("audibleURL encodes title in search query")
    func audibleURL() {
        let book = Book(isbn: "1234567890", title: "Swift Programming")
        #expect(book.audibleURL?.absoluteString == "https://www.audible.com/search?keywords=Swift%20Programming")
    }

    @Test("readStatus defaults to wantToRead")
    func defaultReadStatus() {
        let book = Book(isbn: "1234567890", title: "Test")
        #expect(book.readStatus == .wantToRead)
    }
}

// MARK: - Book Rating Tests

@Suite("BookRating")
struct BookRatingTests {
    @Test("rating defaults to nil")
    func defaultRating() {
        let book = Book(isbn: "1234567890", title: "Test")
        #expect(book.rating == nil)
    }

    @Test("init accepts a rating value")
    func initWithRating() {
        let book = Book(isbn: "1234567890", title: "Test", rating: 4)
        #expect(book.rating == 4)
    }

    @Test("rating can be set within valid range 1-5")
    func validRange() {
        let book = Book(isbn: "1234567890", title: "Test")
        for value in 1...5 {
            book.rating = value
            #expect(book.rating == value)
        }
    }

    @Test("rating can be set to nil")
    func nilRating() {
        let book = Book(isbn: "1234567890", title: "Test", rating: 3)
        book.rating = nil
        #expect(book.rating == nil)
    }

    @Test("ratingDisplay returns star string for rated books")
    func ratingDisplayWithRating() {
        let book = Book(isbn: "1234567890", title: "Test", rating: 3)
        #expect(book.ratingDisplay == "★★★☆☆")
    }

    @Test("ratingDisplay returns empty string for unrated books")
    func ratingDisplayWithoutRating() {
        let book = Book(isbn: "1234567890", title: "Test")
        #expect(book.ratingDisplay == "")
    }

    @Test("ratingDisplay shows all stars filled for rating of 5")
    func ratingDisplayFiveStars() {
        let book = Book(isbn: "1234567890", title: "Test", rating: 5)
        #expect(book.ratingDisplay == "★★★★★")
    }

    @Test("ratingDisplay shows one star filled for rating of 1")
    func ratingDisplayOneStar() {
        let book = Book(isbn: "1234567890", title: "Test", rating: 1)
        #expect(book.ratingDisplay == "★☆☆☆☆")
    }
}

// MARK: - BookSearchResult Tests

@Suite("BookSearchResult")
struct BookSearchResultTests {
    @Test("toBook maps all fields correctly")
    func toBookMapping() {
        let result = BookSearchResult(
            isbn: "1234567890",
            title: "Test Book",
            authors: ["Author A"],
            publisher: "Publisher",
            publishDate: "2024",
            pageCount: 300,
            description: "A test book",
            coverURL: URL(string: "https://example.com/cover.jpg")
        )

        let coverData = Data([0x00, 0x01])
        let book = result.toBook(coverData: coverData)

        #expect(book.isbn == "1234567890")
        #expect(book.title == "Test Book")
        #expect(book.authors == ["Author A"])
        #expect(book.publisher == "Publisher")
        #expect(book.publishDate == "2024")
        #expect(book.pageCount == 300)
        #expect(book.bookDescription == "A test book")
        #expect(book.coverImageData == coverData)
    }

    @Test("toBook defaults coverData to nil")
    func toBookNoCoverData() {
        let result = BookSearchResult(
            isbn: "1234567890",
            title: "Test",
            authors: [],
            publisher: nil,
            publishDate: nil,
            pageCount: nil,
            description: nil,
            coverURL: nil
        )

        let book = result.toBook()
        #expect(book.coverImageData == nil)
    }
}
