# Feature 05: Annual Reading Challenge

## Overview

Let users set a yearly goal for how many books they want to read, with a visual progress tracker. This is Goodreads' most viral feature — the reading challenge is what keeps users engaged throughout the year and is frequently shared on social media. It's simple to implement but extremely high-engagement.

## Competitive Analysis

| App | Challenge Features |
|-----|-------------------|
| Goodreads | Annual book count goal, progress bar, ahead/behind schedule indicator, shareable, historical |
| StoryGraph | Customizable challenges (by count, pages, genre, etc.), multiple concurrent challenges |
| Fable | Annual goal with progress, club-based challenges |
| Bookly | Daily/weekly/monthly goals (pages, minutes, books) |
| Basmo | Daily time goals, streaks |
| **BookShelf (current)** | **None** |

### Goodreads Challenge (Reference Implementation)
- Set goal at start of year (e.g., "I want to read 24 books in 2026")
- Progress bar: "5 of 24 books (21%)"
- Schedule indicator: "2 books ahead of schedule" or "1 book behind schedule"
- Adjustable mid-year
- Shows all books read that year
- Shareable progress card

### Our Approach
Start with the Goodreads-style annual challenge (simple, proven). Can expand to more granular goals later.

## Design Implications

### Challenge Setup

First-time experience — prompt to set a goal:

```
┌─────────────────────────────────┐
│                                 │
│  📚 2026 Reading Challenge      │
│                                 │
│  How many books do you want     │
│  to read this year?             │
│                                 │
│         ┌────────┐              │
│         │   24   │              │
│         └────────┘              │
│     [-]              [+]        │
│                                 │
│  That's about 2 books per month │
│                                 │
│       [Start Challenge]         │
│                                 │
└─────────────────────────────────┘
```

### Challenge Progress (in Stats tab or Bookshelf header)

```
┌─── 2026 Reading Challenge ─────┐
│                                 │
│  5 of 24 books                  │
│  ████████░░░░░░░░░░░░░░░  21%  │
│                                 │
│  📈 2 books ahead of schedule   │
│                                 │
│  [View Books]    [Edit Goal]    │
└─────────────────────────────────┘
```

**Schedule calculation**:
```
Expected by now = goal × (dayOfYear / 365)
Difference = booksRead - expected
"X books ahead/behind schedule"
```

**Color coding**:
- Ahead of schedule: green text
- On schedule: accent color
- Behind schedule: orange/red text

### Challenge Placement Options

**Option A**: Card at top of BookshelfView (always visible, prominent)
**Option B**: Section in Stats tab (clean, but less visible)
**Option C**: Both — summary card in Bookshelf, detailed view in Stats

**Recommended: Option C** — A compact summary in BookshelfView (above the book sections) with a tap-to-expand that navigates to full challenge details in Stats.

### Challenge Detail View

Full-screen view showing:
- Large progress ring or bar
- Books read count and goal
- Schedule status
- Grid of book covers read this year (chronological)
- "Edit Goal" button
- "Share" button (generates shareable image)

### Bookshelf Header Card

Compact version shown at top of BookshelfView:

```
┌─────────────────────────────────┐
│ 📚 2026 Challenge  5/24  ████░░│
│ 2 ahead of schedule    [View →]│
└─────────────────────────────────┘
```

Tapping opens the full challenge detail.

## Data Model Changes

### New Model: ReadingChallenge

```swift
@Model final class ReadingChallenge {
    var year: Int              // e.g., 2026
    var goalCount: Int         // target number of books
    var dateCreated: Date

    init(year: Int, goalCount: Int) {
        self.year = year
        self.goalCount = goalCount
        self.dateCreated = Date()
    }
}
```

**Why a separate model?**
- Persists goal across app launches
- Supports historical challenges (view past years)
- Clean separation from Book model
- Simple schema

### Computed Properties (in ViewModel, not persisted)

