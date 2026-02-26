# Feature 06: Home Screen Widgets

## Overview

Add iOS home screen widgets using WidgetKit that display reading information at a glance — currently reading book, reading challenge progress, and reading stats. Widgets are one of the most requested iOS features and serve as a constant reminder to read, driving daily engagement. Book Buddy and Bookly both offer compelling widgets that are frequently cited as reasons users choose those apps.

## Competitive Analysis

| App | Widget Offerings |
|-----|-----------------|
| Book Buddy | Currently reading (small/medium), stats summary, library count |
| Bookly | Reading timer, streak counter, daily goal progress, currently reading |
| Fable | Current read with progress, reading goal |
| Goodreads | Currently reading (basic), challenge progress |
| StoryGraph | Limited widget support |
| **BookShelf (current)** | **None** |

### Most Popular Widget Types (by user demand)
1. **Currently Reading** — Book cover + title + progress bar (most requested)
2. **Reading Challenge Progress** — X of Y books with progress ring
3. **Reading Stats** — Books this year, pages, streak
4. **Up Next** — Next book in Want to Read queue

## Design Implications

### Widget Sizes & Layouts

#### Small Widget — Currently Reading

```
┌─────────────────┐
│ ┌─────┐ Title   │
│ │cover│ Author  │
│ │     │         │
│ │     │ ██░░ 38%│
│ └─────┘         │
└─────────────────┘
```

- Shows cover thumbnail, title (2 lines), author (1 line)
- Progress bar at bottom (if tracking progress)
- Tap opens the app to the book's detail view
- If no currently reading book: show "Start Reading" prompt

#### Medium Widget — Currently Reading + Challenge

```
┌──────────────────────────────────────┐
│ ┌─────┐ Title of Book    │ 2026     │
│ │cover│ Author Name      │ Challenge│
│ │     │                  │          │
│ │     │ ██████░░░░ 62%   │  5/24    │
│ └─────┘                  │  ◐ 21%   │
└──────────────────────────────────────┘
```

- Left side: currently reading book with progress
- Right side: reading challenge progress ring
- Divider between sections

#### Large Widget — Reading Dashboard

```
┌──────────────────────────────────────┐
│  📚 BookShelf                        │
│                                      │
│  Currently Reading                   │
│  ┌─────┐ Title          ███░░ 62%   │
│  └─────┘ Author                      │
│                                      │
│  2026 Reading Challenge              │
│  ████████████░░░░░░░  12/24 books   │
│                                      │
│  This Month    │  This Year          │
│  2 books       │  12 books           │
│  486 pages     │  3,840 pages        │
└──────────────────────────────────────┘
```

#### Lock Screen Widgets (iOS 16+)

**Circular**: Challenge progress ring (5/24)
**Rectangular**: Currently reading title + progress bar
**Inline**: "Reading: Book Title — 62%"

### Deep Linking
Each widget tap should deep link to the relevant section:
- Currently Reading → BookDetailView for that book
- Challenge → Challenge detail view
- Stats → Stats tab

## Data Architecture

### App Groups & Shared Data

Widgets run in a **separate process** from the main app. They cannot access SwiftData directly. Data must be shared via:

**Option A: App Groups + UserDefaults (Recommended for v1)**
- Create an App Group identifier (e.g., `group.com.bookshelf.shared`)
- Write widget data to shared `UserDefaults(suiteName:)`
- Simple, reliable, well-documented

**Option B: App Groups + Shared SwiftData Container**
- Configure ModelContainer with App Group URL
- More complex setup, but allows direct data queries
- Better for large datasets

**Recommended: Option A for initial implementation**, migrate to Option B if needed.

### Shared Data Structure

```swift
struct WidgetData: Codable {
    // Currently Reading
    var currentBookTitle: String?
    var currentBookAuthor: String?
    var currentBookISBN: String?
    var currentBookProgress: Double?    // 0.0-1.0
    var currentBookCoverData: Data?     // Compressed thumbnail

    // Challenge
    var challengeGoal: Int?
    var challengeBooksRead: Int?
    var challengeYear: Int?

    // Stats
    var booksThisMonth: Int
    var booksThisYear: Int
    var pagesThisMonth: Int
    var pagesThisYear: Int

    var lastUpdated: Date
}
```

### Data Sync Strategy

Update widget data whenever:
- Book status changes
- Reading progress updates
- Book added or deleted
- Challenge goal changes

```swift
func updateWidgetData() {
    let data = WidgetData(
        currentBookTitle: currentlyReadingBooks.first?.title,
        // ... populate all fields
    )
    let encoder = JSONEncoder()
    let encoded = try encoder.encode(data)
    UserDefaults(suiteName: "group.com.bookshelf.shared")?.set(encoded, forKey: "widgetData")
    WidgetCenter.shared.reloadAllTimelines()
}
```

