# Feature 10: Reading Timer

## Overview

Add a reading timer that lets users track how long they spend reading during each session. This enables accurate reading speed calculations, time-based goals, and detailed session history. It's the signature feature of Bookly and Basmo, and transforms BookShelf from a passive tracking tool into an active reading companion that encourages daily reading habits.

## Competitive Analysis

| App | Timer Features |
|-----|---------------|
| Bookly | Start/stop timer, pages per session, speed calculation, estimated finish time, streaks, session history |
| Basmo | Timer with journaling prompts, emotion tracking after sessions, daily time goals |
| Fable | Automatic time tracking in built-in reader |
| Goodreads | No timer (tracks dates only) |
| StoryGraph | No timer |
| Book Buddy | No timer |
| **BookShelf (current)** | **None** |

### Bookly's Timer (Gold Standard)
- Tap to start timer for a specific book
- Timer runs in background (with notification)
- End session: enter pages read
- Calculates pages/hour, estimated time to finish
- Session history with graphs
- Daily/weekly goals based on time

### Our Approach
Build a clean, focused timer that integrates naturally with the Currently Reading flow. Start simple (start/stop + pages), then layer on analytics.

## Design Implications

### Timer Entry Points

**Option A: Floating action button** on BookshelfView
- Always visible, one-tap to start
- Auto-selects currently reading book (or lets you pick)

**Option B: From BookDetailView** (currently reading books only)
- "Start Reading Session" button
- Clear association with specific book

**Option C: Dedicated timer tab**
- Replace or supplement an existing tab
- Gives timer its own space

**Recommended: Option B + mini-player** — Start from BookDetailView, show a persistent mini-player bar at bottom of screen while timer is running (like a music player).

### Timer UI

**Full Timer View** (sheet or dedicated view):

```
┌─────────────────────────────────┐
│  Reading Session           [X]  │
│                                 │
│  ┌─────┐                        │
│  │cover│  The Great Gatsby      │
│  └─────┘  F. Scott Fitzgerald   │
│                                 │
│                                 │
│           02:34:17              │
│        hours  min  sec          │
│                                 │
│                                 │
│    ┌─────────────────────┐      │
│    │                     │      │
│    │    ⏸ Pause           │      │
│    │                     │      │
│    └─────────────────────┘      │
│                                 │
│    [End Session]                │
│                                 │
└─────────────────────────────────┘
```

**Timer States**:
- **Idle**: "Start Reading" button (large, accent color)
- **Running**: Elapsed time display + Pause button
- **Paused**: Elapsed time + Resume button + End Session button
- **Ended**: Pages read input → Save

### Mini-Player Bar

When timer is running and user navigates away, show a persistent bar:

```
┌──────────────────────────────────────┐
│ 📖 The Great Gatsby    02:34  ⏸  ■  │
└──────────────────────────────────────┘
```

- Shows book title, elapsed time, pause/play, stop
- Tap to expand full timer view
- Appears above tab bar
- Persists across all tabs

### End Session Flow

```
┌─────────────────────────────────┐
│  Session Complete!         [X]  │
│                                 │
│  Duration: 45 minutes           │
│                                 │
│  How many pages did you read?   │
│  ┌──────────────┐               │
│  │     23       │               │
│  └──────────────┘               │
│                                 │
│  Current page: 145 → 168        │
│                                 │
│  Reading speed: 31 pages/hour   │
│                                 │
│  [Save Session]                 │
└─────────────────────────────────┘
```

- Enter pages read during session
- Auto-calculate new current page (if tracking progress)
- Show reading speed for this session
- Option to update reading progress (Feature 02 integration)

### Session History

In BookDetailView or Stats tab:

```
┌─── Reading Sessions ──────────┐
│                                │
│  Today          45 min  23 pg  │
│  Yesterday      1h 12m  38 pg │
│  Feb 22         32 min  18 pg  │
│                                │
│  Total: 2h 29m  |  79 pages   │
│  Avg speed: 32 pages/hour     │
│  Est. remaining: 6h 40m       │
│                                │
│  [View All Sessions]           │
└────────────────────────────────┘
```

