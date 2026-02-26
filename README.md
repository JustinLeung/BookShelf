# BookShelf

> **Prototype** — This is a personal prototype built to experiment with iOS Vision framework capabilities and to keep track of books I want to read.

An iOS app that lets you scan book covers and barcodes to build a personal reading list. Point your camera at a book, and BookShelf uses Apple's Vision and VisionKit frameworks to recognize the ISBN barcode or extract text via OCR, then fetches book details automatically.

## Features

- **Onboarding** — Four-screen onboarding flow introducing scanning, searching, tracking, and stats/goals on first launch
- **Barcode & Cover Scanning** — Scan ISBN barcodes or use OCR to recognize text on book covers via Apple's Vision framework and `DataScannerViewController`
- **Smart Book Search** — Multi-strategy search that queries Google Books API with precise operators, falls back to Open Library, and ranks results by relevance
- **Reading List** — Track books as "Want to Read", "Currently Reading", or "Read" with on-device persistence via SwiftData
- **Star Ratings** — Rate books you've read on a 1–5 star scale
- **Reading Progress** — Track current page with a circular progress ring, quick-increment buttons with haptics, reading session history, pace tracking (~pages/day), and estimated completion
- **Reading Stats & Streaks** — Lifetime stats (books, pages, average rating, pace), current and longest reading streaks, time-based summaries (this week/month/year), and a compact stats summary card on the bookshelf
- **Reading Goals** — Set daily and weekly page goals with progress bars that update as you log reading sessions
- **Annual Reading Challenge** — Set a yearly book count goal with progress bar, ahead/behind schedule indicator, and finished book covers for the year
- **Reminders** — Daily reading reminders at a custom time, plus streak protection notifications at 9 PM when your streak is at risk
- **Book Details** — Tabbed detail view with pinned header (cover, title, status badge), an "Activity" tab showing status-contextual actions (progress tracking, ratings, purchase links), and an "About" tab with description and metadata
- **Quick Links** — Jump directly to Amazon or Audible to purchase a book
- **Image Caching** — Two-tier caching system (in-memory + disk) for cover images
- **Startup Performance** — Loading state prevents empty-state flash, async off-main-thread cover image decoding for smooth scrolling, and deduplicated database fetches on launch
- **SwiftUI Previews** — Named preview variants with sample data for every view, covering populated/empty states, read statuses, ratings, and reusable components

## Tech Stack

- **SwiftUI** — Declarative UI
- **SwiftData** — On-device persistence
- **UserNotifications** — Local push notifications for reading reminders
- **Vision / VisionKit** — Barcode detection and OCR
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
│   ├── Book.swift               # SwiftData model
│   ├── ReadingProgressEntry.swift # Reading session history model
│   ├── ReadingGoal.swift        # Daily/weekly page goal model
│   └── ReadingChallenge.swift  # Annual reading challenge model
├── Views/
│   ├── ContentView.swift        # Root view with onboarding + streak reminder
│   ├── OnboardingView.swift     # First-launch onboarding flow
│   ├── BookshelfView.swift      # Main library grid with FAB + stats
│   ├── AddBookView.swift        # Combined search & scan sheet
│   ├── BookDetailView.swift     # Book details & status toggle
│   ├── BookCoverView.swift      # Async off-main-thread cover image decoding
│   ├── StatsSummaryCard.swift   # Compact stats card on bookshelf
│   ├── StatsView.swift          # Full stats: streaks, goals, reminders
│   ├── GoalSettingView.swift    # Daily/weekly goal setting sheet
│   ├── ChallengeSetupView.swift # Annual reading challenge setup sheet
│   ├── StarRatingView.swift     # Interactive 1-5 star rating
│   ├── CircularProgressRing.swift # Animated circular progress ring
│   ├── ReadingProgressBar.swift # Thin progress bar for grid items
│   ├── ProgressUpdateView.swift # Sheet for updating reading progress
│   └── ScannerView.swift        # Barcode scanner, camera, OCR processing
├── ViewModels/
│   └── BookshelfViewModel.swift # Observable view model + stats/goal methods
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

## License

MIT
