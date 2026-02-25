# BookShelf

> **Prototype** — This is a personal prototype built to experiment with iOS Vision framework capabilities and to keep track of books I want to read.

An iOS app that lets you scan book covers and barcodes to build a personal reading list. Point your camera at a book, and BookShelf uses Apple's Vision and VisionKit frameworks to recognize the ISBN barcode or extract text via OCR, then fetches book details automatically.

## Features

- **Barcode & Cover Scanning** — Scan ISBN barcodes or use OCR to recognize text on book covers via Apple's Vision framework and `DataScannerViewController`
- **Smart Book Search** — Multi-strategy search that queries Google Books API with precise operators, falls back to Open Library, and ranks results by relevance
- **Reading List** — Track books as "Want to Read" or "Read" with on-device persistence via SwiftData
- **Book Details** — View cover art, author, publisher, page count, and description
- **Quick Links** — Jump directly to Amazon or Audible to purchase a book
- **Image Caching** — Two-tier caching system (in-memory + disk) for cover images

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
│   ├── ScannerView.swift        # Barcode & OCR scanning
│   └── ManualSearchView.swift   # Search by ISBN or title
├── ViewModels/
│   └── BookshelfViewModel.swift # Observable view model
└── Services/
    ├── GoogleBooksService.swift  # Google Books API client
    ├── BookAPIService.swift      # Search orchestration & Open Library fallback
    └── ImageCacheService.swift   # Memory + disk image cache
```

## License

MIT
