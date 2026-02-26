import Foundation
import SwiftData

@Model
final class ReadingSession {
    var bookISBN: String
    var startTime: Date
    var endTime: Date
    var duration: TimeInterval
    var pagesRead: Int?
    var startPage: Int?
    var endPage: Int?

    init(
        bookISBN: String,
        startTime: Date,
        endTime: Date,
        duration: TimeInterval,
        pagesRead: Int? = nil,
        startPage: Int? = nil,
        endPage: Int? = nil
    ) {
        self.bookISBN = bookISBN
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.pagesRead = pagesRead
        self.startPage = startPage
        self.endPage = endPage
    }

    var pagesPerHour: Double? {
        guard let pagesRead, pagesRead > 0, duration > 0 else { return nil }
        return Double(pagesRead) / (duration / 3600.0)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
