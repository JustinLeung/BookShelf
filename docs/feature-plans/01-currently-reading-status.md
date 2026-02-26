# Feature 01: "Currently Reading" Status

## Overview

Add a third reading status — "Currently Reading" — to the existing "Want to Read" and "Read" statuses. This is the single most expected feature in any book tracking app. Every major competitor (Goodreads, Fable, StoryGraph, Book Buddy) supports it. Without it, users cannot distinguish between books they haven't started and books they're actively reading.

## Competitive Analysis

| App | Statuses Supported |
|-----|-------------------|
| Goodreads | Want to Read, Currently Reading, Read |
| Fable | Want to Read, Currently Reading, Read |
| StoryGraph | Want to Read, Currently Reading, Read, DNF |
| Book Buddy | Custom statuses (flexible) |
| Bookly | Currently Reading, Finished |
| **BookShelf (current)** | **Want to Read, Read** |

## Design Implications

### UI Changes

**BookshelfView — New Section**
The main grid currently shows two sections: "Want to Read" and "Read". A third section "Currently Reading" should appear **between** them (the most important section, shown first):

```
┌─────────────────────────────────┐
│  Currently Reading (2)          │
│  ┌─────┐  ┌─────┐              │
│  │ 📖  │  │ 📖  │              │
│  │cover│  │cover│              │
│  └─────┘  └─────┘              │
│                                 │
│  Want to Read (5)               │
│  ┌─────┐  ┌─────┐  ┌─────┐    │
│  │     │  │     │  │     │    │
│  └─────┘  └─────┘  └─────┘    │
│                                 │
│  Read (12)                      │
│  ┌─────┐  ┌─────┐  ┌─────┐    │
│  │     │  │     │  │     │    │
│  └─────┘  └─────┘  └─────┘    │
└─────────────────────────────────┘
```

**BookDetailView — Status Toggle**
The current two-button toggle (Want to Read / Read) becomes a three-button toggle. Consider using a segmented-style layout:

```
┌──────────────┬──────────────────┬──────────┐
│ Want to Read │ Currently Reading │   Read   │
└──────────────┴──────────────────┴──────────┘
```

- Active status: accent color background, white text
- Inactive: systemGray5 background, primary text
- Transitioning to "Read" should prompt for a rating
- Transitioning away from "Read" should clear the rating (existing behavior)

**Context Menu**
The context menu on BookshelfView grid items currently shows "Mark as Read" / "Mark as Want to Read" toggle. Update to show the two statuses the book is NOT currently in:
- If "Want to Read": Show "Start Reading" and "Mark as Read"
- If "Currently Reading": Show "Mark as Want to Read" and "Mark as Read"
- If "Read": Show "Mark as Want to Read" and "Start Reading"

**Grid Item Badge**
Consider showing a small progress indicator or "reading" badge on currently-reading books in the grid to make them visually distinct.

### User Flow

```
Add Book → defaults to "Want to Read"
         ↓
User taps "Currently Reading" → book moves to Currently Reading section
         ↓
User taps "Read" → book moves to Read section, star rating appears
         ↓
User can move back to any status at any time
```

## Data Model Changes

### Book.swift

**ReadStatus Enum** — Add new case:

```swift
enum ReadStatus: String, Codable, CaseIterable {
    case wantToRead = "want_to_read"
    case currentlyReading = "currently_reading"  // NEW
    case read = "read"

    var displayName: String {
        switch self {
        case .wantToRead: return "Want to Read"
        case .currentlyReading: return "Currently Reading"
        case .read: return "Read"
        }
    }

    var icon: String {
        switch self {
        case .wantToRead: return "bookmark"
        case .currentlyReading: return "book.fill"
        case .read: return "checkmark.circle.fill"
        }
    }
}
```

### Migration Considerations

- **Safe migration**: Adding a new case to a String-backed enum is backwards-compatible
- Existing books with `readStatusRaw = "want_to_read"` or `"read"` remain valid
- No SwiftData schema migration needed — the field type (String) doesn't change
- The computed property `readStatus` will still decode existing values correctly
- Default for new books remains `.wantToRead`

## Architecture Changes

### Files Modified

| File | Change |
|------|--------|
| `Models/Book.swift` | Add `.currentlyReading` case to `ReadStatus` enum |
| `Views/BookshelfView.swift` | Add `currentlyReadingBooks` computed property, new section in grid |
| `Views/BookDetailView.swift` | Update status toggle from 2 buttons to 3 |
| `ViewModels/BookshelfViewModel.swift` | Update `toggleReadStatus` logic for 3-state cycle |

### No New Files Required

This feature is entirely contained within existing files.

## Implementation Steps

1. **Add enum case** to `ReadStatus` in `Book.swift`
   - Add `.currentlyReading = "currently_reading"`
   - Add `displayName` and `icon` computed properties

2. **Update BookshelfView**
   - Add `currentlyReadingBooks` computed property (filter by `.currentlyReading`)
   - Add new section in `booksListView` between existing sections
   - Reorder sections: Currently Reading → Want to Read → Read
   - Update context menu items for 3-state model

3. **Update BookDetailView**
   - Change status toggle from 2-button HStack to 3-button layout
   - Ensure rating is cleared when moving away from `.read`
   - Ensure rating section only shows for `.read` status (already works)

4. **Update BookshelfViewModel**
   - Modify `toggleReadStatus` to cycle: wantToRead → currentlyReading → read → wantToRead
   - Or remove cycle behavior and rely on `setReadStatus` for explicit selection
   - Clear rating when status changes away from `.read` (existing behavior)

5. **Update empty state logic**
   - Include currently reading books in the "has books" check
   - Update empty state message if needed

## Testing Strategy

- Verify existing books still load with old status values
- Test status transitions: all 6 directional transitions between 3 states
- Verify rating clears when moving from Read → any other status
- Verify rating only shows for Read status
- Verify grid sections filter correctly
- Verify context menu shows correct options per status
- Test adding a new book defaults to Want to Read

## Future Enhancements

- Reading progress tracking (pairs naturally with Currently Reading)
- "Started reading on" date auto-set when moving to Currently Reading
- Currently Reading widget on home screen
- Reading timer integration (auto-starts when book is Currently Reading)
