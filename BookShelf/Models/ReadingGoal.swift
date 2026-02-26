import Foundation
import SwiftData

@Model
final class ReadingGoal {
    var dailyPageGoal: Int?
    var weeklyPageGoal: Int?
    var dateCreated: Date
    var dateModified: Date

    init(
        dailyPageGoal: Int? = nil,
        weeklyPageGoal: Int? = nil,
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.dailyPageGoal = dailyPageGoal
        self.weeklyPageGoal = weeklyPageGoal
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }
}
