# Feature 07: Goodreads CSV Import

## Overview

Allow users to import their book library from Goodreads via CSV export. This is the single most critical feature for user acquisition. Every successful Goodreads alternative (StoryGraph, Fable, Literal, Hardcover) offers Goodreads import as a core onboarding feature. Without it, users face the daunting task of manually re-adding potentially hundreds of books, which is a dealbreaker for adoption.

## Competitive Analysis

| App | Import Support |
|-----|---------------|
| StoryGraph | Goodreads CSV import (flagship feature, one-click) |
| Fable | Goodreads CSV import + StoryGraph import |
| Literal | Goodreads CSV import |
| Book Buddy | Goodreads CSV import + generic CSV |
| Hardcover | Goodreads CSV import |
| Libib | CSV import (generic) |
| **BookShelf (current)** | **None** |

### Anti-Goodreads Sentiment
Users actively want to leave Goodreads but won't abandon years of reading history. The import feature directly addresses this — it's not just a convenience, it's a migration path.

## Goodreads CSV Format

### How Users Export from Goodreads
1. Go to goodreads.com/review/import
2. Click "Export Library"
3. Download CSV file (arrives via email or direct download)

### CSV Column Structure

Goodreads exports a CSV with these columns (order may vary):

```
Book Id, Title, Author, Author l-f, Additional Authors,
ISBN, ISBN13, My Rating, Average Rating, Publisher,
Binding, Number of Pages, Year Published, Original Publication Year,
Date Read, Date Added, Bookshelves, Bookshelves with positions,
Exclusive Shelf, My Review, Spoiler, Private Notes,
Read Count, Owned Copies
```

### Key Columns for BookShelf

| Goodreads Column | Maps To | Notes |
|-----------------|---------|-------|
| `Title` | `book.title` | Direct mapping |
| `Author` | `book.authors[0]` | Primary author |
| `Additional Authors` | `book.authors[1...]` | Comma-separated |
| `ISBN13` | `book.isbn` | Preferred; remove `="` wrapper |
| `ISBN` | `book.isbn` (fallback) | If ISBN13 missing |
| `My Rating` | `book.rating` | 0 = unrated, 1-5 = rating |
| `Publisher` | `book.publisher` | Direct mapping |
| `Number of Pages` | `book.pageCount` | Direct mapping |
| `Year Published` | `book.publishDate` | Year only |
| `Exclusive Shelf` | `book.readStatus` | See mapping below |
| `Date Read` | `book.dateFinished` | Format: yyyy/MM/dd |
| `Date Added` | `book.dateAdded` | Format: yyyy/MM/dd |

### Shelf Mapping

| Goodreads `Exclusive Shelf` | BookShelf `ReadStatus` |
|----------------------------|----------------------|
| `read` | `.read` |
| `currently-reading` | `.currentlyReading` (Feature 01) |
| `to-read` | `.wantToRead` |

### ISBN Quirk

Goodreads wraps ISBNs in `="0123456789"` format to prevent Excel from treating them as numbers. Must strip the `="` prefix and `"` suffix:

```swift
func cleanGoodreadsISBN(_ raw: String) -> String {
    var cleaned = raw.trimmingCharacters(in: .whitespaces)
    if cleaned.hasPrefix("=\"") {
        cleaned = String(cleaned.dropFirst(2))
    }
    if cleaned.hasSuffix("\"") {
        cleaned = String(cleaned.dropLast())
    }
    return cleaned
}
```

## Design Implications

### Import Flow

**Step 1: Entry Point**
Add "Import Library" option. Possible locations:
- Settings screen (if added)
- BookshelfView toolbar menu
- Empty state ("Import from Goodreads" button)
- Onboarding flow

