import Foundation
import SwiftData

@Model
final class ReadingProgressEntry {
    var bookISBN: String
    var page: Int?
    var percentage: Double?
    var timestamp: Date

    init(
        bookISBN: String,
        page: Int? = nil,
        percentage: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.bookISBN = bookISBN
        self.page = page
        self.percentage = percentage
        self.timestamp = timestamp
    }

    func pagesRead(since previous: ReadingProgressEntry?) -> Int? {
        guard let currentPage = page else { return nil }
        guard let previousPage = previous?.page else { return currentPage > 0 ? currentPage : nil }
        let diff = currentPage - previousPage
        return diff > 0 ? diff : nil
    }
}

// MARK: - Preview Sample Data

#if DEBUG
extension ReadingProgressEntry {
    static var sampleEntries: [ReadingProgressEntry] {
        let now = Date()
        let calendar = Calendar.current
        return [
            ReadingProgressEntry(
                bookISBN: "9780451524935",
                page: 124,
                percentage: nil,
                timestamp: now
            ),
            ReadingProgressEntry(
                bookISBN: "9780451524935",
                page: 100,
                percentage: nil,
                timestamp: calendar.date(byAdding: .day, value: -1, to: now)!
            ),
            ReadingProgressEntry(
                bookISBN: "9780451524935",
                page: 78,
                percentage: nil,
                timestamp: calendar.date(byAdding: .day, value: -3, to: now)!
            ),
            ReadingProgressEntry(
                bookISBN: "9780451524935",
                page: 45,
                percentage: nil,
                timestamp: calendar.date(byAdding: .day, value: -5, to: now)!
            ),
            ReadingProgressEntry(
                bookISBN: "9780451524935",
                page: 12,
                percentage: nil,
                timestamp: calendar.date(byAdding: .day, value: -7, to: now)!
            )
        ]
    }
}
#endif
