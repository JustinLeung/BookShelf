import Foundation
import SwiftData
import XCTest
@testable import BookShelf

// MARK: - Shared Test Helpers

class BookShelfTestCase: XCTestCase {
    var testContext: ModelContext!

    @MainActor
    override func setUp() {
        super.setUp()
        // Reuse the app's in-memory container (isTesting makes it in-memory).
        // Creating a second ModelContainer for the same @Model types crashes SwiftData.
        testContext = ModelContext(BookShelfApp.sharedModelContainer)
    }

    @MainActor
    override func tearDown() {
        // Delete all objects so tests stay isolated
        try? testContext.delete(model: ReadingProgressEntry.self)
        try? testContext.delete(model: ReadingGoal.self)
        try? testContext.delete(model: ReadingChallenge.self)
        try? testContext.delete(model: ReadingSession.self)
        try? testContext.delete(model: BookNote.self)
        try? testContext.delete(model: StreakFreeze.self)
        try? testContext.delete(model: Book.self)
        try? testContext.save()
        testContext = nil
        super.tearDown()
    }

    @MainActor
    func makeBook(
        isbn: String = "1234567890",
        title: String = "Test",
        authors: [String] = [],
        pageCount: Int? = nil,
        readStatus: ReadStatus = .wantToRead,
        rating: Int? = nil,
        dateStarted: Date? = nil,
        dateFinished: Date? = nil,
        currentPage: Int? = nil,
        progressPercentage: Double? = nil
    ) -> Book {
        let book = Book(
            isbn: isbn,
            title: title,
            authors: authors,
            pageCount: pageCount,
            readStatus: readStatus,
            rating: rating,
            dateStarted: dateStarted,
            dateFinished: dateFinished,
            currentPage: currentPage,
            progressPercentage: progressPercentage
        )
        testContext.insert(book)
        return book
    }
}

// MARK: - ReadStatus Tests

final class ReadStatusTests: XCTestCase {
    func testRawValueRoundTrip() {
        for status in ReadStatus.allCases {
            let restored = ReadStatus(rawValue: status.rawValue)
            XCTAssertEqual(restored, status)
        }
    }

    func testRawValues() {
        XCTAssertEqual(ReadStatus.wantToRead.rawValue, "want_to_read")
        XCTAssertEqual(ReadStatus.read.rawValue, "read")
    }

    func testDisplayName() {
        XCTAssertEqual(ReadStatus.wantToRead.displayName, "Want to Read")
        XCTAssertEqual(ReadStatus.currentlyReading.displayName, "Reading")
        XCTAssertEqual(ReadStatus.read.displayName, "Read")
    }
}

// MARK: - Book Tests

final class BookTests: BookShelfTestCase {
    @MainActor
    func testAuthorsDisplayMultiple() {
        let book = makeBook(authors: ["Alice", "Bob"])
        XCTAssertEqual(book.authorsDisplay, "Alice, Bob")
    }

    @MainActor
    func testAuthorsDisplayEmpty() {
        let book = makeBook(authors: [])
        XCTAssertEqual(book.authorsDisplay, "Unknown Author")
    }

    @MainActor
    func testAmazonURL() {
        let book = makeBook(isbn: "978-0-13-468599-1")
        XCTAssertEqual(book.amazonURL?.absoluteString, "https://www.amazon.com/dp/9780134685991")
    }

    @MainActor
    func testAudibleURL() {
        let book = makeBook(title: "Swift Programming")
        XCTAssertEqual(book.audibleURL?.absoluteString, "https://www.audible.com/search?keywords=Swift%20Programming")
    }

    @MainActor
    func testDefaultReadStatus() {
        let book = makeBook()
        XCTAssertEqual(book.readStatus, .wantToRead)
    }
}

// MARK: - Reading Progress Tests

final class ReadingProgressTests: BookShelfTestCase {
    @MainActor
    func testCalculatedProgressFromPages() {
        let book = makeBook(pageCount: 200, currentPage: 100)
        XCTAssertEqual(book.calculatedProgress, 0.5)
    }

    @MainActor
    func testCalculatedProgressFallback() {
        let book = makeBook(progressPercentage: 0.75)
        XCTAssertEqual(book.calculatedProgress, 0.75)
    }

    @MainActor
    func testCalculatedProgressNil() {
        let book = makeBook()
        XCTAssertNil(book.calculatedProgress)
    }

    @MainActor
    func testCalculatedProgressPrefersPages() {
        let book = makeBook(pageCount: 100, currentPage: 25, progressPercentage: 0.9)
        XCTAssertEqual(book.calculatedProgress, 0.25)
    }

    @MainActor
    func testCalculatedProgressClamped() {
        let overBook = makeBook(isbn: "over", pageCount: 100, currentPage: 150)
        XCTAssertEqual(overBook.calculatedProgress, 1.0)

        let negativeBook = makeBook(isbn: "neg", progressPercentage: -0.5)
        XCTAssertEqual(negativeBook.calculatedProgress, 0.0)

        let overPercentage = makeBook(isbn: "pct", progressPercentage: 1.5)
        XCTAssertEqual(overPercentage.calculatedProgress, 1.0)
    }

    @MainActor
    func testCalculatedProgressZeroPageCount() {
        let book = makeBook(pageCount: 0, currentPage: 10)
        XCTAssertNil(book.calculatedProgress)
    }

    @MainActor
    func testProgressDefaultsToNil() {
        let book = makeBook()
        XCTAssertNil(book.currentPage)
        XCTAssertNil(book.progressPercentage)
    }

    @MainActor
    func testSampleCurrentlyReadingProgress() {
        let book = makeBook(
            isbn: "9780451524935",
            title: "1984",
            authors: ["George Orwell"],
            pageCount: 328,
            readStatus: .currentlyReading,
            dateStarted: Calendar.current.date(byAdding: .day, value: -14, to: Date()),
            currentPage: 124
        )
        XCTAssertEqual(book.currentPage, 124)
        XCTAssertNotNil(book.calculatedProgress)
        XCTAssertGreaterThan(book.calculatedProgress!, 0.0)
        XCTAssertLessThan(book.calculatedProgress!, 1.0)
    }
}

// MARK: - ReadingProgressEntry Tests

final class ReadingProgressEntryTests: BookShelfTestCase {
    @MainActor
    func testPagesReadDiff() {
        let current = ReadingProgressEntry(bookISBN: "111", page: 100)
        let previous = ReadingProgressEntry(bookISBN: "111", page: 75)
        testContext.insert(current)
        testContext.insert(previous)
        XCTAssertEqual(current.pagesRead(since: previous), 25)
    }

