# Feature 09: Quote Scanner (OCR)

## Overview

Let users scan physical book pages to capture and save quotes using the camera and OCR. BookShelf already has the Vision framework integrated for cover OCR scanning — this feature extends that capability to a new use case. This is a natural differentiator that leverages existing technical investment and is inspired by Basmo's quote scanning feature.

## Competitive Analysis

| App | Quote Features |
|-----|---------------|
| Goodreads | Massive quote database (community-contributed), browse/search/share |
| Basmo | OCR quote scanning from physical pages, quote collections, sharing |
| Fable | Highlights from built-in e-reader (digital only) |
| StoryGraph | Manual quote entry in reading journal |
| Literal | Highlights and notes (digital) |
| **BookShelf (current)** | **None** |

### Basmo's Quote Scanner (Reference)
- Point camera at book page
- Select/crop text region
- OCR extracts text
- User can edit extracted text (fix OCR errors)
- Save quote to book
- Share as formatted image

### Our Advantage
BookShelf already has:
- `VNRecognizeTextRequest` implementation in ScannerView
- OCR error correction logic
- Camera capture UI (`CameraCaptureView`, `CameraModel`)
- Image processing pipeline

Reusing these components dramatically reduces implementation effort.

## Design Implications

### Entry Points

**From BookDetailView** — "Save a Quote" button or section:

```
┌─── Quotes (3) ────────────────┐
│                                │
│  "The only way to do great     │
│  work is to love what you do." │
│  — Page 42                     │
│                                │
│  "Stay hungry, stay foolish."  │
│  — Page 156                    │
│                                │
│  [📷 Scan Quote] [✏️ Add Quote]│
└────────────────────────────────┘
```

**From Scanner Tab** — Add a third scanning mode:

```
┌─────────────────────────────────┐
│  [Scan Barcode] [Photo Cover]   │
│        [📝 Scan Quote]          │ ← NEW
└─────────────────────────────────┘
```

### Quote Scanning Flow

**Step 1: Capture**

```
┌─────────────────────────────────┐
│                            [X]  │
│                                 │
│  ┌────────────────────────────┐ │
│  │                            │ │
│  │    Camera viewfinder       │ │
│  │                            │ │
│  │    Point at text you       │ │
│  │    want to capture         │ │
│  │                            │ │
│  └────────────────────────────┘ │
│                                 │
│  Tip: Hold steady and ensure    │
│  good lighting for best results │
│                                 │
│         [ 📷 Capture ]          │
└─────────────────────────────────┘
```

Reuse existing `CameraCaptureView` and `CameraModel`.

**Step 2: Text Selection & Editing**

After OCR processes the image, show extracted text for editing:

```
┌─────────────────────────────────┐
│  Edit Quote                [X]  │
│                                 │
│  ┌────────────────────────────┐ │
│  │  "The only way to do great │ │
│  │  work is to love what you  │ │
│  │  do. If you haven't found  │ │
│  │  it yet, keep looking.     │ │
│  │  Don't settle."            │ │
│  │                            │ │
│  │  (editable text view)      │ │
│  └────────────────────────────┘ │
│                                 │
│  Page Number (optional)         │
│  ┌────────┐                     │
│  │  42    │                     │
│  └────────┘                     │
│                                 │
│  Book: The Great Gatsby         │
│  (auto-selected or pick)   [▾]  │
│                                 │
│  [Retake Photo]  [Save Quote]   │
└─────────────────────────────────┘
```

- Text is editable (user can fix OCR errors)
- Optional page number field
- Book auto-selected if accessed from BookDetailView
- Book picker if accessed from Scanner tab

**Step 3: Saved Quote**

Quote appears in BookDetailView's quotes section and in a new "All Quotes" view.

### Quote Display in BookDetailView

```
┌─── Quotes ────────────────────┐
│                                │
│  "The only way to do great     │
│  work is to love what you do." │
│                  — p. 42       │
│                                │
│  ─────────────────────────     │
│                                │
│  "Stay hungry, stay foolish."  │
│                  — p. 156      │
│                                │
│  [See All (5)]                 │
│                                │
│  [📷 Scan Quote] [✏️ Type]     │
└────────────────────────────────┘
```

- Show 2-3 most recent quotes
- "See All" expands to full list
- Swipe-to-delete on individual quotes
- Tap to view/edit a quote

### Quote Sharing

Long-press or tap a quote to get share options:

```
┌─────────────────────────────────┐
│                                 │
│  "The only way to do great      │
│  work is to love what you do."  │
│                                 │
│  — Steve Jobs                   │
│  The Great Gatsby, p. 42        │
│                                 │
│  ┌──────────────────────────┐   │
│  │  bookshelf logo/watermark │   │
│  └──────────────────────────┘   │
│                                 │
│  [Copy Text] [Share Image]      │
│  [Share Text]                   │
└─────────────────────────────────┘
```

Generate a formatted image card for social sharing using SwiftUI's `ImageRenderer`.

## Data Model Changes

### New Model: BookQuote