```
┌─────────────────────────────────┐
│  Import Library                 │
│                                 │
│  ┌────────────────────────────┐ │
│  │  📗 Import from Goodreads  │ │
│  │  Import your reading       │ │
│  │  history via CSV export    │ │
│  └────────────────────────────┘ │
│                                 │
│  ┌────────────────────────────┐ │
│  │  📄 Import CSV File        │ │
│  │  Import from any CSV file  │ │
│  │  with ISBN/title columns   │ │
│  └────────────────────────────┘ │
│                                 │
│  How to export from Goodreads:  │
│  1. Go to goodreads.com/review  │
│     /import                     │
│  2. Click "Export Library"      │
│  3. Download the CSV file       │
│  4. Open it here                │
└─────────────────────────────────┘
```

**Step 2: File Selection**
Use `fileImporter` modifier (SwiftUI) to present the system file picker:
- Filter: `.commaSeparatedText` (UTI for CSV files)
- Also accept `.plainText` as fallback

**Step 3: Import Preview**

```
┌─────────────────────────────────┐
│  Import Preview            [X]  │
│                                 │
│  Found 247 books in CSV         │
│                                 │
│  ┌────────────────────────────┐ │
│  │ ✅ 198 new books            │ │
│  │ ⚠️  49 already in library   │ │
│  │ ❌   0 errors               │ │
│  └────────────────────────────┘ │
│                                 │
│  Import options:                │
│  ☑ Import ratings              │
│  ☑ Import read dates           │
│  ☑ Import reviews as notes     │
│  ☐ Skip duplicates (by ISBN)   │
│  ☐ Fetch cover images          │
│                                 │
│  [Import 198 Books]             │
│                                 │
│  ⚠️ Cover images will be        │
│  fetched in the background      │
└─────────────────────────────────┘
```

**Step 4: Import Progress**

```
┌─────────────────────────────────┐
│  Importing...                   │
│                                 │
│  ████████████░░░░░░░  124/198   │
│                                 │
│  Currently importing:           │
│  "Tomorrow and Tomorrow..."     │
│                                 │
│  ✅ 120 imported                 │
│  ⚠️  4 skipped (no ISBN)        │
│  ❌  0 errors                    │
│                                 │
│  [Cancel]                       │
└─────────────────────────────────┘
```

**Step 5: Import Complete**

```
┌─────────────────────────────────┐
│  Import Complete! 🎉            │
│                                 │
│  ✅ 194 books imported           │
│  ⚠️  4 skipped (no ISBN)        │
│  ❌  0 errors                    │
│                                 │
│  📖 Want to Read: 87            │
│  📚 Currently Reading: 3        │
│  ✅ Read: 104                    │
│                                 │
│  [View Library]                 │
│                                 │
│  Cover images are being         │
│  downloaded in the background.  │
└─────────────────────────────────┘
```

## Data Architecture

### CSV Parsing

Use Swift's built-in CSV handling or a lightweight parser. Since Goodreads CSVs can have commas inside quoted fields, use proper CSV parsing (not simple split by comma).

```swift
struct GoodreadsCSVParser {
    func parse(data: Data) throws -> [GoodreadsBook] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidEncoding
        }

        let rows = parseCSVRows(content)  // Handle quoted fields properly
        let headers = rows.first ?? []
        let headerMap = Dictionary(uniqueKeysWithValues: headers.enumerated().map { ($1, $0) })

        return rows.dropFirst().compactMap { row in
            parseRow(row, headers: headerMap)
        }
    }
}

struct GoodreadsBook {
    let title: String
    let author: String
    let additionalAuthors: [String]
    let isbn: String?
    let isbn13: String?
    let rating: Int?         // 0 = unrated
    let publisher: String?
    let pageCount: Int?
    let yearPublished: String?
    let exclusiveShelf: String
    let dateRead: Date?
    let dateAdded: Date?
    let review: String?
}
```

### Import Strategy

1. **Parse CSV** → array of `GoodreadsBook`
2. **Deduplicate** → check existing books by ISBN
3. **Convert** → map to `Book` model
4. **Batch insert** → insert in batches (50 at a time) to avoid memory issues
5. **Fetch covers** → background task to download cover images via ISBN lookup
6. **Update widget** → refresh widget data after import

### Cover Image Strategy

