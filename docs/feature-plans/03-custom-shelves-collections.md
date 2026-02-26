# Feature 08: Custom Shelves / Collections

## Overview

Allow users to create custom shelves (collections) to organize their books beyond the default reading status categories. Examples: "Favorites", "Owned", "Audiobooks", "Book Club Picks", "Signed Copies", "To Buy", "Lent Out". This is a fundamental organizational feature present in every major book tracking app and enables personal taxonomy that reading status alone cannot provide.

## Competitive Analysis

| App | Collection System |
|-----|------------------|
| Goodreads | 3 exclusive shelves + unlimited custom shelves (exclusive or tag-like) |
| StoryGraph | Tags and custom shelves |
| Fable | Custom shelves |
| Book Buddy | Customizable shelves, tags, and categories with smart lists |
| Libib | Multiple libraries + custom tags |
| Literal | Shelves with subscribe/follow capability |
| **BookShelf (current)** | **2 fixed shelves only (Want to Read, Read)** |

### Goodreads Model (Industry Standard)
Goodreads distinguishes between:
- **Exclusive shelves**: A book can be on only ONE (Read, Currently Reading, Want to Read)
- **Non-exclusive shelves**: A book can be on MANY simultaneously (Favorites, Owned, etc.)

This is the most flexible and intuitive model. Reading status remains exclusive (a book is either read or not), while collections are additive tags.

### Design Decision: Shelves vs Tags
- **Shelves model**: Each collection is a named list. Books are added/removed from lists. Good for browsing by collection.
- **Tags model**: Each book has tags. Books can have many tags. Good for filtering.
- **Recommended: Hybrid** — Use SwiftData relationships (Shelf model) but present them as tags in the UI for multi-select. This gives the best of both worlds.

## Design Implications

### Shelf Management

**Create/Edit Shelves**

Access from a new "Collections" section in BookshelfView or via a toolbar menu:

```
┌─────────────────────────────────┐
│  Collections              [+]   │
│                                 │
│  ┌────────────────────────────┐ │
│  │ ⭐ Favorites           12  │ │
│  │ 📦 Owned               34  │ │
│  │ 🎧 Audiobooks           8  │ │
│  │ 📚 Book Club            5  │ │
│  │ ✍️  Signed Copies        3  │ │
│  └────────────────────────────┘ │
│                                 │
│  [Edit Collections]            │
└─────────────────────────────────┘
```

Tapping a collection shows its books in a grid (same layout as main bookshelf sections).

**Create New Collection Sheet**

```
┌─────────────────────────────────┐
│  New Collection            [X]  │
│                                 │
│  Name                           │
│  ┌────────────────────────────┐ │
│  │ Favorites                  │ │
│  └────────────────────────────┘ │
│                                 │
│  Icon                           │
│  ⭐ 📚 🎧 📖 💜 🔥 📦 ✍️ 🏆   │
│  (scrollable icon picker)       │
│                                 │
│  [Create]                       │
└─────────────────────────────────┘
```

### Adding Books to Collections

**From BookDetailView** — Add a "Collections" section:

```
┌─── Collections ───────────────┐
│                                │
│  ☑ Favorites                   │
│  ☑ Owned                       │
│  ☐ Audiobooks                  │
│  ☐ Book Club                   │
│                                │
│  [+ New Collection]            │
└────────────────────────────────┘
```

Toggle checkmarks to add/remove from collections. Multiple selections allowed.

**From Context Menu** (BookshelfView grid):
- Add "Add to Collection →" submenu
- Shows list of collections with checkmarks

**From Bulk Selection** (future enhancement):
- Select multiple books → "Add to Collection"

### BookshelfView Integration

**Option A: Inline sections** — Show collections as collapsible sections below the reading status sections:

```
Currently Reading (2)
  [books grid]

Want to Read (5)
  [books grid]

Read (12)
  [books grid]

─── Collections ───

⭐ Favorites (4)
  [books grid]

🎧 Audiobooks (8)
  [books grid]
```

**Option B: Separate tab/view** — Keep main bookshelf clean, add a "Collections" view.

**Option C: Filter chips** — Add horizontal scrolling filter chips at the top:

```
[All] [⭐ Favorites] [📦 Owned] [🎧 Audiobooks] [+ New]
```

Selecting a chip filters the bookshelf to show only books in that collection.

**Recommended: Option C (filter chips)** — Cleanest UI, doesn't clutter the main view, familiar iOS pattern.

## Data Model Changes

### New Model: BookCollection