    @MainActor
    func testPagesReadNilCurrentPage() {
        let current = ReadingProgressEntry(bookISBN: "111", page: nil)
        let previous = ReadingProgressEntry(bookISBN: "111", page: 75)
        testContext.insert(current)
        testContext.insert(previous)
        XCTAssertNil(current.pagesRead(since: previous))
    }

    @MainActor
    func testPagesReadNoPrevious() {
        let current = ReadingProgressEntry(bookISBN: "111", page: 50)
        testContext.insert(current)
        XCTAssertEqual(current.pagesRead(since: nil), 50)
    }

    @MainActor
    func testPagesReadNoDiff() {
        let current = ReadingProgressEntry(bookISBN: "111", page: 50)
        let previous = ReadingProgressEntry(bookISBN: "111", page: 50)
        let earlier = ReadingProgressEntry(bookISBN: "111", page: 75)
        testContext.insert(current)
        testContext.insert(previous)
        testContext.insert(earlier)
        XCTAssertNil(current.pagesRead(since: previous))
        XCTAssertNil(current.pagesRead(since: earlier))
    }

    @MainActor
    func testDefaultTimestamp() {
        let before = Date()
        let entry = ReadingProgressEntry(bookISBN: "111", page: 10)
        testContext.insert(entry)
        let after = Date()
        XCTAssertGreaterThanOrEqual(entry.timestamp, before)
        XCTAssertLessThanOrEqual(entry.timestamp, after)
    }
}

// MARK: - Reading Progress ViewModel Tests

final class ReadingProgressViewModelTests: BookShelfTestCase {
    @MainActor
    func testProgressClearsOnWantToRead() throws {
        let vm = BookshelfViewModel()
        let book = makeBook(isbn: "111", pageCount: 200, readStatus: .currentlyReading, currentPage: 100, progressPercentage: 0.5)
        try testContext.save()
        vm.setModelContext(testContext)

        vm.setReadStatus(book, status: .wantToRead)

        XCTAssertNil(book.currentPage)
        XCTAssertNil(book.progressPercentage)
    }

    @MainActor
    func testProgressSetsTo100OnRead() throws {
        let vm = BookshelfViewModel()
        let book = makeBook(isbn: "111", pageCount: 200, readStatus: .currentlyReading, currentPage: 100)
        try testContext.save()
        vm.setModelContext(testContext)

        vm.setReadStatus(book, status: .read)

        XCTAssertEqual(book.currentPage, 200)
        XCTAssertEqual(book.progressPercentage, 1.0)
    }

    @MainActor
    func testUpdateProgressClampsPage() throws {
        let vm = BookshelfViewModel()
        let book = makeBook(isbn: "111", pageCount: 200, readStatus: .currentlyReading)
        try testContext.save()
        vm.setModelContext(testContext)

        vm.updateProgress(book, page: 300, percentage: nil)

        XCTAssertEqual(book.currentPage, 200)
    }

    @MainActor
    func testUpdateProgressClampsNegativePage() throws {
        let vm = BookshelfViewModel()
        let book = makeBook(isbn: "111", pageCount: 200, readStatus: .currentlyReading)
        try testContext.save()
        vm.setModelContext(testContext)

        vm.updateProgress(book, page: -5, percentage: nil)

        XCTAssertEqual(book.currentPage, 0)
    }

    @MainActor
    func testUpdateProgressSetsPercentage() throws {
        let vm = BookshelfViewModel()
        let book = makeBook(isbn: "111", readStatus: .currentlyReading)
        try testContext.save()
        vm.setModelContext(testContext)

        vm.updateProgress(book, page: nil, percentage: 0.65)

        XCTAssertEqual(book.progressPercentage, 0.65)
        XCTAssertNil(book.currentPage)
    }
}

// MARK: - ReadingProgressEntry Creation Tests

final class ReadingProgressEntryCreationTests: BookShelfTestCase {
    @MainActor
    func testEntryCreatedOnUpdate() throws {
        let vm = BookshelfViewModel()
        let book = makeBook(isbn: "222", pageCount: 300, readStatus: .currentlyReading)
        try testContext.save()
        vm.setModelContext(testContext)

        vm.updateProgress(book, page: 50, percentage: nil)

        let sessions = vm.fetchReadingSessions(for: "222")
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.page, 50)
        XCTAssertEqual(sessions.first?.bookISBN, "222")
    }

    @MainActor
    func testMultipleEntries() throws {
        let vm = BookshelfViewModel()
        let book = makeBook(isbn: "333", pageCount: 300, readStatus: .currentlyReading)
        try testContext.save()
        vm.setModelContext(testContext)

        vm.updateProgress(book, page: 30, percentage: nil)
        vm.updateProgress(book, page: 60, percentage: nil)
        vm.updateProgress(book, page: 90, percentage: nil)

        let sessions = vm.fetchReadingSessions(for: "333")
        XCTAssertEqual(sessions.count, 3)
    }

    @MainActor
    func testEntriesClearedOnWantToRead() throws {
        let vm = BookshelfViewModel()
        let book = makeBook(isbn: "444", pageCount: 300, readStatus: .currentlyReading)
        try testContext.save()
        vm.setModelContext(testContext)

        vm.updateProgress(book, page: 50, percentage: nil)
        vm.updateProgress(book, page: 100, percentage: nil)

        vm.setReadStatus(book, status: .wantToRead)

        let sessions = vm.fetchReadingSessions(for: "444")
        XCTAssertTrue(sessions.isEmpty)
    }
}

// MARK: - Reading Pace Tests

final class ReadingPaceTests: BookShelfTestCase {
    @MainActor
    func testPaceNilWithFewSessions() throws {
        let vm = BookshelfViewModel()
        let book = makeBook(isbn: "555", pageCount: 300, readStatus: .currentlyReading)
        try testContext.save()
        vm.setModelContext(testContext)

        XCTAssertNil(vm.readingPace(for: "555"))

        vm.updateProgress(book, page: 50, percentage: nil)

        XCTAssertNil(vm.readingPace(for: "555"))
    }

    @MainActor
    func testPaceCalculation() throws {
        let vm = BookshelfViewModel()
        let _ = makeBook(isbn: "666", pageCount: 300, readStatus: .currentlyReading)
        try testContext.save()
        vm.setModelContext(testContext)

        let calendar = Calendar.current
        let now = Date()
        let entry1 = ReadingProgressEntry(
            bookISBN: "666",
            page: 20,
            timestamp: calendar.date(byAdding: .day, value: -10, to: now)!
        )
        let entry2 = ReadingProgressEntry(
            bookISBN: "666",
            page: 120,
            timestamp: now
        )
        testContext.insert(entry1)
        testContext.insert(entry2)
        try testContext.save()

        let pace = vm.readingPace(for: "666")
        XCTAssertNotNil(pace)
        // 100 pages over 10 days = 10 pages/day
        XCTAssertEqual(pace, 10.0)
    }