```swift
@Model final class BookQuote {
    var text: String                    // The quote text
    var pageNumber: Int?                // Optional page reference
    var dateCreated: Date               // When the quote was saved
    var sourceImageData: Data?          // Original camera capture (optional)

    @Relationship(inverse: \Book.quotes)
    var book: Book?

    init(text: String, pageNumber: Int? = nil, book: Book? = nil) {
        self.text = text
        self.pageNumber = pageNumber
        self.dateCreated = Date()
        self.book = book
    }
}
```

### Book.swift — Add Relationship

```swift
@Model final class Book {
    // ... existing properties ...

    @Relationship
    var quotes: [BookQuote] = []
}
```

### Migration Considerations

- New model `BookQuote` — no migration needed
- New optional relationship on `Book` — safe to add (defaults to empty array)
- `sourceImageData` uses `@Attribute(.externalStorage)` for efficiency (like `coverImageData`)
- Register `BookQuote.self` in SwiftData schema

## Architecture Changes

### New Files

| File | Purpose |
|------|---------|
| `Models/BookQuote.swift` | Quote model with relationship to Book |
| `Views/Quotes/QuoteScannerView.swift` | Camera capture UI for quote scanning |
| `Views/Quotes/QuoteEditView.swift` | Edit extracted text, set page, select book |
| `Views/Quotes/QuoteListView.swift` | All quotes for a book or all books |
| `Views/Quotes/QuoteCardView.swift` | Individual quote display component |
| `Views/Quotes/QuoteShareView.swift` | Formatted quote card for sharing |
| `Services/QuoteOCRService.swift` | OCR processing optimized for text paragraphs |

### Modified Files

| File | Change |
|------|--------|
| `Models/Book.swift` | Add `quotes` relationship |
| `BookShelfApp.swift` | Register `BookQuote.self` in schema |
| `Views/BookDetailView.swift` | Add quotes section |
| `ViewModels/BookshelfViewModel.swift` | Add quote CRUD methods |

### Reusable Components from ScannerView

The following can be extracted and reused:
- `CameraCaptureView` → reuse directly for quote capture
- `CameraModel` → reuse directly
- `CameraPreviewView` → reuse directly
- `performOCR(on:)` → extract to shared service, adapt for paragraph text
- `correctOCRErrors(_:)` → reuse, expand corrections dictionary

## Implementation Steps

1. **Create BookQuote model**
   - text, pageNumber, dateCreated, sourceImageData
   - Relationship to Book
   - Register in SwiftData schema

2. **Add quotes relationship to Book**
   - `var quotes: [BookQuote] = []`

3. **Create QuoteOCRService**
   - Extract OCR logic from ScannerView into reusable service
   - Adapt for paragraph text (don't filter by text size like cover scanning does)
   - Use `.accurate` recognition level
   - Enable language correction
   - Keep all recognized text (not just large text like title extraction)
   - Apply error corrections

4. **Create QuoteScannerView**
   - Reuse `CameraCaptureView` for image capture
   - Pass captured image to QuoteOCRService
   - Display extracted text in QuoteEditView
   - Full-screen sheet presentation

5. **Create QuoteEditView**
   - TextEditor for the extracted/typed quote text
   - Page number text field (number pad)
   - Book selector (if not pre-selected)
   - "Retake" button to return to camera
   - "Save" button

6. **Create QuoteCardView**
   - Styled quote display with quotation marks
   - Page number reference
   - Book title / author attribution
   - Tap for actions (edit, share, delete)

7. **Create QuoteListView**
   - Full list of quotes for a book (or all quotes)
   - Sort by date added or page number
   - Swipe to delete
   - Empty state: "No quotes yet"

8. **Update BookDetailView**
   - Add quotes section after details
   - Show 2-3 most recent quotes
   - "See All" button for full list
   - "Scan Quote" and "Type Quote" buttons

9. **Create QuoteShareView**
   - Formatted card layout for sharing
   - Quote text in elegant typography
   - Book title and author attribution
   - Optional BookShelf branding
   - Use `ImageRenderer` to convert to shareable image
   - Share sheet integration (`ShareLink`)

10. **Add manual quote entry**
    - Simple text input alternative to scanning
    - For users who prefer typing or for ebook quotes

## Testing Strategy

- Test OCR accuracy on various book page photos
- Test with different lighting conditions
- Test text editing after OCR extraction
- Test saving quote with and without page number
- Test saving quote with and without book association
- Test quote list display and sorting
- Test quote deletion
- Test share image generation
- Test with long quotes (multi-paragraph)
- Test with short quotes (single line)
- Test OCR error correction on common mistakes
- Test camera permissions handling

## Dependencies

- Independent — leverages existing OCR infrastructure
- No dependency on other features
- Enhanced by Feature 08 (Collections) — could have a "Favorite Quotes" collection concept

## Future Enhancements

- Text selection from OCR (highlight specific portion of recognized text)
- Auto-detect page numbers from scanned text
- Quote categories/tags
- Daily quote notification (random quote from your collection)
- Quote search across all saved quotes
- Kindle highlights import (if Kindle integration added)
- Quote of the day widget
- Export all quotes as text file or PDF
- Community quote sharing
- AI-powered quote suggestions from book descriptions
