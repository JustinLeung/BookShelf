# BookShelf

> **Prototype** — This is a personal prototype built to experiment with iOS Vision framework capabilities and to keep track of books I want to read.

An iOS app that lets you scan book covers and barcodes to build a personal reading list. Point your camera at a book, and BookShelf uses Apple's Vision and VisionKit frameworks to recognize the ISBN barcode or extract text via OCR, then fetches book details automatically.

## Features

- **Barcode & Cover Scanning** — Scan ISBN barcodes or use OCR to recognize text on book covers via Apple's Vision framework and `DataScannerViewController`
- **Smart Book Search** — Multi-strategy search that queries Google Books API with precise operators, falls back to Open Library, and ranks results by relevance
- **Reading List** — Track books as "Want to Read", "Currently Reading", or "Read" with on-device persistence via SwiftData
- **Star Ratings** — Rate books you've read on a 1–5 star scale
- **Reading Progress** — Automatically tracks start and finish dates, calculates days to read
- **Book Details** — View cover art, author, publisher, page count, and description
- **Quick Links** — Jump directly to Amazon or Audible to purchase a book
- **Image Caching** — Two-tier caching system (in-memory + disk) for cover images
- **SwiftUI Previews** — Named preview variants with sample data for every view, covering populated/empty states, read statuses, ratings, and reusable components

## Tech Stack

- **SwiftUI** — Declarative UI
- **SwiftData** — On-device persistence
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
│   └── Book.swift               # SwiftData model
├── Views/
│   ├── ContentView.swift        # Tab navigation
│   ├── BookshelfView.swift      # Main library grid
│   ├── BookDetailView.swift     # Book details & status toggle
│   ├── StarRatingView.swift     # Interactive 1-5 star rating
│   ├── ScannerView.swift        # Barcode & OCR scanning
│   └── ManualSearchView.swift   # Search by ISBN or title
├── ViewModels/
│   └── BookshelfViewModel.swift # Observable view model
└── Services/
    ├── GoogleBooksService.swift  # Google Books API client
    ├── BookAPIService.swift      # Search orchestration & Open Library fallback
    └── ImageCacheService.swift   # Memory + disk image cache
```

## Previews

Every view includes named `#Preview` variants with sample data, wrapped in `#if DEBUG`. Sample books and search results are defined as static properties on `Book` and `BookSearchResult` in `Book.swift`. An in-memory `ModelContainer` (`Book.previewContainer`) is provided for views that depend on SwiftData.

| View | Previews |
|------|----------|
| ContentView | With Books, Empty |
| BookshelfView | Populated, Empty, Grid Item variants |
| BookDetailView | Want to Read, Currently Reading, Read (rated/unrated), DetailSection, DetailRow |
| StarRatingView | 5 Stars, 3 Stars, No Rating, Interactive |
| ManualSearchView | Empty, Search Result Row, Search Result Row (in shelf) |
| ScannerView | Scanner landing page |

## License

MIT