    @MainActor
    func testSessionsNewestFirst() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        let calendar = Calendar.current
        let now = Date()
        let entry1 = ReadingProgressEntry(
            bookISBN: "777",
            page: 10,
            timestamp: calendar.date(byAdding: .day, value: -5, to: now)!
        )
        let entry2 = ReadingProgressEntry(
            bookISBN: "777",
            page: 50,
            timestamp: now
        )
        testContext.insert(entry1)
        testContext.insert(entry2)
        try testContext.save()

        let sessions = vm.fetchReadingSessions(for: "777")
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions.first?.page, 50)
        XCTAssertEqual(sessions.last?.page, 10)
    }
}

// MARK: - Book Rating Tests

final class BookRatingTests: BookShelfTestCase {
    @MainActor
    func testDefaultRating() {
        let book = makeBook()
        XCTAssertNil(book.rating)
    }

    @MainActor
    func testInitWithRating() {
        let book = makeBook(rating: 4)
        XCTAssertEqual(book.rating, 4)
    }

    @MainActor
    func testValidRange() {
        let book = makeBook()
        for value in 1...5 {
            book.rating = value
            XCTAssertEqual(book.rating, value)
        }
    }

    @MainActor
    func testNilRating() {
        let book = makeBook(rating: 3)
        book.rating = nil
        XCTAssertNil(book.rating)
    }

    @MainActor
    func testRatingDisplayWithRating() {
        let book = makeBook(rating: 3)
        XCTAssertEqual(book.ratingDisplay, "★★★☆☆")
    }

    @MainActor
    func testRatingDisplayWithoutRating() {
        let book = makeBook()
        XCTAssertTrue(book.ratingDisplay.isEmpty)
    }

    @MainActor
    func testRatingDisplayFiveStars() {
        let book = makeBook(rating: 5)
        XCTAssertEqual(book.ratingDisplay, "★★★★★")
    }

    @MainActor
    func testRatingDisplayOneStar() {
        let book = makeBook(rating: 1)
        XCTAssertEqual(book.ratingDisplay, "★☆☆☆☆")
    }
}

// MARK: - Preview Sample Data Tests

final class PreviewSampleDataTests: BookShelfTestCase {
    @MainActor
    func testSampleBooksCount() {
        let books = makeSampleBooks()
        XCTAssertEqual(books.count, 5)
    }

    @MainActor
    func testSampleWantToReadStatus() {
        let book = makeBook(
            isbn: "9780547928227",
            title: "The Hobbit",
            authors: ["J.R.R. Tolkien"],
            readStatus: .wantToRead
        )
        XCTAssertEqual(book.readStatus, .wantToRead)
        XCTAssertEqual(book.title, "The Hobbit")
        XCTAssertEqual(book.authors, ["J.R.R. Tolkien"])
        XCTAssertNil(book.rating)
        XCTAssertNil(book.dateStarted)
        XCTAssertNil(book.dateFinished)
    }

    @MainActor
    func testSampleCurrentlyReadingStatus() {
        let book = makeBook(
            isbn: "9780451524935",
            title: "1984",
            authors: ["George Orwell"],
            readStatus: .currentlyReading,
            dateStarted: Calendar.current.date(byAdding: .day, value: -14, to: Date())
        )
        XCTAssertEqual(book.readStatus, .currentlyReading)
        XCTAssertEqual(book.title, "1984")
        XCTAssertNotNil(book.dateStarted)
        XCTAssertNil(book.dateFinished)
    }

    @MainActor
    func testSampleReadWithRatingStatus() {
        let started = Calendar.current.date(byAdding: .day, value: -45, to: Date())
        let finished = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        let book = makeBook(
            isbn: "9780061120084",
            title: "To Kill a Mockingbird",
            authors: ["Harper Lee"],
            readStatus: .read,
            rating: 5,
            dateStarted: started,
            dateFinished: finished
        )
        XCTAssertEqual(book.readStatus, .read)
        XCTAssertEqual(book.title, "To Kill a Mockingbird")
        XCTAssertEqual(book.rating, 5)
        XCTAssertNotNil(book.dateStarted)
        XCTAssertNotNil(book.dateFinished)
        XCTAssertNotNil(book.daysToRead)
    }

    @MainActor
    func testSampleReadNoRatingStatus() {
        let book = makeBook(
            isbn: "9780743273565",
            title: "The Great Gatsby",
            authors: ["F. Scott Fitzgerald"],
            readStatus: .read,
            dateStarted: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
            dateFinished: Calendar.current.date(byAdding: .day, value: -10, to: Date())
        )
        XCTAssertEqual(book.readStatus, .read)
        XCTAssertEqual(book.title, "The Great Gatsby")
        XCTAssertNil(book.rating)
        XCTAssertNotNil(book.dateStarted)
        XCTAssertNotNil(book.dateFinished)
    }

    @MainActor
    func testSampleLongTitleStatus() {
        let book = makeBook(
            isbn: "9780062316097",
            title: "Sapiens: A Brief History of Humankind",
            authors: ["Yuval Noah Harari"],
            readStatus: .wantToRead
        )
        XCTAssertEqual(book.readStatus, .wantToRead)
        XCTAssertEqual(book.title, "Sapiens: A Brief History of Humankind")
    }

    @MainActor
    func testSampleBooksHaveRequiredFields() {
        let books = makeSampleBooks()
        for book in books {
            XCTAssertFalse(book.isbn.isEmpty)
            XCTAssertFalse(book.title.isEmpty)
            XCTAssertFalse(book.authors.isEmpty)
        }
    }

    @MainActor
    func testSampleBooksCoversAllStatuses() {
        let books = makeSampleBooks()
        let statuses = Set(books.map { $0.readStatus })
        XCTAssertTrue(statuses.contains(.wantToRead))
        XCTAssertTrue(statuses.contains(.currentlyReading))
        XCTAssertTrue(statuses.contains(.read))
    }

    func testSampleResultsCount() {
        XCTAssertEqual(BookSearchResult.sampleResults.count, 2)
    }

    func testSampleResultsFields() {
        for result in BookSearchResult.sampleResults {
            XCTAssertFalse(result.isbn.isEmpty)
            XCTAssertFalse(result.title.isEmpty)
            XCTAssertFalse(result.authors.isEmpty)
        }
    }

