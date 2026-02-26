# Feature 02: Reading Progress Tracking

## Overview

Allow users to track their reading progress for books marked as "Currently Reading" by recording current page number or percentage. This is a natural companion to the "Currently Reading" status (Feature 01) and is supported by every major competitor.

## Competitive Analysis

| App | Progress Tracking |
|-----|------------------|
| Goodreads | Page number OR percentage; progress updates visible in feed |
| Fable | Page/percentage with sync across devices |
| StoryGraph | Page number with progress bar |
| Bookly | Pages per session via reading timer |
| Basmo | Pages per session via reading timer |
| **BookShelf (current)** | **None** |

### Key Differentiator Opportunity
Most apps only track a single current page. BookShelf could track **progress history** (a log of page updates over time), enabling reading speed calculations and progress graphs later. This small data model investment pays dividends for the Stats Dashboard (Feature 04) and Reading Timer (Feature 10).

## Design Implications

### BookDetailView — Progress Section

When a book's status is "Currently Reading", show a progress section between the status toggle and purchase buttons:

```
┌─────────────────────────────────┐
│         [Book Cover]            │
│        Title / Author           │
│                                 │
│  [Want to Read] [Reading] [Read]│
│                                 │
│  ┌─── Reading Progress ──────┐  │
│  │                            │  │
│  │  Page [145] of 382         │  │
│  │  ████████████░░░░░░░  38%  │  │
│  │                            │  │
│  │  [Update Progress]         │  │
│  └────────────────────────────┘  │
│                                 │
│  [Amazon]  [Audible]            │
└─────────────────────────────────┘
```

**Progress Bar**: Horizontal bar showing percentage complete. Uses accent color for filled portion, systemGray5 for remaining.

**Page Input**: Tapping "Update Progress" shows a sheet or inline editor with a number pad to enter current page. Auto-calculates percentage if `pageCount` is available.

**Percentage Fallback**: If `pageCount` is nil (some API results lack it), allow percentage-only input (0-100 slider or text field).

### BookshelfView — Progress Indicator on Grid

Currently-reading books in the grid should show a subtle progress bar beneath the cover:

```
┌─────────┐
│  cover   │
│  image   │
├─────────┤  ← thin progress bar
│████░░░░░│
└─────────┘
  Title
  Author
```

- Progress bar: 3pt height, accent color fill, rounded
- Only shown for books with status `.currentlyReading`

### Progress Update Flow

```
User taps "Update Progress"
    ↓
Sheet appears with:
  - Current page text field (number pad)
  - Total pages display (from pageCount)
  - Progress bar preview
  - "Save" button
    ↓
Progress saved → bar updates → history entry logged
```

## Data Model Changes

### Book.swift — New Properties

```swift
@Model final class Book {
    // ... existing properties ...

    // Reading Progress
    var currentPage: Int?           // Current page number
    var progressPercentage: Double? // 0.0 to 1.0 (computed or manual)
}
```

**Computed property for progress**:
```swift
var calculatedProgress: Double? {
    if let current = currentPage, let total = pageCount, total > 0 {
        return Double(current) / Double(total)
    }
    return progressPercentage
}
```

### New Model: ReadingProgressEntry (Optional — for history tracking)

```swift
@Model final class ReadingProgressEntry {
    var bookISBN: String
    var page: Int?
    var percentage: Double?
    var timestamp: Date

    init(bookISBN: String, page: Int? = nil, percentage: Double? = nil) {
        self.bookISBN = bookISBN
        self.page = page
        self.percentage = percentage
        self.timestamp = Date()
    }
}
```

This model enables:
- Progress over time graphs (for Stats Dashboard)
- Reading speed calculation (pages per day)
- "You read X pages today" tracking

### Migration Considerations

- `currentPage` and `progressPercentage` are both optional — safe to add
- Existing books will have nil values (no progress shown)
- Register `ReadingProgressEntry.self` in the SwiftData schema in `BookShelfApp.swift`
- No data migration needed — purely additive

## Architecture Changes

### New Files

| File | Purpose |
|------|---------|
| `Models/ReadingProgressEntry.swift` | Progress history model |
| `Views/ProgressUpdateView.swift` | Sheet for updating current page |
| `Views/ReadingProgressBar.swift` | Reusable progress bar component |

### Modified Files

| File | Change |
|------|--------|
| `Models/Book.swift` | Add `currentPage`, `progressPercentage`, computed `calculatedProgress` |
| `BookShelfApp.swift` | Register `ReadingProgressEntry.self` in schema |
| `Views/BookshelfView.swift` | Add progress bar to grid items for currently reading books |
| `Views/BookDetailView.swift` | Add progress section with update button |
| `ViewModels/BookshelfViewModel.swift` | Add `updateProgress(book:page:)` method |

## Implementation Steps

1. **Add properties to Book model**
   - `currentPage: Int?`
   - `progressPercentage: Double?`
   - `calculatedProgress` computed property

2. **Create ReadingProgressEntry model**
   - ISBN, page, percentage, timestamp
   - Register in SwiftData schema

3. **Create ReadingProgressBar view**
   - Reusable component: takes progress (0.0-1.0) and optional page/total display
   - Accent color fill on systemGray5 track
   - Configurable height (3pt for grid, 8pt for detail)

4. **Create ProgressUpdateView sheet**
   - Number pad text field for current page
   - Shows total pages if available
   - Live preview of progress bar
   - Percentage display
   - Save button that calls viewModel method

5. **Update BookDetailView**
   - Show progress section when status is `.currentlyReading`
   - Display current page / total pages
   - Display progress bar
   - "Update Progress" button that opens sheet

6. **Update BookshelfView grid items**
   - Add thin progress bar below cover image for currently-reading books
   - Only render if `calculatedProgress` is non-nil

7. **Update BookshelfViewModel**
   - `updateProgress(book:page:)` method
   - Creates `ReadingProgressEntry` for history
   - Updates `book.currentPage` and `book.progressPercentage`
   - Saves context

8. **Clear progress on status change**
   - When status changes FROM `.currentlyReading` to `.read`: keep final progress (100%)
   - When status changes FROM `.currentlyReading` to `.wantToRead`: clear progress
   - When status changes TO `.currentlyReading`: reset progress to 0 if previously nil

## Testing Strategy

- Test progress update with valid page count
- Test progress update without page count (percentage only)
- Test progress bar rendering at 0%, 50%, 100%
- Test progress clears on status change to Want to Read
- Test progress preserved on status change to Read
- Test progress history entries are created
- Test calculatedProgress computed property with various inputs
- Test edge cases: page > pageCount, negative values, zero pageCount

## Dependencies

- **Requires Feature 01** (Currently Reading status) to be implemented first
- Enables Feature 04 (Reading Stats Dashboard) — progress history feeds into analytics
- Enables Feature 10 (Reading Timer) — timer sessions can auto-update progress

## Future Enhancements

- Progress notifications ("You're 75% through BookTitle!")
- Reading speed estimate ("At your pace, you'll finish in 3 days")
- Progress sharing to social media
- Graph of progress over time in book detail view
- Daily reading goals based on page targets
