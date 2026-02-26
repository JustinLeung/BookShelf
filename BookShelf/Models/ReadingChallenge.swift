import Foundation
import SwiftData

@Model
final class ReadingChallenge {
    var year: Int
    var goalCount: Int
    var dateCreated: Date
    var dateModified: Date

    init(
        year: Int,
        goalCount: Int,
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.year = year
        self.goalCount = goalCount
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }
}