    @MainActor
    private func makeSampleBooks() -> [Book] {
        let calendar = Calendar.current
        let now = Date()
        return [
            makeBook(isbn: "9780547928227", title: "The Hobbit", authors: ["J.R.R. Tolkien"], readStatus: .wantToRead),
            makeBook(isbn: "9780451524935", title: "1984", authors: ["George Orwell"], pageCount: 328, readStatus: .currentlyReading, dateStarted: calendar.date(byAdding: .day, value: -14, to: now), currentPage: 124),
            makeBook(isbn: "9780061120084", title: "To Kill a Mockingbird", authors: ["Harper Lee"], readStatus: .read, rating: 5, dateStarted: calendar.date(byAdding: .day, value: -45, to: now), dateFinished: calendar.date(byAdding: .day, value: -5, to: now)),
            makeBook(isbn: "9780743273565", title: "The Great Gatsby", authors: ["F. Scott Fitzgerald"], readStatus: .read, dateStarted: calendar.date(byAdding: .day, value: -30, to: now), dateFinished: calendar.date(byAdding: .day, value: -10, to: now)),
            makeBook(isbn: "9780062316097", title: "Sapiens: A Brief History of Humankind", authors: ["Yuval Noah Harari"], readStatus: .wantToRead),
        ]
    }
}

// MARK: - BookshelfViewModel Tests

final class BookshelfViewModelTests: BookShelfTestCase {
    @MainActor
    func testDefaultIsInitialized() {
        let vm = BookshelfViewModel()
        XCTAssertFalse(vm.isInitialized)
    }

    @MainActor
    func testIsInitializedAfterSetModelContext() {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        XCTAssertTrue(vm.isInitialized)
    }

    @MainActor
    func testBooksEmptyBeforeInit() {
        let vm = BookshelfViewModel()
        XCTAssertTrue(vm.books.isEmpty)
    }

    @MainActor
    func testFetchBooksLoadsData() throws {
        let vm = BookshelfViewModel()
        let _ = makeBook(isbn: "111", title: "Book A")
        try testContext.save()
        vm.setModelContext(testContext)
        XCTAssertEqual(vm.books.count, 1)
        XCTAssertEqual(vm.books.first?.title, "Book A")
    }
}

// MARK: - Onboarding Tests

final class OnboardingTests: XCTestCase {
    func testDefaultValue() {
        let defaults = UserDefaults(suiteName: "OnboardingTest-default")!
        defaults.removePersistentDomain(forName: "OnboardingTest-default")
        let value = defaults.bool(forKey: "hasCompletedOnboarding")
        XCTAssertFalse(value)
    }

    func testPersistsTrue() {
        let defaults = UserDefaults(suiteName: "OnboardingTest-persist")!
        defaults.removePersistentDomain(forName: "OnboardingTest-persist")
        defaults.set(true, forKey: "hasCompletedOnboarding")
        let value = defaults.bool(forKey: "hasCompletedOnboarding")
        XCTAssertTrue(value)
    }

    func testCanReset() {
        let defaults = UserDefaults(suiteName: "OnboardingTest-reset")!
        defaults.removePersistentDomain(forName: "OnboardingTest-reset")
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set(false, forKey: "hasCompletedOnboarding")
        let value = defaults.bool(forKey: "hasCompletedOnboarding")
        XCTAssertFalse(value)
    }
}

// MARK: - BookSearchResult Tests

final class BookSearchResultTests: BookShelfTestCase {
    @MainActor
    func testToBookMapping() {
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
        testContext.insert(book)

        XCTAssertEqual(book.isbn, "1234567890")
        XCTAssertEqual(book.title, "Test Book")
        XCTAssertEqual(book.authors, ["Author A"])
        XCTAssertEqual(book.publisher, "Publisher")
        XCTAssertEqual(book.publishDate, "2024")
        XCTAssertEqual(book.pageCount, 300)
        XCTAssertEqual(book.bookDescription, "A test book")
        XCTAssertEqual(book.coverImageData, coverData)
    }

    @MainActor
    func testToBookNoCoverData() {
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
        testContext.insert(book)
        XCTAssertNil(book.coverImageData)
    }
}

// MARK: - Reading Streak Tests

final class ReadingStreakTests: BookShelfTestCase {
    private func makeEntry(daysAgo: Int, isbn: String = "111") {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
        let entry = ReadingProgressEntry(bookISBN: isbn, page: 10 + daysAgo, timestamp: date)
        testContext.insert(entry)
    }

    @MainActor
    func testNoEntriesZeroStreak() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        XCTAssertEqual(vm.currentStreak(), 0)
    }

    @MainActor
    func testSingleEntryTodayStreakOne() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        makeEntry(daysAgo: 0)
        try testContext.save()
        XCTAssertEqual(vm.currentStreak(), 1)
    }

    @MainActor
    func testFiveConsecutiveDays() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        for day in 0..<5 {
            makeEntry(daysAgo: day)
        }
        try testContext.save()
        XCTAssertEqual(vm.currentStreak(), 5)
    }

    @MainActor
    func testGapTwoDaysAgoStreakTwo() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        // Today, yesterday, then gap, then 3 days ago
        makeEntry(daysAgo: 0)
        makeEntry(daysAgo: 1)
        makeEntry(daysAgo: 3)
        try testContext.save()
        XCTAssertEqual(vm.currentStreak(), 2)
    }

    @MainActor
    func testNoEntryTodayButYesterdayStartsFromYesterday() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        makeEntry(daysAgo: 1)
        makeEntry(daysAgo: 2)
        makeEntry(daysAgo: 3)
        try testContext.save()
        XCTAssertEqual(vm.currentStreak(), 3)
    }

    @MainActor
    func testLongestStreakWithHistoricalData() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        // Current streak: 2 days (today + yesterday)
        makeEntry(daysAgo: 0)
        makeEntry(daysAgo: 1)
        // Gap at day 2
        // Historical streak: 5 days (days 3-7)
        for day in 3...7 {
            makeEntry(daysAgo: day)
        }
        try testContext.save()
        XCTAssertEqual(vm.currentStreak(), 2)
        XCTAssertEqual(vm.longestStreak(), 5)
    }

    @MainActor
    func testMultipleEntriesSameDayCountsAsOne() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        // Multiple entries today
        let now = Date()
        let entry1 = ReadingProgressEntry(bookISBN: "111", page: 10, timestamp: now)
        let entry2 = ReadingProgressEntry(bookISBN: "111", page: 20, timestamp: now.addingTimeInterval(-3600))
        testContext.insert(entry1)
        testContext.insert(entry2)
        try testContext.save()
        XCTAssertEqual(vm.currentStreak(), 1)
    }

    @MainActor
    func testEntriesAcrossMultipleBooksAllCount() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        makeEntry(daysAgo: 0, isbn: "aaa")
        makeEntry(daysAgo: 1, isbn: "bbb")
        makeEntry(daysAgo: 2, isbn: "aaa")
        try testContext.save()
        XCTAssertEqual(vm.currentStreak(), 3)
    }

    @MainActor
    func testHasReadToday() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        XCTAssertFalse(vm.hasReadToday())
        makeEntry(daysAgo: 0)
        try testContext.save()
        XCTAssertTrue(vm.hasReadToday())
    }
}

