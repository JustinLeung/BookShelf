# Feature 03: Date Tracking (Start & Finish Dates)

## Overview

Track when a user starts and finishes reading a book. Currently, BookShelf only stores `dateAdded` (when the book was added to the shelf). Adding `dateStarted` and `dateFinished` enables reading speed calculations, time-to-read stats, monthly/yearly reading breakdowns, and is a prerequisite for the Reading Stats Dashboard (Feature 04) and Annual Reading Challenge (Feature 05).

## Competitive Analysis

| App | Date Tracking |
|-----|--------------|
| Goodreads | Date added, date started, date finished (manual entry) |
| Fable | Start and finish dates with auto-logging |
| StoryGraph | Start date, finish date, with re-read support (multiple date pairs) |
| Book Buddy | Date added, custom date fields |
| Bookly | Timer-based (auto-tracks reading session dates) |
| **BookShelf (current)** | **dateAdded only** |

### Design Decision: Auto vs Manual
- **Auto-set dates**: When user changes status to "Currently Reading", auto-set `dateStarted` to today. When status changes to "Read", auto-set `dateFinished` to today.
- **Manual override**: Allow users to edit dates manually (they may have started/finished on a different day).
- This matches Goodreads' approach and is the most user-friendly.

## Design Implications

### BookDetailView — Date Display

Dates appear in the existing "Details" section alongside ISBN, publisher, etc.:

```
┌─── Details ────────────────────┐
│  ISBN           9780593321201  │
│  Publisher      Penguin        │
│  Published      2023           │
│  Pages          416            │
│  Date Added     Jan 15, 2026   │
│  Started        Feb 1, 2026    │  ← NEW (tappable to edit)
│  Finished       Feb 18, 2026   │  ← NEW (tappable to edit)
│  Days to Read   17 days        │  ← NEW (computed)
└────────────────────────────────┘
```

**Tappable dates**: Tapping a date row opens a date picker sheet for manual editing.

**Conditional display**:
- `dateStarted`: Only shown if book is Currently Reading or Read
- `dateFinished`: Only shown if book is Read
- `daysToRead`: Only shown if both dates exist

### Date Edit Sheet

```
┌─────────────────────────────────┐
│  Edit Date                   ✕  │
│                                 │
│  Started Reading                │
│  ┌─────────────────────────┐    │
│  │  DatePicker (graphical)  │    │
│  └─────────────────────────┘    │
│                                 │
│  [Clear Date]    [Save]         │
└─────────────────────────────────┘
```

- Uses SwiftUI `DatePicker` with `.graphical` style
- "Clear Date" to remove the date (reset to nil)
- Validation: `dateFinished` cannot be before `dateStarted`

### BookshelfView — Sorting Enhancement

With dates available, add sorting options to the bookshelf:
- Date added (current default)
- Date started (most recently started first)
- Date finished (most recently finished first)
- Title (alphabetical)

This can be a simple menu button in the navigation bar.

## Data Model Changes

### Book.swift — New Properties

```swift
@Model final class Book {
    // ... existing properties ...

    // Date Tracking
    var dateStarted: Date?    // When user began reading
    var dateFinished: Date?   // When user finished reading
}
```

**Computed properties**:
```swift
var daysToRead: Int? {
    guard let start = dateStarted, let finish = dateFinished else { return nil }
    return Calendar.current.dateComponents([.day], from: start, to: finish).day
}

var readingYear: Int? {
    guard let finish = dateFinished else { return nil }
    return Calendar.current.component(.year, from: finish)
}

var readingMonth: Int? {
    guard let finish = dateFinished else { return nil }
    return Calendar.current.component(.month, from: finish)
}
```

### Migration Considerations

- Both fields are optional — safe to add without migration
- Existing books will have nil start/finish dates
- `dateAdded` remains untouched and continues to work
- Users can retroactively add dates for previously read books

## Architecture Changes

### New Files

| File | Purpose |
|------|---------|
| `Views/DateEditView.swift` | Sheet with DatePicker for editing start/finish dates |

### Modified Files

| File | Change |
|------|--------|
| `Models/Book.swift` | Add `dateStarted`, `dateFinished`, computed properties |
| `Views/BookDetailView.swift` | Display dates in details section, add tap-to-edit |
| `Views/BookshelfView.swift` | Add sort menu in navigation bar |
| `ViewModels/BookshelfViewModel.swift` | Auto-set dates on status change, add sort methods |

## Implementation Steps

1. **Add date properties to Book model**
   - `dateStarted: Date?`
   - `dateFinished: Date?`
   - `daysToRead` computed property
   - `readingYear` / `readingMonth` computed properties

2. **Auto-set dates on status transitions**
   In `BookshelfViewModel`, update `setReadStatus`:
   ```
   → Currently Reading: set dateStarted = Date() (if nil)
   → Read: set dateFinished = Date() (if nil)
   → Want to Read: clear dateStarted and dateFinished
   ```
   Only auto-set if the date is currently nil (don't overwrite user-edited dates).

3. **Create DateEditView**
   - DatePicker with `.graphical` display style
   - "Clear Date" button
   - Save/cancel actions
   - Date validation (finish >= start)

4. **Update BookDetailView**
   - Add date rows to Details section
   - Make date rows tappable → open DateEditView sheet
   - Show "Days to Read" computed value when both dates exist
   - Conditionally show based on read status

5. **Add sorting to BookshelfView**
   - Add `@State private var sortOption: SortOption`
   - Create `SortOption` enum: `.dateAdded`, `.dateStarted`, `.dateFinished`, `.title`
   - Add sort menu button to navigation bar (`.toolbar`)
   - Apply sort to each section's book array

6. **Update ViewModel**
   - `updateDateStarted(book:date:)` method
   - `updateDateFinished(book:date:)` method
   - Integrate auto-dating into `setReadStatus`

## Testing Strategy

- Test auto-set dateStarted when changing to Currently Reading
- Test auto-set dateFinished when changing to Read
- Test dates clear when changing to Want to Read
- Test manual date editing via DatePicker
- Test date validation (finish cannot precede start)
- Test daysToRead calculation
- Test nil handling (books without dates)
- Test sort options work correctly
- Test re-reading scenario: dates should reset when going back to Currently Reading

## Dependencies

- **Recommended after Feature 01** (Currently Reading status), as dateStarted naturally pairs with the Currently Reading transition
- **Required for Feature 04** (Stats Dashboard) — date data feeds monthly/yearly breakdowns
- **Required for Feature 05** (Annual Reading Challenge) — dateFinished determines which year a book counts toward

## Future Enhancements

- Re-read tracking: store array of (startDate, finishDate) pairs per book
- "On this day" feature: show what you were reading a year ago
- Reading pace alerts: "You started this 30 days ago, want to update progress?"
- Calendar view showing reading activity by day
- Export reading timeline