```swift
var booksReadThisYear: [Book] {
    books.filter {
        $0.readStatus == .read &&
        $0.dateFinished != nil &&
        Calendar.current.component(.year, from: $0.dateFinished!) == currentYear
    }
}

var challengeProgress: Double {
    guard let challenge = currentChallenge, challenge.goalCount > 0 else { return 0 }
    return Double(booksReadThisYear.count) / Double(challenge.goalCount)
}

var booksAheadOfSchedule: Int {
    let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
    let expectedByNow = Double(challenge.goalCount) * (Double(dayOfYear) / 365.0)
    return booksReadThisYear.count - Int(expectedByNow.rounded())
}
```

### Migration Considerations

- New model, no migration needed for existing data
- Register `ReadingChallenge.self` in SwiftData schema
- Challenge data is independent of book data

## Architecture Changes

### New Files

| File | Purpose |
|------|---------|
| `Models/ReadingChallenge.swift` | Challenge model (year, goal count) |
| `Views/Challenge/ChallengeSetupView.swift` | Goal setting sheet with stepper |
| `Views/Challenge/ChallengeProgressCard.swift` | Compact progress card for BookshelfView header |
| `Views/Challenge/ChallengeDetailView.swift` | Full challenge view with book grid |

### Modified Files

| File | Change |
|------|--------|
| `BookShelfApp.swift` | Register `ReadingChallenge.self` in schema |
| `Views/BookshelfView.swift` | Add ChallengeProgressCard at top of scroll view |
| `ViewModels/BookshelfViewModel.swift` | Add challenge-related computed properties and methods |

## Implementation Steps

1. **Create ReadingChallenge model**
   - Year, goalCount, dateCreated
   - Register in SwiftData schema

2. **Create ChallengeSetupView**
   - Stepper or +/- buttons for goal count (range: 1-200)
   - "books per month" helper text (goal / 12)
   - "Start Challenge" button
   - Presented as sheet from BookshelfView

3. **Create ChallengeProgressCard**
   - Compact horizontal card
   - Progress bar (ProgressView linear style or custom)
   - "X of Y books" label
   - Ahead/behind schedule indicator with color
   - Tap gesture to navigate to detail

4. **Create ChallengeDetailView**
   - Large progress display (ring or bar)
   - Schedule status with explanation
   - LazyVGrid of book covers read this year
   - "Edit Goal" button → re-opens setup view
   - "Share Progress" button (future: generates shareable image)

5. **Update BookshelfView**
   - Query for current year's ReadingChallenge
   - If challenge exists: show ChallengeProgressCard above book sections
   - If no challenge: show "Set a Reading Goal" prompt (or nothing)

6. **Update ViewModel**
   - `createChallenge(year:goal:)` method
   - `updateChallengeGoal(_:newGoal:)` method
   - `currentChallenge` computed property (fetch for current year)
   - `booksReadInYear(_:)` method

7. **Auto-prompt for new year**
   - On app launch in January, if no challenge for current year: prompt to set one
   - Optional: carry over last year's goal as suggestion

## Testing Strategy

- Test challenge creation and persistence
- Test progress calculation with various book counts
- Test ahead/behind schedule calculation at different times of year
- Test year boundary (books finished Dec 31 vs Jan 1)
- Test goal editing mid-year
- Test with 0 books read (empty state)
- Test with goal exceeded (> 100% progress)
- Test challenge for past years
- Test without Feature 03 dates (fallback to dateAdded?)

## Dependencies

- **Strongly benefits from Feature 03** (Date Tracking) — uses `dateFinished` to determine which year a book counts toward
- **Without Feature 03**: Could fall back to `dateAdded` for the year, but less accurate
- Displays well in Feature 04 (Stats Dashboard) as an additional card

## Future Enhancements

- Monthly/weekly mini-challenges
- Genre-specific challenges ("Read 5 non-fiction books")
- Page count challenges ("Read 10,000 pages")
- Challenge history view (compare year-over-year)
- Shareable progress card for social media (rendered image)
- Push notification reminders ("You're 2 books behind, pick up a book!")
- Celebration animation when challenge is completed
- Community challenges (if social features added)