// MARK: - Lifetime Stats Tests

final class LifetimeStatsTests: BookShelfTestCase {
    @MainActor
    func testTotalBooksReadCountsOnlyReadStatus() throws {
        let vm = BookshelfViewModel()
        let _ = makeBook(isbn: "a", readStatus: .read)
        let _ = makeBook(isbn: "b", readStatus: .read)
        let _ = makeBook(isbn: "c", readStatus: .currentlyReading)
        let _ = makeBook(isbn: "d", readStatus: .wantToRead)
        try testContext.save()
        vm.setModelContext(testContext)
        XCTAssertEqual(vm.totalBooksRead, 2)
    }

    @MainActor
    func testTotalPagesReadSumsPageCount() throws {
        let vm = BookshelfViewModel()
        let _ = makeBook(isbn: "a", pageCount: 200, readStatus: .read)
        let _ = makeBook(isbn: "b", pageCount: 300, readStatus: .read)
        let _ = makeBook(isbn: "c", pageCount: 100, readStatus: .currentlyReading)
        try testContext.save()
        vm.setModelContext(testContext)
        XCTAssertEqual(vm.totalPagesRead, 500)
    }

    @MainActor
    func testTotalPagesReadSkipsNilPageCount() throws {
        let vm = BookshelfViewModel()
        let _ = makeBook(isbn: "a", pageCount: 200, readStatus: .read)
        let _ = makeBook(isbn: "b", readStatus: .read) // nil pageCount
        try testContext.save()
        vm.setModelContext(testContext)
        XCTAssertEqual(vm.totalPagesRead, 200)
    }

    @MainActor
    func testAverageRatingCorrect() throws {
        let vm = BookshelfViewModel()
        let _ = makeBook(isbn: "a", readStatus: .read, rating: 4)
        let _ = makeBook(isbn: "b", readStatus: .read, rating: 2)
        try testContext.save()
        vm.setModelContext(testContext)
        XCTAssertEqual(vm.averageRating, 3.0)
    }

    @MainActor
    func testAverageRatingNilWhenNoRatings() throws {
        let vm = BookshelfViewModel()
        let _ = makeBook(isbn: "a", readStatus: .read)
        try testContext.save()
        vm.setModelContext(testContext)
        XCTAssertNil(vm.averageRating)
    }

    @MainActor
    func testAverageDaysPerBookCorrect() throws {
        let vm = BookshelfViewModel()
        let calendar = Calendar.current
        let now = Date()
        let _ = makeBook(
            isbn: "a",
            readStatus: .read,
            dateStarted: calendar.date(byAdding: .day, value: -10, to: now),
            dateFinished: now
        )
        let _ = makeBook(
            isbn: "b",
            readStatus: .read,
            dateStarted: calendar.date(byAdding: .day, value: -20, to: now),
            dateFinished: now
        )
        try testContext.save()
        vm.setModelContext(testContext)
        XCTAssertEqual(vm.averageDaysPerBook, 15.0)
    }

    @MainActor
    func testAverageDaysPerBookNilWithNoDates() throws {
        let vm = BookshelfViewModel()
        let _ = makeBook(isbn: "a", readStatus: .read)
        try testContext.save()
        vm.setModelContext(testContext)
        XCTAssertNil(vm.averageDaysPerBook)
    }
}

// MARK: - Time Period Stats Tests

final class TimePeriodStatsTests: BookShelfTestCase {
    @MainActor
    func testBooksFinishedInWeekBoundary() throws {
        let vm = BookshelfViewModel()
        let now = Date()
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)!.start

        let _ = makeBook(isbn: "a", readStatus: .read, dateFinished: startOfWeek.addingTimeInterval(3600))
        let _ = makeBook(isbn: "b", readStatus: .read, dateFinished: calendar.date(byAdding: .day, value: -8, to: now))
        try testContext.save()
        vm.setModelContext(testContext)

        let thisWeek = vm.booksFinished(in: vm.thisWeekInterval)
        XCTAssertEqual(thisWeek.count, 1)
        XCTAssertEqual(thisWeek.first?.isbn, "a")
    }

    @MainActor
    func testPagesReadInPeriodComputesDiffs() throws {
        let vm = BookshelfViewModel()
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        // Entry before today (baseline)
        let baseline = ReadingProgressEntry(bookISBN: "111", page: 50, timestamp: calendar.date(byAdding: .day, value: -1, to: now)!)
        // Entry today
        let todayEntry = ReadingProgressEntry(bookISBN: "111", page: 80, timestamp: startOfDay.addingTimeInterval(3600))
        testContext.insert(baseline)
        testContext.insert(todayEntry)
        try testContext.save()
        vm.setModelContext(testContext)

        let todayPeriod = DateInterval(start: startOfDay, end: now)
        let pages = vm.pagesReadInPeriod(todayPeriod)
        XCTAssertEqual(pages, 30)
    }

    @MainActor
    func testEntriesOutsideRangeExcluded() throws {
        let vm = BookshelfViewModel()
        let calendar = Calendar.current
        let now = Date()

        // All entries in the past (before this week)
        let oldEntry = ReadingProgressEntry(bookISBN: "111", page: 100, timestamp: calendar.date(byAdding: .day, value: -14, to: now)!)
        testContext.insert(oldEntry)
        try testContext.save()
        vm.setModelContext(testContext)

        let pages = vm.pagesReadInPeriod(vm.thisWeekInterval)
        XCTAssertEqual(pages, 0)
    }

    @MainActor
    func testBooksFinishedExcludesOtherStatuses() throws {
        let vm = BookshelfViewModel()
        let now = Date()
        let _ = makeBook(isbn: "a", readStatus: .read, dateFinished: now)
        let _ = makeBook(isbn: "b", readStatus: .currentlyReading)
        try testContext.save()
        vm.setModelContext(testContext)

        let thisYear = vm.booksFinished(in: vm.thisYearInterval)
        XCTAssertEqual(thisYear.count, 1)
    }
}

// MARK: - Reading Goal Tests

final class ReadingGoalTests: BookShelfTestCase {
    @MainActor
    func testSaveAndFetchGoal() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        vm.saveReadingGoal(daily: 30, weekly: 200)
        let goal = vm.fetchReadingGoal()