Goodreads CSV does NOT include cover image URLs. Options:
- **Lazy loading**: Don't fetch covers during import; fetch on first view (existing CachedAsyncImage behavior)
- **Background fetch**: After import, queue background tasks to fetch covers via Google Books API using ISBNs
- **Recommended**: Background fetch with progress indicator

```swift
func fetchCoversForImportedBooks(_ books: [Book]) async {
    for book in books where book.coverImageData == nil {
        if let result = try? await GoogleBooksService.shared.searchByISBN(book.isbn) {
            if let url = result.coverURL {
                let data = try? await BookAPIService.shared.fetchCoverImage(url: url)
                book.coverImageData = data
                if let data = data {
                    await ImageCacheService.shared.cacheImage(data, for: book.isbn)
                }
            }
        }
        // Rate limit: small delay between API calls
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
    }
}
```

## Architecture Changes

### New Files

| File | Purpose |
|------|---------|
| `Services/GoodreadsImportService.swift` | CSV parsing, validation, conversion |
| `Views/Import/ImportView.swift` | Main import flow (entry point) |
| `Views/Import/ImportPreviewView.swift` | Preview with counts and options |
| `Views/Import/ImportProgressView.swift` | Progress bar during import |
| `Views/Import/ImportCompleteView.swift` | Summary after import |

### Modified Files

| File | Change |
|------|--------|
| `Views/BookshelfView.swift` | Add "Import" button to toolbar |
| `ViewModels/BookshelfViewModel.swift` | Add `importBooks` method |

## Implementation Steps

1. **Create GoodreadsImportService**
   - CSV parser that handles quoted fields, commas in titles, etc.
   - `GoodreadsBook` intermediate struct
   - `cleanGoodreadsISBN()` helper
   - Date parsing for `yyyy/MM/dd` format
   - Shelf-to-ReadStatus mapping
   - Validation: skip rows without title or ISBN

2. **Create ImportView**
   - Entry point with Goodreads import option
   - Instructions for exporting from Goodreads
   - `.fileImporter` modifier for file selection
   - Pass selected file URL to parser

3. **Create ImportPreviewView**
   - Display parsed book count
   - Show new vs duplicate counts
   - Import options (checkboxes)
   - "Import" button

4. **Create ImportProgressView**
   - Progress bar with book count
   - Current book title display
   - Success/skip/error counters
   - Cancel button

5. **Create ImportCompleteView**
   - Summary statistics
   - Breakdown by shelf
   - "View Library" button
   - Background cover fetch status

6. **Implement batch import in ViewModel**
   - Insert books in batches of 50
   - Skip duplicates by ISBN
   - Map ratings (0 → nil, 1-5 → Int)
   - Map shelves to ReadStatus
   - Save context after each batch
   - Report progress via callback

7. **Background cover fetch**
   - After import, start async task to fetch covers
   - Rate-limited API calls (0.2s delay)
   - Update books as covers arrive

8. **Add import entry point**
   - Toolbar button in BookshelfView
   - Also show in empty state

## Testing Strategy

- Test with real Goodreads CSV export file
- Test with malformed CSV (missing columns, extra commas)
- Test ISBN cleaning (`="0123456789"` format)
- Test duplicate detection
- Test shelf mapping (read, currently-reading, to-read)
- Test rating mapping (0 = nil, 1-5)
- Test date parsing
- Test with books missing ISBN (should skip or search by title)
- Test large import (500+ books) for performance
- Test cancellation mid-import
- Test encoding issues (UTF-8, special characters in titles)
- Test with Additional Authors field populated

## Dependencies

- **Enhanced by Feature 01** (Currently Reading) — maps `currently-reading` shelf correctly
- **Enhanced by Feature 03** (Date Tracking) — imports `Date Read` and `Date Added`
- Independent of other features — can be implemented standalone

## Future Enhancements

- StoryGraph CSV import
- Book Buddy import
- Generic CSV import with column mapping UI
- CSV export (for backup or switching to another app)
- Import from Apple Books reading history
- Import progress resume (if interrupted)
- Conflict resolution UI (when duplicate has different rating)
- Import reading progress (Goodreads stores page/percentage in some exports)