## Data Model Changes

### New Model: ReadingSession

```swift
@Model final class ReadingSession {
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval     // Seconds (excludes paused time)
    var pagesRead: Int?
    var startPage: Int?            // Page when session started
    var endPage: Int?              // Page when session ended

    @Relationship(inverse: \Book.readingSessions)
    var book: Book?

    init(book: Book?) {
        self.startTime = Date()
        self.duration = 0
        self.book = book
    }

    var pagesPerHour: Double? {
        guard let pages = pagesRead, duration > 0 else { return nil }
        return Double(pages) / (duration / 3600)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
}
```

### Book.swift — Add Relationship

```swift
@Model final class Book {
    // ... existing properties ...

    @Relationship
    var readingSessions: [ReadingSession] = []
}
```

### Computed Properties on Book

```swift
extension Book {
    var totalReadingTime: TimeInterval {
        readingSessions.reduce(0) { $0 + $1.duration }
    }

    var averagePagesPerHour: Double? {
        let sessions = readingSessions.filter { $0.pagesRead != nil && $0.duration > 0 }
        guard !sessions.isEmpty else { return nil }
        let totalPages = sessions.compactMap(\.pagesRead).reduce(0, +)
        let totalTime = sessions.reduce(0) { $0 + $1.duration }
        return Double(totalPages) / (totalTime / 3600)
    }

    var estimatedTimeRemaining: TimeInterval? {
        guard let speed = averagePagesPerHour,
              let total = pageCount,
              let current = currentPage,
              speed > 0 else { return nil }
        let remaining = total - current
        return Double(remaining) / speed * 3600
    }
}
```

### Migration Considerations

- New model `ReadingSession` — no migration needed
- New optional relationship on `Book` — safe to add
- Register `ReadingSession.self` in SwiftData schema

## Architecture Changes

### New Files

| File | Purpose |
|------|---------|
| `Models/ReadingSession.swift` | Session model (start, end, duration, pages) |
| `Views/Timer/ReadingTimerView.swift` | Full timer display with controls |
| `Views/Timer/TimerMiniPlayerView.swift` | Persistent bottom bar during active timer |
| `Views/Timer/EndSessionView.swift` | Pages read input after session ends |
| `Views/Timer/SessionHistoryView.swift` | List of past sessions for a book |
| `ViewModels/TimerViewModel.swift` | Timer state management, background handling |

### Modified Files

| File | Change |
|------|--------|
| `Models/Book.swift` | Add `readingSessions` relationship, computed properties |
| `BookShelfApp.swift` | Register `ReadingSession.self` in schema |
| `Views/BookDetailView.swift` | Add "Start Reading" button, session history section |
| `Views/ContentView.swift` | Add TimerMiniPlayerView overlay |

### TimerViewModel — Core Timer Logic

```swift
@MainActor
@Observable
class TimerViewModel {
    enum TimerState {
        case idle
        case running
        case paused
        case ended
    }

    var state: TimerState = .idle
    var elapsedTime: TimeInterval = 0
    var currentBook: Book?
    var currentSession: ReadingSession?

    private var timer: Timer?
    private var pausedDuration: TimeInterval = 0
    private var lastResumeTime: Date?

    func startSession(for book: Book) { ... }
    func pauseSession() { ... }
    func resumeSession() { ... }
    func endSession() { ... }
    func saveSession(pagesRead: Int?) { ... }
}
```

## Background Timer Handling

### iOS Background Execution

iOS suspends apps in the background. The timer needs to handle this:

1. **Record wall-clock times** — Don't rely on `Timer` firing in background
2. **On pause/background**: Save `lastResumeTime` to compute elapsed time
3. **On resume/foreground**: Calculate time difference from `lastResumeTime`
4. **Use `scenePhase`**: Detect app going to background/foreground