        XCTAssertNotNil(goal)
        XCTAssertEqual(goal?.dailyPageGoal, 30)
        XCTAssertEqual(goal?.weeklyPageGoal, 200)
    }

    @MainActor
    func testUpdateExistingGoal() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        vm.saveReadingGoal(daily: 30, weekly: 200)
        vm.saveReadingGoal(daily: 50, weekly: 300)

        let goal = vm.fetchReadingGoal()
        XCTAssertEqual(goal?.dailyPageGoal, 50)
        XCTAssertEqual(goal?.weeklyPageGoal, 300)
    }

    @MainActor
    func testReturnsNilWhenNoGoalExists() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        XCTAssertNil(vm.fetchReadingGoal())
    }

    @MainActor
    func testDailyGoalProgressNilWhenNoGoal() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        XCTAssertNil(vm.dailyGoalProgress())
    }

    @MainActor
    func testWeeklyGoalProgressNilWhenNoGoal() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        XCTAssertNil(vm.weeklyGoalProgress())
    }
}

// MARK: - Reading Challenge Tests

final class ReadingChallengeTests: BookShelfTestCase {
    @MainActor
    func testSaveAndFetchChallenge() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        let year = Calendar.current.component(.year, from: Date())
        vm.saveChallenge(year: year, goalCount: 24)

        let challenge = vm.fetchChallenge(for: year)
        XCTAssertNotNil(challenge)
        XCTAssertEqual(challenge?.year, year)
        XCTAssertEqual(challenge?.goalCount, 24)
    }

    @MainActor
    func testUpdateExistingChallengeGoal() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        let year = Calendar.current.component(.year, from: Date())
        vm.saveChallenge(year: year, goalCount: 12)
        vm.saveChallenge(year: year, goalCount: 30)

        let challenge = vm.fetchChallenge(for: year)
        XCTAssertEqual(challenge?.goalCount, 30)
    }

    @MainActor
    func testReturnsNilWhenNoChallengeForYear() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        XCTAssertNil(vm.fetchChallenge(for: 1999))
    }

    @MainActor
    func testDeleteChallenge() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        let year = Calendar.current.component(.year, from: Date())
        vm.saveChallenge(year: year, goalCount: 20)
        XCTAssertNotNil(vm.fetchChallenge(for: year))

        vm.deleteChallenge(for: year)
        XCTAssertNil(vm.fetchChallenge(for: year))
    }

    @MainActor
    func testBooksReadInYearCountsOnlyFinishedInYear() throws {
        let vm = BookshelfViewModel()
        let now = Date()
        let year = Calendar.current.component(.year, from: now)

        let _ = makeBook(isbn: "a", readStatus: .read, dateFinished: now)
        let _ = makeBook(isbn: "b", readStatus: .read, dateFinished: now)
        let _ = makeBook(isbn: "c", readStatus: .currentlyReading)
        let _ = makeBook(isbn: "d", readStatus: .wantToRead)
        try testContext.save()
        vm.setModelContext(testContext)

        let result = vm.booksReadInYear(year)
        XCTAssertEqual(result.count, 2)
    }

    @MainActor
    func testBooksReadInYearExcludesOtherYears() throws {
        let vm = BookshelfViewModel()
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)

        let _ = makeBook(isbn: "a", readStatus: .read, dateFinished: now)
        let lastYear = calendar.date(from: DateComponents(year: year - 1, month: 6, day: 15))!
        let _ = makeBook(isbn: "b", readStatus: .read, dateFinished: lastYear)
        try testContext.save()
        vm.setModelContext(testContext)

        XCTAssertEqual(vm.booksReadInYear(year).count, 1)
        XCTAssertEqual(vm.booksReadInYear(year - 1).count, 1)
    }

    @MainActor
    func testChallengeProgressReturnsCorrectCounts() throws {
        let vm = BookshelfViewModel()
        let now = Date()
        let year = Calendar.current.component(.year, from: now)

        vm.setModelContext(testContext)
        vm.saveChallenge(year: year, goalCount: 24)

        let _ = makeBook(isbn: "a", readStatus: .read, dateFinished: now)
        let _ = makeBook(isbn: "b", readStatus: .read, dateFinished: now)
        try testContext.save()
        vm.fetchBooks()

        let progress = vm.challengeProgress()
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress?.booksRead, 2)
        XCTAssertEqual(progress?.goal, 24)
    }

    @MainActor
    func testChallengeProgressNilWhenNoChallenge() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        XCTAssertNil(vm.challengeProgress())
    }
}

// MARK: - ReadStatus Extended Tests

final class ReadStatusExtendedTests: XCTestCase {
    func testNewCasesRawValues() {
        XCTAssertEqual(ReadStatus.paused.rawValue, "paused")
        XCTAssertEqual(ReadStatus.didNotFinish.rawValue, "did_not_finish")
    }

    func testNewCasesRoundTrip() {
        XCTAssertEqual(ReadStatus(rawValue: "paused"), .paused)
        XCTAssertEqual(ReadStatus(rawValue: "did_not_finish"), .didNotFinish)
    }

    func testDisplayNames() {
        XCTAssertEqual(ReadStatus.paused.displayName, "Paused")
        XCTAssertEqual(ReadStatus.didNotFinish.displayName, "Did Not Finish")
    }

    func testIcons() {
        XCTAssertEqual(ReadStatus.paused.icon, "pause.circle.fill")
        XCTAssertEqual(ReadStatus.didNotFinish.icon, "xmark.circle.fill")
    }

    func testCountsForChallenge() {
        XCTAssertTrue(ReadStatus.read.countsForChallenge)
        XCTAssertFalse(ReadStatus.wantToRead.countsForChallenge)
        XCTAssertFalse(ReadStatus.currentlyReading.countsForChallenge)
        XCTAssertFalse(ReadStatus.paused.countsForChallenge)
        XCTAssertFalse(ReadStatus.didNotFinish.countsForChallenge)
    }

    func testUnknownRawValueFallsBack() {
        XCTAssertNil(ReadStatus(rawValue: "unknown_status"))
    }

    func testAllCasesIncludesNewStatuses() {
        let allCases = ReadStatus.allCases
        XCTAssertTrue(allCases.contains(.paused))
        XCTAssertTrue(allCases.contains(.didNotFinish))
        XCTAssertEqual(allCases.count, 5)
    }
}

// MARK: - Status Transition Tests