## Architecture Changes

### New Target: BookShelfWidgets

WidgetKit requires a **separate target** (Widget Extension) in the Xcode project.

### New Files

| File | Target | Purpose |
|------|--------|---------|
| `BookShelfWidgets/BookShelfWidgets.swift` | Widget Extension | Widget bundle entry point |
| `BookShelfWidgets/CurrentlyReadingWidget.swift` | Widget Extension | Currently reading widget (small/medium) |
| `BookShelfWidgets/ChallengeWidget.swift` | Widget Extension | Challenge progress widget |
| `BookShelfWidgets/DashboardWidget.swift` | Widget Extension | Large dashboard widget |
| `BookShelfWidgets/LockScreenWidgets.swift` | Widget Extension | Lock screen widget variants |
| `BookShelfWidgets/WidgetData.swift` | Shared | Shared data model (both targets) |
| `BookShelfWidgets/WidgetDataProvider.swift` | Widget Extension | Timeline provider |

### Modified Files

| File | Change |
|------|--------|
| `BookShelfApp.swift` | Configure App Group for shared container |
| `ViewModels/BookshelfViewModel.swift` | Call `updateWidgetData()` on data changes |
| `BookShelf.xcodeproj` | Add Widget Extension target, App Group capability |

### Xcode Project Changes

1. Add **Widget Extension** target (File → New → Target → Widget Extension)
2. Add **App Groups** capability to both main app and widget targets
3. Configure shared App Group identifier
4. Add shared files to both targets (WidgetData model)

## Implementation Steps

1. **Configure App Group**
   - Add App Groups capability to main app target
   - Create group identifier: `group.com.bookshelf.shared`
   - Add same capability to widget extension target

2. **Create WidgetData shared model**
   - Define `Codable` struct with all widget-relevant data
   - Place in shared group or framework accessible to both targets

3. **Add widget data sync to main app**
   - Create `WidgetDataService` class
   - Method `updateWidgetData()` serializes current state to shared UserDefaults
   - Call from BookshelfViewModel on every data mutation
   - Call `WidgetCenter.shared.reloadAllTimelines()` after update

4. **Create Widget Extension target**
   - Add new target in Xcode
   - Configure with App Group

5. **Implement TimelineProvider**
   ```swift
   struct Provider: TimelineProvider {
       func placeholder(in context: Context) -> WidgetEntry { ... }
       func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) { ... }
       func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
           // Read from shared UserDefaults
           // Create timeline with single entry
           // Refresh policy: .after(Date().addingTimeInterval(3600)) // hourly
       }
   }
   ```

6. **Create Currently Reading Widget views**
   - Small: cover + title + author + progress
   - Medium: cover + title + author + progress + challenge
   - Handle empty state (no currently reading book)

7. **Create Challenge Widget view**
   - Progress ring using `Circle` stroke
   - Books count label
   - Handle no active challenge state

8. **Create Lock Screen widgets**
   - Circular: challenge progress
   - Rectangular: currently reading + progress
   - Inline: book title

9. **Add deep linking**
   - Use `widgetURL()` modifier for widget tap targets
   - Handle URL scheme in main app's `onOpenURL`
   - Navigate to appropriate view based on URL

10. **Create preview snapshots**
    - Design preview data for Widget Gallery
    - Ensure widgets look good in Xcode previews

## Testing Strategy

- Test widget renders with complete data
- Test widget renders with missing data (no book, no challenge, no progress)
- Test data sync from main app to widget
- Test deep linking from widget to app
- Test all widget sizes (small, medium, large)
- Test lock screen widgets
- Test widget gallery preview/snapshot
- Test widget refresh timeline
- Test dark mode rendering
- Test dynamic type / accessibility sizes
- Test on multiple device sizes

## Dependencies

- **Enhanced by Feature 01** (Currently Reading) — primary content for the widget
- **Enhanced by Feature 02** (Reading Progress) — progress bar on widget
- **Enhanced by Feature 05** (Reading Challenge) — challenge progress ring
- Works in a basic form without these (can show last read book, total counts)

## Future Enhancements

- Interactive widgets (iOS 17+): Mark book as read directly from widget
- Live Activities: Show reading timer as Live Activity on lock screen
- Widget suggestions via Siri Shortcuts (proactive widget placement)
- Multiple widget configurations (choose which book to display)
- "Up Next" widget showing top of Want to Read queue
- Reading streak widget
- Animated progress updates
