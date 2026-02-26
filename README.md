# BookShelf

> **Prototype** — This is a personal prototype built to experiment with iOS Vision framework capabilities and to keep track of books I want to read.

An iOS reading tracker that lets you scan book covers and barcodes to build a personal reading list, then helps you build a consistent reading habit with timers, streaks, goals, and insights. Point your camera at a book, and BookShelf uses Apple's Vision and VisionKit frameworks to recognize the ISBN barcode or extract text via OCR, then fetches book details automatically.

## Features

### Core
- **Onboarding** — Four-screen onboarding flow introducing scanning, searching, tracking, and stats/goals on first launch
- **Barcode & Cover Scanning** — Scan ISBN barcodes or use OCR to recognize text on book covers via Apple's Vision framework and `DataScannerViewController`
- **Smart Book Search** — Multi-strategy search that queries Google Books API with precise operators, falls back to Open Library, and ranks results by relevance
- **Reading List** — Track books as "Want to Read", "Currently Reading", "Read", "Paused", or "Did Not Finish" with on-device persistence via SwiftData
- **Star Ratings** — Rate books you've read on a 1–5 star scale
- **Quick Links** — Jump directly to Amazon or Audible to purchase a book
- **Image Caching** — Two-tier caching system (in-memory + disk) for cover images

### Tab-Based Navigation
- **Reading Tab** — Currently Reading dashboard as the primary view with book cards, progress rings, and quick actions
- **Library Tab** — Full bookshelf grid organized by status (Reading, Want to Read, Read, Paused, Did Not Finish)
- **Stats Tab** — Reading statistics, goals, challenges, and reminders

### Reading Timer
- **Timed Reading Sessions** — Start a wall-clock-based timer for any currently reading book
- **Pause/Resume** — Timer state machine (idle → running → paused → running → ended) with accurate wall-clock elapsed time
- **End Session Flow** — Record ending page, see pages read and reading speed, save session to history
- **Mini Player** — Compact timer bar above tab bar that persists across tabs; tap to open full timer
- **Background Handling** — Timer continues accurately when app enters background via wall-clock approach

### Currently Reading Dashboard
- **Daily Goal Banner** — Progress bar showing daily page goal progress
- **Streak Badge** — Flame icon with day count and milestone celebrations (7, 30, 100, 365 days)
- **Quote of the Day** — Random saved quote displayed on the dashboard
- **Currently Reading Cards** — Cover with progress ring, title, page info, "Read" (timer) and "Update" buttons, estimated completion
- **Paused Books Section** — Collapsible section with resume buttons
- **Weekly Activity Chart** — Bar chart showing pages per day for the last 7 days
- **Weekly Summary** — Pages, finished books, and books in progress this week
- **Reading Insights** — Pace predictions, personal bests, preferred reading time, estimated completion dates

### Enhanced Streaks
- **Grace Period** — Between midnight and 2 AM counts as the previous day for streak calculation
- **Streak Freeze** — One freeze per calendar week to protect your streak on missed days
- **Milestone Celebrations** — Special messages at 7, 30, 100, and 365-day milestones
- **Ethical Messaging** — On streak loss: "You read X days in a row - amazing! Start a new streak today."

### Reading Progress
- Track current page with a circular progress ring, quick-increment buttons with haptics, reading session history, pace tracking (~pages/day), and estimated completion

### Notes & Quotes
- **Quote Scanner** — Capture quotes from book pages using camera OCR (captures all text, not just titles)
- **Quote Editor** — Edit scanned text, set page number, save as quote
- **Note Input** — Add personal notes and thoughts per book
- **Book Detail Integration** — View and manage notes/quotes per book with context menu deletion

### Stats & Goals
- **Lifetime Stats** — Books read, total pages, average rating, average pace, average days per book
- **Current & Longest Streaks** — With streak freeze support
- **Time-Based Summaries** — This week, this month, this year
- **Reading Goals** — Set daily and weekly page goals with progress bars
- **Annual Reading Challenge** — Yearly book count goal with progress bar, ahead/behind indicator, and finished book covers
- **Reading Insights** — Estimated completion dates, pages per hour, preferred reading time, best reading week

### Book Statuses
- **Paused** — Keep progress and start date, resume anytime
- **Did Not Finish** — Record DNF with optional reason, keep progress for history
- DNF books are excluded from the annual reading challenge count

### Other
- **Reminders** — Daily reading reminders at a custom time, plus streak protection notifications at 9 PM when your streak is at risk
- **Book Details** — Tabbed detail view with pinned header (cover, title, status badge), an "Activity" tab showing status-contextual actions (timer, progress tracking, ratings, purchase links, notes/quotes), and an "About" tab with description and metadata
- **Startup Performance** — Loading state prevents empty-state flash, async off-main-thread cover image decoding for smooth scrolling, and deduplicated database fetches on launch
- **SwiftUI Previews** — Named preview variants with sample data for every view

## Tech Stack

- **SwiftUI** — Declarative UI
- **SwiftData** — On-device persistence
- **UserNotifications** — Local push notifications for reading reminders
- **Vision / VisionKit** — Barcode detection and OCR (book covers + quote scanning)
- **Google Books API** — Primary book metadata source
- **Open Library API** — Fallback metadata source

## Requirements

- iOS 17.0+
- Xcode 15.0+

## Getting Started

1. Clone the repository
2. Open `BookShelf.xcodeproj` in Xcode
3. Build and run on a simulator or device (camera features require a physical device)

