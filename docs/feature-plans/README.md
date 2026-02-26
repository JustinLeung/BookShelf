# BookShelf — Feature Implementation Plans

## Overview

This directory contains detailed implementation plans for 10 high-priority features, based on extensive competitive research of Goodreads, Fable, StoryGraph, Bookly, Book Buddy, Basmo, Literal, Libib, Hardcover, and Oku.

Each plan includes: competitive analysis, UI/UX design with ASCII mockups, data model changes, architecture impact, step-by-step implementation, migration considerations, testing strategy, and future enhancements.

## Feature List

| # | Feature | Effort | Impact | Status |
|---|---------|--------|--------|--------|
| 01 | [Currently Reading Status](01-currently-reading-status.md) | Low | High | Done |
| 02 | [Reading Progress Tracking](02-reading-progress-tracking.md) | Medium | High | Done |
| 03 | [Date Tracking (Start/Finish)](03-date-tracking.md) | Low | High | Done |
| 04 | [Reading Stats Dashboard](04-reading-stats-dashboard.md) | Medium | High | Planned |
| 05 | [Annual Reading Challenge](05-annual-reading-challenge.md) | Medium | High | Planned |
| 06 | [Home Screen Widgets](06-home-screen-widgets.md) | High | High | Planned |
| 07 | [Goodreads CSV Import](07-goodreads-csv-import.md) | Medium | High | Planned |
| 08 | [Custom Shelves / Collections](08-custom-shelves-collections.md) | Medium | Medium | Planned |
| 09 | [Quote Scanner (OCR)](09-quote-scanner-ocr.md) | Medium | Medium | Planned |
| 10 | [Reading Timer](10-reading-timer.md) | High | High | Planned |

## Dependency Graph

```
Feature 01: Currently Reading Status
    └──► Feature 02: Reading Progress Tracking
    └──► Feature 10: Reading Timer

Feature 03: Date Tracking
    └──► Feature 04: Reading Stats Dashboard
    └──► Feature 05: Annual Reading Challenge

Feature 06: Home Screen Widgets
    ◄── Enhanced by Features 01, 02, 05

Feature 07: Goodreads CSV Import (independent)

Feature 08: Custom Shelves (independent)

Feature 09: Quote Scanner (independent)
```

## Recommended Implementation Order

### Phase 1 — Foundation (Weeks 1-2)
Build the data foundation that all analytics features depend on.

1. **Feature 01: Currently Reading Status** — Quick win, universally expected
2. **Feature 03: Date Tracking** — Quick win, enables stats

### Phase 2 — Core Tracking (Weeks 3-5)
Transform BookShelf from a static list into an active reading tracker.

3. **Feature 02: Reading Progress Tracking** — Depends on Feature 01
4. **Feature 07: Goodreads CSV Import** — Independent, critical for user acquisition

### Phase 3 — Analytics & Engagement (Weeks 6-8)
Use collected data to provide insights and drive engagement.

5. **Feature 04: Reading Stats Dashboard** — Best after dates/progress are tracked
6. **Feature 05: Annual Reading Challenge** — Proven engagement driver

### Phase 4 — Differentiation (Weeks 9-12)
Features that set BookShelf apart from competitors.

7. **Feature 08: Custom Shelves** — Independent, improves organization
8. **Feature 09: Quote Scanner** — Leverages existing OCR, unique differentiator
9. **Feature 10: Reading Timer** — Most complex, benefits from all prior features
10. **Feature 06: Home Screen Widgets** — Best saved for last (showcases all features)

## Data Model Summary

### New Properties on Book

```swift
// Feature 01
// ReadStatus enum: add .currentlyReading case

// Feature 02
var currentPage: Int?
var progressPercentage: Double?

// Feature 03
var dateStarted: Date?
var dateFinished: Date?

// Feature 08
@Relationship var collections: [BookCollection] = []

// Feature 09
@Relationship var quotes: [BookQuote] = []

// Feature 10
@Relationship var readingSessions: [ReadingSession] = []
```

### New Models

```
Feature 02: ReadingProgressEntry (bookISBN, page, percentage, timestamp)
Feature 05: ReadingChallenge (year, goalCount, dateCreated)
Feature 08: BookCollection (name, icon, dateCreated, sortOrder, books[])
Feature 09: BookQuote (text, pageNumber, dateCreated, sourceImageData, book)
Feature 10: ReadingSession (startTime, endTime, duration, pagesRead, book)
```

### SwiftData Schema Registration

All new models must be registered in `BookShelfApp.swift`:
```swift
let schema = Schema([
    Book.self,
    ReadingProgressEntry.self,  // Feature 02
    ReadingChallenge.self,      // Feature 05
    BookCollection.self,        // Feature 08
    BookQuote.self,             // Feature 09
    ReadingSession.self,        // Feature 10
])
```

## Architecture Impact

### New Tabs
- **Stats Tab** (Feature 04) — 4th tab with chart.bar.fill icon

### New Targets
- **Widget Extension** (Feature 06) — Separate target for WidgetKit

### New ViewModels
- `StatsViewModel` (Feature 04)
- `TimerViewModel` (Feature 10)

### Estimated New Files: ~30
### Estimated Modified Files: ~8

## Competitive Positioning

After implementing all 10 features, BookShelf would offer:

| Capability | Goodreads | StoryGraph | Bookly | Book Buddy | BookShelf |
|-----------|-----------|------------|--------|------------|-----------|
| Barcode scanning | Yes | No | Yes | Yes | **Yes** |
| Cover OCR scanning | No | No | No | No | **Yes (unique)** |
| Quote OCR scanning | No | No | No | No | **Yes (unique)** |
| Currently Reading | Yes | Yes | Yes | Yes | **Yes** |
| Reading progress | Yes | Yes | Yes | No | **Yes** |
| Date tracking | Yes | Yes | Timer | Yes | **Yes** |
| Stats dashboard | Basic | Best | Good | Basic | **Yes** |
| Reading challenge | Yes | Yes | Yes | No | **Yes** |
| Home screen widgets | Basic | No | Yes | Yes | **Yes** |
| Goodreads import | N/A | Yes | No | Yes | **Yes** |
| Custom collections | Yes | Yes | No | Yes | **Yes** |
| Reading timer | No | No | Yes | No | **Yes** |
| Free (no subscription) | Yes | Freemium | Paid | Paid | **Yes** |
| iOS native | No (web) | No (web) | Yes | Yes | **Yes** |

### BookShelf's Unique Value Proposition
- **Only app** with barcode scanning + cover OCR + quote OCR + reading timer + stats — all in one free iOS-native app
- Best-in-class scanning (3 methods: barcode, cover photo, manual)
- Native iOS experience with widgets, Siri, Spotlight
- No subscription required
- Privacy-focused (local data, no account required)