final class StatusTransitionTests: BookShelfTestCase {
    @MainActor
    func testPausedKeepsProgress() throws {
        let vm = BookshelfViewModel()
        let book = makeBook(isbn: "p1", pageCount: 300, readStatus: .currentlyReading,
                           dateStarted: Date(), currentPage: 150, progressPercentage: 0.5)
        try testContext.save()
        vm.setModelContext(testContext)

        vm.setReadStatus(book, status: .paused)

        XCTAssertEqual(book.readStatus, .paused)
        XCTAssertEqual(book.currentPage, 150)
        XCTAssertNotNil(book.dateStarted)
        XCTAssertNil(book.dateFinished)
    }

    @MainActor
    func testDNFSetsDateFinished() throws {
        let vm = BookshelfViewModel()
        let book = makeBook(isbn: "d1", pageCount: 300, readStatus: .currentlyReading,
                           dateStarted: Date(), currentPage: 100)
        try testContext.save()
        vm.setModelContext(testContext)

        vm.setReadStatus(book, status: .didNotFinish, dnfReason: "Too boring")

        XCTAssertEqual(book.readStatus, .didNotFinish)
        XCTAssertNotNil(book.dateFinished)
        XCTAssertEqual(book.dnfReason, "Too boring")
        XCTAssertEqual(book.currentPage, 100)
    }

    @MainActor
    func testWantToReadClearsDNFReason() throws {
        let vm = BookshelfViewModel()
        let book = makeBook(isbn: "w1", pageCount: 300, readStatus: .didNotFinish,
                           dateStarted: Date(), dateFinished: Date(), currentPage: 50)
        book.dnfReason = "Lost interest"
        try testContext.save()
        vm.setModelContext(testContext)

        vm.setReadStatus(book, status: .wantToRead)

        XCTAssertEqual(book.readStatus, .wantToRead)
        XCTAssertNil(book.dnfReason)
        XCTAssertNil(book.currentPage)
        XCTAssertNil(book.dateStarted)
    }

    @MainActor
    func testTogglePausedResumesReading() throws {
        let vm = BookshelfViewModel()
        let book = makeBook(isbn: "t1", readStatus: .paused)
        try testContext.save()
        vm.setModelContext(testContext)

        vm.toggleReadStatus(book)

        XCTAssertEqual(book.readStatus, .currentlyReading)
    }

    @MainActor
    func testToggleDNFGoesToWantToRead() throws {
        let vm = BookshelfViewModel()
        let book = makeBook(isbn: "t2", readStatus: .didNotFinish)
        try testContext.save()
        vm.setModelContext(testContext)

        vm.toggleReadStatus(book)

        XCTAssertEqual(book.readStatus, .wantToRead)
    }
}

// MARK: - ReadingSession Tests

final class ReadingSessionModelTests: BookShelfTestCase {
    @MainActor
    func testPagesPerHour() {
        let session = ReadingSession(
            bookISBN: "111",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            duration: 3600,
            pagesRead: 30
        )
        testContext.insert(session)
        XCTAssertEqual(session.pagesPerHour, 30.0)
    }

    @MainActor
    func testPagesPerHourNilWhenNoPagesRead() {
        let session = ReadingSession(
            bookISBN: "111",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            duration: 3600
        )
        testContext.insert(session)
        XCTAssertNil(session.pagesPerHour)
    }

    @MainActor
    func testFormattedDurationHours() {
        let session = ReadingSession(
            bookISBN: "111",
            startTime: Date(),
            endTime: Date(),
            duration: 3661 // 1h 1m 1s
        )
        testContext.insert(session)
        XCTAssertEqual(session.formattedDuration, "1:01:01")
    }

    @MainActor
    func testFormattedDurationMinutes() {
        let session = ReadingSession(
            bookISBN: "111",
            startTime: Date(),
            endTime: Date(),
            duration: 125 // 2m 5s
        )
        testContext.insert(session)
        XCTAssertEqual(session.formattedDuration, "2:05")
    }

    @MainActor
    func testSessionCRUD() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        let session = ReadingSession(
            bookISBN: "test-isbn",
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800),
            duration: 1800,
            pagesRead: 15,
            startPage: 50,
            endPage: 65
        )
        testContext.insert(session)
        try testContext.save()

        let sessions = vm.fetchTimedSessions(for: "test-isbn")
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.pagesRead, 15)
        XCTAssertEqual(sessions.first?.startPage, 50)
        XCTAssertEqual(sessions.first?.endPage, 65)
    }
}

// MARK: - ReadingTimerViewModel Tests

final class ReadingTimerViewModelTests: BookShelfTestCase {
    @MainActor
    func testInitialState() {
        let timer = ReadingTimerViewModel()
        XCTAssertEqual(timer.state, .idle)
        XCTAssertNil(timer.currentBook)
        XCTAssertEqual(timer.displayTime, 0)
    }

    @MainActor
    func testStartSession() {
        let timer = ReadingTimerViewModel()
        let book = makeBook(isbn: "timer1", readStatus: .currentlyReading)

        timer.startSession(for: book)

        XCTAssertEqual(timer.state, .running)
        XCTAssertNotNil(timer.currentBook)
        XCTAssertEqual(timer.currentBook?.isbn, "timer1")
    }

    @MainActor
    func testPauseAndResume() {
        let timer = ReadingTimerViewModel()
        let book = makeBook(isbn: "timer2", readStatus: .currentlyReading)

        timer.startSession(for: book)
        XCTAssertEqual(timer.state, .running)

        timer.pause()
        XCTAssertEqual(timer.state, .paused)

        timer.resume()
        XCTAssertEqual(timer.state, .running)
    }

    @MainActor
    func testCancelSession() {
        let timer = ReadingTimerViewModel()
        let book = makeBook(isbn: "timer3", readStatus: .currentlyReading)

        timer.startSession(for: book)
        timer.cancelSession()

        XCTAssertEqual(timer.state, .idle)
        XCTAssertNil(timer.currentBook)
        XCTAssertEqual(timer.displayTime, 0)
    }

    @MainActor
    func testEndSessionCreatesReadingSession() throws {
        let timer = ReadingTimerViewModel()
        let book = makeBook(isbn: "timer4", pageCount: 300, readStatus: .currentlyReading, currentPage: 50)
        try testContext.save()

        timer.startSession(for: book)
        timer.endSession(endPage: 65, modelContext: testContext)

        let descriptor = FetchDescriptor<ReadingSession>(
            predicate: #Predicate { $0.bookISBN == "timer4" }
        )
        let sessions = try testContext.fetch(descriptor)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.endPage, 65)

        // Book progress should be updated
        XCTAssertEqual(book.currentPage, 65)
    }

    @MainActor
    func testFormattedTime() {
        let timer = ReadingTimerViewModel()
        XCTAssertEqual(timer.formattedTime, "00:00:00")
    }
}

// MARK: - BookNote Tests

