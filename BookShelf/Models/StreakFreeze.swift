import Foundation
import SwiftData

@Model
final class StreakFreeze {
    var dateUsed: Date
    var weekOfYear: Int
    var year: Int

    init(
        dateUsed: Date = Date(),
        weekOfYear: Int,
        year: Int
    ) {
        self.dateUsed = dateUsed
        self.weekOfYear = weekOfYear
        self.year = year
    }
}