```swift
@Model final class BookCollection {
    var name: String
    var icon: String          // SF Symbol name or emoji
    var dateCreated: Date
    var sortOrder: Int        // For manual ordering

    @Relationship(inverse: \Book.collections)
    var books: [Book] = []

    init(name: String, icon: String = "books.vertical", sortOrder: Int = 0) {
        self.name = name
        self.icon = icon
        self.dateCreated = Date()
        self.sortOrder = sortOrder
    }
}
```

### Book.swift — Add Relationship

```swift
@Model final class Book {
    // ... existing properties ...

    @Relationship
    var collections: [BookCollection] = []
}
```

### Migration Considerations

- **New model**: `BookCollection` is entirely new — no migration needed
- **New relationship on Book**: Adding an optional/empty relationship to an existing model is safe in SwiftData (defaults to empty array)
- Register `BookCollection.self` in SwiftData schema
- SwiftData handles the junction table automatically for many-to-many relationships

## Architecture Changes

### New Files

| File | Purpose |
|------|---------|
| `Models/BookCollection.swift` | Collection model with relationship to Book |
| `Views/Collections/CollectionListView.swift` | List of all collections |
| `Views/Collections/CollectionDetailView.swift` | Books in a specific collection |
| `Views/Collections/CreateCollectionView.swift` | Sheet for creating/editing a collection |
| `Views/Collections/CollectionPickerView.swift` | Multi-select picker for adding book to collections |
| `Views/Collections/CollectionFilterChips.swift` | Horizontal scrolling filter chips |

### Modified Files

| File | Change |
|------|--------|
| `Models/Book.swift` | Add `collections` relationship |
| `BookShelfApp.swift` | Register `BookCollection.self` in schema |
| `Views/BookshelfView.swift` | Add filter chips, collection filtering |
| `Views/BookDetailView.swift` | Add collections section with toggle picker |
| `ViewModels/BookshelfViewModel.swift` | Add collection CRUD methods |

## Implementation Steps

1. **Create BookCollection model**
   - Name, icon, dateCreated, sortOrder
   - `@Relationship` to `[Book]`
   - Register in SwiftData schema

2. **Add relationship to Book model**
   - `var collections: [BookCollection] = []`
   - `@Relationship` with inverse

3. **Create CreateCollectionView**
   - Text field for name
   - Icon picker (grid of SF Symbols or emojis)
   - Create / Save button
   - Validation: non-empty name, unique name

4. **Create CollectionPickerView**
   - List of all collections with checkmarks
   - Toggle to add/remove book from collection
   - "New Collection" button at bottom
   - Used in BookDetailView

5. **Create CollectionFilterChips**
   - Horizontal ScrollView with capsule buttons
   - "All" chip (always first, default selected)
   - One chip per collection with icon + name
   - "+" button at end to create new collection
   - Single selection (tap to filter)

6. **Update BookshelfView**
   - Add CollectionFilterChips above book sections
   - When a collection chip is selected, filter displayed books to that collection
   - When "All" is selected, show normal reading status sections

7. **Create CollectionDetailView**
   - Full-screen view of books in a collection
   - Same grid layout as BookshelfView sections
   - Edit/delete collection options in toolbar
   - Remove books from collection via context menu

8. **Update BookDetailView**
   - Add "Collections" section
   - Show CollectionPickerView for adding/removing

9. **Update ViewModel**
   - `createCollection(name:icon:)` method
   - `deleteCollection(_:)` method
   - `addBookToCollection(book:collection:)` method
   - `removeBookFromCollection(book:collection:)` method
   - `fetchCollections()` method

10. **Add context menu integration**
    - "Add to Collection →" in BookshelfView context menu
    - Shows submenu of collections

## Testing Strategy

- Test creating a collection
- Test adding a book to multiple collections
- Test removing a book from a collection
- Test deleting a collection (books should remain, only relationship removed)
- Test filter chips filtering correctly
- Test collection with 0 books (empty state)
- Test collection name validation (empty, duplicate)
- Test many-to-many relationship integrity
- Test that reading status sections still work independently of collections
- Test that deleting a book removes it from all collections

## Dependencies

- Independent — can be implemented at any time
- Enhanced by Feature 07 (Goodreads Import) — could map Goodreads custom shelves to collections
- Works well alongside all other features

## Future Enhancements

- Smart collections (auto-populated by rules, like Book Buddy's smart lists)
  - "Books over 500 pages"
  - "5-star books"
  - "Read in 2026"
- Collection sharing (generate a link to share a collection)
- Collection sorting options (manual drag, alphabetical, date added)
- Collection cover/thumbnail (mosaic of book covers)
- Drag-and-drop to reorder collections
- Import Goodreads custom shelves as collections
- Nested collections (sub-categories)
- Collection color themes
