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
    private(set) var isInitialized = false

    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchBooks()
        isInitialized = true
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

        deleteProgressEntries(for: book.isbn)
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

        // Clear progress when moving to wantToRead
        if status == .wantToRead {
            book.currentPage = nil
            book.progressPercentage = nil
            deleteProgressEntries(for: book.isbn)
        }

        // Set progress to 100% when marking as read
        if status == .read {
            if let pageCount = book.pageCount, pageCount > 0 {
                book.currentPage = pageCount
            }
            book.progressPercentage = 1.0
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

    func updateProgress(_ book: Book, page: Int?, percentage: Double?) {
        guard let modelContext else { return }

        var clampedPage: Int?
        if let page {
            clampedPage = max(0, book.pageCount.map { min(page, $0) } ?? page)
            book.currentPage = clampedPage
            if let pageCount = book.pageCount, pageCount > 0 {
                book.progressPercentage = Double(clampedPage!) / Double(pageCount)
            }
        } else if let percentage {
            book.progressPercentage = min(1.0, max(0.0, percentage))
            book.currentPage = nil
        }

        // Record a progress entry
        let entry = ReadingProgressEntry(
            bookISBN: book.isbn,
            page: clampedPage,
            percentage: percentage
        )
        modelContext.insert(entry)

        do {
            try modelContext.save()
            fetchBooks()
        } catch {
            showError(message: "Failed to update progress: \(error.localizedDescription)")
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

    func fetchReadingSessions(for isbn: String) -> [ReadingProgressEntry] {
        guard let modelContext else { return [] }

        let descriptor = FetchDescriptor<ReadingProgressEntry>(
            predicate: #Predicate { $0.bookISBN == isbn },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    func readingPace(for isbn: String) -> Double? {
        let sessions = fetchReadingSessions(for: isbn)
        guard sessions.count >= 2 else { return nil }

        // Sessions are newest-first; oldest is last
        guard let newest = sessions.first,
              let oldest = sessions.last,
              let newestPage = newest.page,
              let oldestPage = oldest.page else { return nil }

        let totalPages = newestPage - oldestPage
        guard totalPages > 0 else { return nil }

        let days = Calendar.current.dateComponents([.day], from: oldest.timestamp, to: newest.timestamp).day ?? 0
        guard days > 0 else { return Double(totalPages) }

        return Double(totalPages) / Double(days)
    }

    private func deleteProgressEntries(for isbn: String) {
        guard let modelContext else { return }

        let descriptor = FetchDescriptor<ReadingProgressEntry>(
            predicate: #Predicate { $0.bookISBN == isbn }
        )

        if let entries = try? modelContext.fetch(descriptor) {
            for entry in entries {
                modelContext.delete(entry)
            }
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

    // MARK: - Reading Streaks

    func fetchAllProgressEntries() -> [ReadingProgressEntry] {
        guard let modelContext else { return [] }

        let descriptor = FetchDescriptor<ReadingProgressEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    func readingDays() -> Set<DateComponents> {
        let entries = fetchAllProgressEntries()
        let calendar = Calendar.current
        var days = Set<DateComponents>()
        for entry in entries {
            let components = calendar.dateComponents([.year, .month, .day], from: entry.timestamp)
            days.insert(components)
        }
        return days
    }

    func currentStreak() -> Int {
        let days = readingDays()
        guard !days.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: Date())

        // Start from today; if no activity today, try yesterday
        var checkDate = today
        if !days.contains(checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.date(from: today)!) else { return 0 }
            checkDate = calendar.dateComponents([.year, .month, .day], from: yesterday)
            if !days.contains(checkDate) {
                return 0
            }
        }

        var streak = 0
        var current = checkDate
        while days.contains(current) {
            streak += 1
            guard let prevDate = calendar.date(byAdding: .day, value: -1, to: calendar.date(from: current)!) else { break }
            current = calendar.dateComponents([.year, .month, .day], from: prevDate)
        }
        return streak
    }

    func longestStreak() -> Int {
        let days = readingDays()
        guard !days.isEmpty else { return 0 }

        let calendar = Calendar.current
        let sortedDates = days.compactMap { calendar.date(from: $0) }.sorted()

        var longest = 1
        var current = 1

        for i in 1..<sortedDates.count {
            let daysBetween = calendar.dateComponents([.day], from: sortedDates[i - 1], to: sortedDates[i]).day ?? 0
            if daysBetween == 1 {
                current += 1
                longest = max(longest, current)
            } else if daysBetween > 1 {
                current = 1
            }
            // daysBetween == 0 means same day (shouldn't happen with Set), skip
        }

        return longest
    }

    func hasReadToday() -> Bool {
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: Date())
        return readingDays().contains(today)
    }

    // MARK: - Lifetime Stats

    var totalBooksRead: Int {
        books.filter { $0.readStatus == .read }.count
    }

    var totalPagesRead: Int {
        books.filter { $0.readStatus == .read }.compactMap(\.pageCount).reduce(0, +)
    }

    var averageRating: Double? {
        let ratings = books.compactMap(\.rating)
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }

    var averageDaysPerBook: Double? {
        let days = books.compactMap(\.daysToRead)
        guard !days.isEmpty else { return nil }
        return Double(days.reduce(0, +)) / Double(days.count)
    }

    var averagePagesPerDay: Double? {
        let dayCount = readingDays().count
        guard dayCount > 0 else { return nil }
        return Double(totalPagesRead) / Double(dayCount)
    }

    // MARK: - Time-Based Summaries

    var thisWeekInterval: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        return DateInterval(start: startOfWeek, end: now)
    }

    var thisMonthInterval: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)!.start
        return DateInterval(start: startOfMonth, end: now)
    }

    var thisYearInterval: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let startOfYear = calendar.dateInterval(of: .year, for: now)!.start
        return DateInterval(start: startOfYear, end: now)
    }

    func booksFinished(in period: DateInterval) -> [Book] {
        books.filter { book in
            guard let finished = book.dateFinished else { return false }
            return period.contains(finished)
        }
    }

    func pagesReadInPeriod(_ period: DateInterval) -> Int {
        let entries = fetchAllProgressEntries()
        // Group entries by bookISBN, filter to those within period
        let entriesInPeriod = entries.filter { period.contains($0.timestamp) }

        var total = 0
        // Group by book
        let grouped = Dictionary(grouping: entriesInPeriod) { $0.bookISBN }

        for (isbn, bookEntries) in grouped {
            let sorted = bookEntries.sorted { $0.timestamp < $1.timestamp }
            // Get the entry just before the period for this book as baseline
            let allBookEntries = entries.filter { $0.bookISBN == isbn }.sorted { $0.timestamp < $1.timestamp }
            let baseline = allBookEntries.last { $0.timestamp < period.start }?.page ?? 0

            if let lastInPeriod = sorted.last?.page {
                let firstInPeriod = sorted.first?.page ?? baseline
                let startPage = min(firstInPeriod, baseline == 0 ? firstInPeriod : baseline)
                let diff = lastInPeriod - startPage
                if diff > 0 {
                    total += diff
                }
            }
        }
        return total
    }

    // MARK: - Reading Goals

    func fetchReadingGoal() -> ReadingGoal? {
        guard let modelContext else { return nil }

        let descriptor = FetchDescriptor<ReadingGoal>()
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            return nil
        }
    }

    func saveReadingGoal(daily: Int?, weekly: Int?) {
        guard let modelContext else { return }

        if let existing = fetchReadingGoal() {
            existing.dailyPageGoal = daily
            existing.weeklyPageGoal = weekly
            existing.dateModified = Date()
        } else {
            let goal = ReadingGoal(dailyPageGoal: daily, weeklyPageGoal: weekly)
            modelContext.insert(goal)
        }

        do {
            try modelContext.save()
        } catch {
            showError(message: "Failed to save goal: \(error.localizedDescription)")
        }
    }

    func dailyGoalProgress() -> (pagesRead: Int, goal: Int)? {
        guard let goal = fetchReadingGoal(), let dailyGoal = goal.dailyPageGoal else { return nil }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let period = DateInterval(start: startOfDay, end: Date())
        let pagesRead = pagesReadInPeriod(period)

        return (pagesRead: pagesRead, goal: dailyGoal)
    }

    func weeklyGoalProgress() -> (pagesRead: Int, goal: Int)? {
        guard let goal = fetchReadingGoal(), let weeklyGoal = goal.weeklyPageGoal else { return nil }

        let pagesRead = pagesReadInPeriod(thisWeekInterval)
        return (pagesRead: pagesRead, goal: weeklyGoal)
    }

    // MARK: - Reading Challenge

    func fetchChallenge(for year: Int) -> ReadingChallenge? {
        guard let modelContext else { return nil }

        let descriptor = FetchDescriptor<ReadingChallenge>(
            predicate: #Predicate { $0.year == year }
        )
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            return nil
        }
    }

    func saveChallenge(year: Int, goalCount: Int) {
        guard let modelContext else { return }

        if let existing = fetchChallenge(for: year) {
            existing.goalCount = goalCount
            existing.dateModified = Date()
        } else {
            let challenge = ReadingChallenge(year: year, goalCount: goalCount)
            modelContext.insert(challenge)
        }

        do {
            try modelContext.save()
        } catch {
            showError(message: "Failed to save challenge: \(error.localizedDescription)")
        }
    }

    func deleteChallenge(for year: Int) {
        guard let modelContext else { return }

        if let challenge = fetchChallenge(for: year) {
            modelContext.delete(challenge)
            do {
                try modelContext.save()
            } catch {
                showError(message: "Failed to delete challenge: \(error.localizedDescription)")
            }
        }
    }

    func booksReadInYear(_ year: Int) -> [Book] {
        let calendar = Calendar.current
        return books.filter { book in
            guard book.readStatus == .read, let finished = book.dateFinished else { return false }
            return calendar.component(.year, from: finished) == year
        }
    }

    func challengeProgress() -> (booksRead: Int, goal: Int, aheadBy: Int)? {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        guard let challenge = fetchChallenge(for: currentYear) else { return nil }

        let booksRead = booksReadInYear(currentYear).count
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let daysInYear: Int = calendar.range(of: .day, in: .year, for: Date())?.count ?? 365
        let expectedBooks = Int(round(Double(challenge.goalCount) * Double(dayOfYear) / Double(daysInYear)))
        let aheadBy = booksRead - expectedBooks

        return (booksRead: booksRead, goal: challenge.goalCount, aheadBy: aheadBy)
    }
}