## Project Structure

```
BookShelf/
├── Models/
│   ├── Book.swift               # SwiftData model + ReadStatus enum (5 statuses)
│   ├── ReadingProgressEntry.swift # Reading progress history model
│   ├── ReadingGoal.swift        # Daily/weekly page + minute goal model
│   ├── ReadingChallenge.swift   # Annual reading challenge model
│   ├── ReadingSession.swift     # Timed reading session model
│   ├── BookNote.swift           # Quotes and notes model
│   └── StreakFreeze.swift       # Streak freeze tracking model
├── Views/
│   ├── ContentView.swift        # Root view with onboarding + scene phase handling
│   ├── MainTabView.swift        # Tab container (Reading, Library, Stats)
│   ├── CurrentlyReadingView.swift # Reading dashboard (hero view)
│   ├── OnboardingView.swift     # First-launch onboarding flow
│   ├── BookshelfView.swift      # Library grid with all status sections
│   ├── AddBookView.swift        # Combined search & scan sheet
│   ├── BookDetailView.swift     # Book details, actions, notes/quotes
│   ├── BookCoverView.swift      # Async off-main-thread cover image decoding
│   ├── StatsSummaryCard.swift   # Compact stats card on bookshelf
│   ├── StatsView.swift          # Full stats tab: streaks, goals, reminders
│   ├── GoalSettingView.swift    # Daily/weekly goal setting sheet
│   ├── ChallengeSetupView.swift # Annual reading challenge setup sheet
│   ├── StarRatingView.swift     # Interactive 1-5 star rating
│   ├── CircularProgressRing.swift # Animated circular progress ring
│   ├── ReadingProgressBar.swift # Thin progress bar for grid items
│   ├── ProgressUpdateView.swift # Sheet for updating reading progress
│   ├── ScannerView.swift        # Barcode scanner, camera, OCR processing
│   ├── Timer/
│   │   ├── ReadingTimerView.swift    # Full-screen reading timer
│   │   ├── EndSessionView.swift      # Post-session summary + save
│   │   └── TimerMiniPlayerView.swift # Compact timer bar above tab bar
│   ├── Reading/
│   │   ├── CurrentlyReadingCard.swift  # Book card with progress ring + actions
│   │   ├── DailyGoalBanner.swift       # Daily goal progress banner
│   │   ├── StreakBadge.swift           # Streak display with milestones
│   │   ├── WeeklyActivityChart.swift   # 7-day bar chart
│   │   ├── WeeklySummaryCard.swift     # Weekly stats summary
│   │   ├── ReadingInsightsCard.swift   # Pace predictions + personal bests
│   │   └── QuoteOfTheDayCard.swift     # Random saved quote card
│   └── Quotes/
│       ├── QuoteScannerView.swift # Camera quote capture with OCR
│       ├── QuoteEditView.swift    # Edit scanned quote text
│       └── NoteInputView.swift    # Note/quote text entry
├── ViewModels/
│   ├── BookshelfViewModel.swift      # Observable view model + all business logic
│   └── ReadingTimerViewModel.swift   # Timer state machine
└── Services/
    ├── GoogleBooksService.swift  # Google Books API client
    ├── BookAPIService.swift      # Search orchestration & Open Library fallback
    ├── ImageCacheService.swift   # Memory + disk image cache
    └── NotificationService.swift # Daily + streak reminder scheduling
```

## Previews

Every view includes named `#Preview` variants with sample data, wrapped in `#if DEBUG`. Sample books and search results are defined as static properties on `Book` and `BookSearchResult` in `Book.swift`. An in-memory `ModelContainer` (`Book.previewContainer`) is provided for views that depend on SwiftData.

| View | Previews |
|------|----------|
| OnboardingView | Onboarding Flow, Welcome Page, Add Books Page, Track Reading Page, Stats & Goals Page |
| ContentView | With Books, Empty |
| MainTabView | Main Tab View |
| CurrentlyReadingView | Currently Reading, Empty |
| BookshelfView | Populated, Empty, Grid Item variants |
| BookDetailView | Want to Read, Currently Reading, Read (rated/unrated), DetailSection, DetailRow |
| BookCoverView | With Cover Data, Placeholder (Grid), Placeholder (Detail) |
| StarRatingView | 5 Stars, 3 Stars, No Rating, Interactive |
| CircularProgressRing | 0%, 38%, 75%, 100%, Compact |
| ReadingProgressBar | 0%, 38%, 75%, 100% |
| ProgressUpdateView | With Page Count, Without Page Count |
| AddBookView | Empty, Search Result Row, Search Result Row (in shelf) |
| StatsSummaryCard | Stats Summary Card |
| StatsView | Stats View |
| GoalSettingView | Goal Setting |
| ChallengeSetupView | Challenge Setup |
| ReadingTimerView | Reading Timer |
| EndSessionView | End Session |
| TimerMiniPlayerView | Mini Player |
| CurrentlyReadingCard | Currently Reading Card |
| DailyGoalBanner | Daily Goal Banner |
| StreakBadge | Streak Badge |
| WeeklyActivityChart | Weekly Activity |
| WeeklySummaryCard | Weekly Summary |
| ReadingInsightsCard | Reading Insights |
| QuoteOfTheDayCard | Quote Card |
| QuoteEditView | Quote Edit |
| NoteInputView | Note Input |

## License

MIT
