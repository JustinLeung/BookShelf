# BookShelf Wiki

BookShelf is an iOS app that lets you scan book covers and barcodes to build a personal reading list. It uses Apple's Vision framework for OCR, Google Books and Open Library APIs for metadata, and SwiftData for on-device persistence.

## Pages

- [[Architecture]] — MVVM structure, actors, data flow
- [[Project Structure]] — Directory layout and file guide
- [[Models]] — Book, ReadStatus, BookSearchResult
- [[Views]] — UI components and navigation
- [[Services]] — API clients, search orchestration, image caching
- [[Scanning & OCR]] — Barcode detection and cover text recognition
- [[Build System]] — XcodeGen, SwiftLint, CI/CD
- [[Testing]] — Swift Testing setup and test suites

## Quick Facts

| | |
|---|---|
| **Platform** | iOS 17+ |
| **Language** | Swift 5 |
| **UI** | SwiftUI |
| **Persistence** | SwiftData |
| **Dependencies** | None (Apple frameworks only) |
| **Build Tool** | XcodeGen |
| **CI** | GitHub Actions |
| **Tests** | Swift Testing |