```swift
.onChange(of: scenePhase) { _, newPhase in
    switch newPhase {
    case .active:
        timerViewModel.handleForeground()
    case .background:
        timerViewModel.handleBackground()
    default:
        break
    }
}
```

### Local Notifications

When timer is running and app goes to background:
- Schedule a local notification after a configurable duration
- "You've been reading for 1 hour! Keep going or end your session?"
- Tapping notification opens the app to the timer view

### Live Activity (iOS 16.1+ — Future Enhancement)

Show timer on lock screen and Dynamic Island:
- Elapsed time
- Book title
- Pause/resume controls

## Implementation Steps

1. **Create ReadingSession model**
   - startTime, endTime, duration, pagesRead, startPage, endPage
   - Relationship to Book
   - Computed properties (pagesPerHour, formattedDuration)
   - Register in SwiftData schema

2. **Add relationship to Book**
   - `readingSessions: [ReadingSession]`
   - Computed: totalReadingTime, averagePagesPerHour, estimatedTimeRemaining

3. **Create TimerViewModel**
   - Timer state machine (idle → running → paused → ended)
   - Start/pause/resume/end methods
   - Elapsed time tracking using wall-clock times (not Timer ticks)
   - Background/foreground handling
   - Save session to SwiftData

4. **Create ReadingTimerView**
   - Large elapsed time display (hours:minutes:seconds)
   - Book cover and title
   - Start/pause/resume buttons
   - End session button
   - Clean, focused UI (minimal distractions)

5. **Create TimerMiniPlayerView**
   - Compact bar (50pt height)
   - Book title, elapsed time, pause/play button, stop button
   - Tap to expand full timer view
   - Position above tab bar in ContentView

6. **Create EndSessionView**
   - Pages read input (number pad)
   - Auto-calculate speed
   - Show session duration summary
   - "Save" button
   - Option to update reading progress (Feature 02)

7. **Create SessionHistoryView**
   - List of sessions for a book
   - Date, duration, pages read per session
   - Total stats at top
   - Estimated time remaining (if page count known)

8. **Update BookDetailView**
   - Add "Start Reading Session" button (for Currently Reading books)
   - Add session history summary section
   - Show total reading time and average speed

9. **Update ContentView**
   - Add TimerMiniPlayerView as overlay
   - Conditionally shown when timer is active
   - Shared TimerViewModel across app

10. **Handle background transitions**
    - Save timer state on `scenePhase` changes
    - Restore timer on foreground return
    - Optional: local notification for long sessions

## Testing Strategy

- Test start/pause/resume/end cycle
- Test elapsed time accuracy over extended periods
- Test background/foreground transitions
- Test pages per hour calculation
- Test estimated time remaining calculation
- Test mini-player appears when timer is running
- Test mini-player disappears when session ends
- Test session persistence in SwiftData
- Test session history display
- Test with multiple books (only one timer at a time)
- Test edge cases: 0 pages read, very long sessions, rapid start/stop

## Dependencies

- **Enhanced by Feature 01** (Currently Reading) — timer only shows for currently reading books
- **Enhanced by Feature 02** (Reading Progress) — end session can auto-update current page
- **Enhanced by Feature 03** (Date Tracking) — session dates contribute to reading activity data
- **Feeds into Feature 04** (Stats Dashboard) — reading time stats, speed analytics

## Future Enhancements

- Live Activity on lock screen and Dynamic Island
- Daily/weekly reading time goals
- Reading streaks (consecutive days with sessions)
- Automatic page estimation (if speed is known, auto-suggest pages after session)
- Focus mode integration (silence notifications while reading)
- Pomodoro-style reading sessions (25 min read, 5 min break)
- Session notes/journaling after reading (Basmo-style)
- Background audio ambiance (rain sounds, library sounds)
- Apple Health integration (mindful minutes)
- Reading speed comparison across books/genres
- Social sharing of reading streaks