final class BookNoteTests: BookShelfTestCase {
    @MainActor
    func testSaveAndFetchNote() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        vm.saveNote(bookISBN: "note1", text: "Great passage", noteType: .quote, pageNumber: 42)

        let notes = vm.fetchNotes(for: "note1")
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.text, "Great passage")
        XCTAssertEqual(notes.first?.noteType, .quote)
        XCTAssertEqual(notes.first?.pageNumber, 42)
    }

    @MainActor
    func testFetchAllQuotes() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        vm.saveNote(bookISBN: "q1", text: "Quote 1", noteType: .quote)
        vm.saveNote(bookISBN: "q1", text: "Note 1", noteType: .note)
        vm.saveNote(bookISBN: "q2", text: "Quote 2", noteType: .quote)

        let quotes = vm.fetchAllQuotes()
        XCTAssertEqual(quotes.count, 2)
    }

    @MainActor
    func testRandomQuoteReturnsQuote() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        vm.saveNote(bookISBN: "rq1", text: "Random quote text", noteType: .quote)

        let quote = vm.randomQuote()
        XCTAssertNotNil(quote)
        XCTAssertEqual(quote?.noteType, .quote)
    }

    @MainActor
    func testRandomQuoteNilWhenNoQuotes() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        XCTAssertNil(vm.randomQuote())
    }

    @MainActor
    func testDeleteNote() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        vm.saveNote(bookISBN: "del1", text: "To delete", noteType: .note)
        var notes = vm.fetchNotes(for: "del1")
        XCTAssertEqual(notes.count, 1)

        vm.deleteNote(notes.first!)
        notes = vm.fetchNotes(for: "del1")
        XCTAssertTrue(notes.isEmpty)
    }

    @MainActor
    func testNoteTypeGetterSetter() {
        let note = BookNote(bookISBN: "nt1", text: "Test", noteType: .quote)
        testContext.insert(note)
        XCTAssertEqual(note.noteType, .quote)

        note.noteType = .note
        XCTAssertEqual(note.noteType, .note)
        XCTAssertEqual(note.noteTypeRaw, "note")
    }
}

// MARK: - Streak Freeze Tests

final class StreakFreezeTests: BookShelfTestCase {
    @MainActor
    func testUseStreakFreeze() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        XCTAssertTrue(vm.hasStreakFreezeAvailable())
        let result = vm.useStreakFreeze()
        XCTAssertTrue(result)
        XCTAssertFalse(vm.hasStreakFreezeAvailable())
    }

    @MainActor
    func testOnePerWeek() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        let first = vm.useStreakFreeze()
        XCTAssertTrue(first)

        let second = vm.useStreakFreeze()
        XCTAssertFalse(second)
    }

    @MainActor
    func testFreezePreservesStreak() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        let calendar = Calendar.current
        let now = Date()

        // Create entries for today and 2 days ago (gap yesterday)
        let todayEntry = ReadingProgressEntry(bookISBN: "sf1", page: 30, timestamp: now)
        let twoDaysAgoEntry = ReadingProgressEntry(
            bookISBN: "sf1",
            page: 20,
            timestamp: calendar.date(byAdding: .day, value: -2, to: now)!
        )
        testContext.insert(todayEntry)
        testContext.insert(twoDaysAgoEntry)

        // Use a freeze for yesterday
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let freeze = StreakFreeze(
            dateUsed: yesterday,
            weekOfYear: calendar.component(.weekOfYear, from: yesterday),
            year: calendar.component(.year, from: yesterday)
        )
        testContext.insert(freeze)
        try testContext.save()

        let streak = vm.currentStreak()
        XCTAssertEqual(streak, 3) // today + freeze yesterday + 2 days ago
    }

    @MainActor
    func testFetchFreezeDays() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        let calendar = Calendar.current
        let now = Date()
        let freeze = StreakFreeze(
            dateUsed: now,
            weekOfYear: calendar.component(.weekOfYear, from: now),
            year: calendar.component(.year, from: now)
        )
        testContext.insert(freeze)
        try testContext.save()

        let freezeDays = vm.fetchStreakFreezeDays()
        XCTAssertEqual(freezeDays.count, 1)
    }
}

// MARK: - Reading Insights Tests

final class ReadingInsightsTests: BookShelfTestCase {
    @MainActor
    func testEstimatedCompletionDate() throws {
        let vm = BookshelfViewModel()
        let book = makeBook(isbn: "ins1", pageCount: 300, readStatus: .currentlyReading, currentPage: 150)
        try testContext.save()
        vm.setModelContext(testContext)

        let calendar = Calendar.current
        let now = Date()
        let entry1 = ReadingProgressEntry(
            bookISBN: "ins1", page: 50,
            timestamp: calendar.date(byAdding: .day, value: -10, to: now)!
        )
        let entry2 = ReadingProgressEntry(
            bookISBN: "ins1", page: 150,
            timestamp: now
        )
        testContext.insert(entry1)
        testContext.insert(entry2)
        try testContext.save()

        let completion = vm.estimatedCompletionDate(for: book)
        XCTAssertNotNil(completion)
        // 100 pages in 10 days = 10 pages/day, 150 remaining = 15 days
        if let date = completion {
            let daysUntil = calendar.dateComponents([.day], from: now, to: date).day ?? 0
            XCTAssertEqual(daysUntil, 15)
        }
    }

    @MainActor
    func testEstimatedCompletionNilForFinishedBook() {
        let book = makeBook(isbn: "ins2", pageCount: 300, readStatus: .read, currentPage: 300)
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        XCTAssertNil(vm.estimatedCompletionDate(for: book))
    }

    @MainActor
    func testPagesPerHourFromTimedSessions() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        let session = ReadingSession(
            bookISBN: "pph1",
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800),
            duration: 1800, // 30 min
            pagesRead: 20
        )
        testContext.insert(session)
        try testContext.save()

        let pph = vm.pagesPerHour(for: "pph1")
        XCTAssertNotNil(pph)
        XCTAssertEqual(pph!, 40.0, accuracy: 0.1) // 20 pages / 0.5 hours
    }

    @MainActor
    func testWeeklySummary() throws {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)

        let summary = vm.weeklySummary()
        XCTAssertEqual(summary.pages, 0)
        XCTAssertEqual(summary.books, 0)
    }

    @MainActor
    func testPreferredReadingTimeNilWhenNoSessions() {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        XCTAssertNil(vm.preferredReadingTime())
    }

    @MainActor
    func testBestReadingWeekNilWhenFewEntries() {
        let vm = BookshelfViewModel()
        vm.setModelContext(testContext)
        XCTAssertNil(vm.bestReadingWeek())
    }
}
