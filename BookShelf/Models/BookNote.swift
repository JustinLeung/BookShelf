import Foundation
import SwiftData

enum NoteType: String, Codable {
    case quote
    case note
}

@Model
final class BookNote {
    var bookISBN: String
    var text: String
    var noteTypeRaw: String
    var pageNumber: Int?
    var dateCreated: Date
    @Attribute(.externalStorage) var sourceImageData: Data?

    var noteType: NoteType {
        get { NoteType(rawValue: noteTypeRaw) ?? .note }
        set { noteTypeRaw = newValue.rawValue }
    }

    init(
        bookISBN: String,
        text: String,
        noteType: NoteType = .note,
        pageNumber: Int? = nil,
        dateCreated: Date = Date(),
        sourceImageData: Data? = nil
    ) {
        self.bookISBN = bookISBN
        self.text = text
        self.noteTypeRaw = noteType.rawValue
        self.pageNumber = pageNumber
        self.dateCreated = dateCreated
        self.sourceImageData = sourceImageData
    }
}
