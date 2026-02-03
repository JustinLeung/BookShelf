# BookShelf

An iOS app to catalog and track your personal book collection.

## Features

- **Barcode Scanner** - Scan book ISBNs with your camera to quickly add books
- **Manual Search** - Search for books by title or author
- **Book Details** - View cover art, author, publisher, page count, and description
- **Reading Status** - Track books as "Want to Read" or "Read"
- **Quick Links** - Jump to Amazon or Audible to purchase books

## Requirements

- iOS 17.0+
- Xcode 15.0+

## Tech Stack

- SwiftUI
- SwiftData
- Google Books API

## Getting Started

1. Clone the repository
2. Open `BookShelf.xcodeproj` in Xcode
3. Build and run on a simulator or device

## Project Structure

```
BookShelf/
├── Models/
│   └── Book.swift          # Book data model with SwiftData
├── Views/
│   ├── BookshelfView.swift # Main library view
│   ├── BookDetailView.swift
│   ├── ScannerView.swift   # Barcode scanning
│   └── ManualSearchView.swift
├── ViewModels/
│   └── BookshelfViewModel.swift
└── Services/
    ├── GoogleBooksService.swift
    └── ImageCacheService.swift
```

## License

MIT
