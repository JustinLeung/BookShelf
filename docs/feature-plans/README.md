# BookShelf — Feature Implementation Plans

## Overview

This directory contains detailed implementation plans for planned features, based on competitive research of Goodreads, Fable, StoryGraph, Bookly, Book Buddy, Basmo, Literal, Libib, Hardcover, and Oku.

Each plan includes: competitive analysis, UI/UX design with ASCII mockups, data model changes, architecture impact, step-by-step implementation, migration considerations, testing strategy, and future enhancements.

## Feature List

| # | Feature | Effort | Impact |
|---|---------|--------|--------|
| 01 | [Home Screen Widgets](01-home-screen-widgets.md) | High | High |
| 02 | [Goodreads CSV Import](02-goodreads-csv-import.md) | Medium | High |
| 03 | [Custom Shelves / Collections](03-custom-shelves-collections.md) | Medium | Medium |
| 04 | [Quote Scanner (OCR)](04-quote-scanner-ocr.md) | Medium | Medium |
| 05 | [Reading Timer](05-reading-timer.md) | High | High |
| 06 | [Affiliate Links](06-affiliate-links.md) | Low | Low |

## Already Implemented

The following features have been completed and their plan documents removed:

- Currently Reading Status
- Reading Progress Tracking
- Date Tracking (Start/Finish)
- Reading Stats Dashboard
- Annual Reading Challenge

## Dependency Graph

```
Feature 01: Home Screen Widgets
    ◄── Enhanced by existing progress, challenge features

Feature 02: Goodreads CSV Import (independent)

Feature 03: Custom Shelves (independent)

Feature 04: Quote Scanner (independent)

Feature 05: Reading Timer
    ◄── Builds on existing progress tracking

Feature 06: Affiliate Links (independent)
```

## Recommended Implementation Order

### Phase 1 — High Impact
1. **Feature 02: Goodreads CSV Import** — Independent, critical for user acquisition
2. **Feature 03: Custom Shelves** — Independent, improves organization

### Phase 2 — Differentiation
3. **Feature 04: Quote Scanner** — Leverages existing OCR, unique differentiator
4. **Feature 05: Reading Timer** — Benefits from existing progress tracking
5. **Feature 06: Affiliate Links** — Quick win, low effort

### Phase 3 — Polish
6. **Feature 01: Home Screen Widgets** — Best saved for last (showcases all features)

## Data Model Summary

### New Models

```
Feature 01: (Widget Extension — reads existing models via App Group)
Feature 03: BookCollection (name, icon, dateCreated, sortOrder, books[])
Feature 04: BookQuote (text, pageNumber, dateCreated, sourceImageData, book)
Feature 05: ReadingSession (startTime, endTime, duration, pagesRead, book)
```

### SwiftData Schema Registration

New models must be registered in `BookShelfApp.swift` as they are implemented.
