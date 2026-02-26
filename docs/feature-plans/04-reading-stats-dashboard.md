# Feature 04: Reading Stats Dashboard

## Overview

Add a dedicated statistics screen showing reading analytics and visualizations. This is one of the most requested features in book tracking apps and a key reason users switch from Goodreads to StoryGraph. The dashboard presents data derived from reading history, dates, ratings, and page counts in visually engaging charts and summaries.

## Competitive Analysis

| App | Stats Offering |
|-----|---------------|
| Goodreads | Year in Books page, rating distribution, basic counts |
| StoryGraph | Best-in-class: mood graphs, pace charts, genre breakdown, reading patterns by month, pages over time |
| Bookly | Reading speed, time spent, streaks, daily/weekly/monthly charts |
| Fable | Books count, pages, streaks, genre breakdown, Year in Review |
| Basmo | Reading time, streaks, books count |
| **BookShelf (current)** | **Section counts only (Want to Read: N, Read: N)** |

### StoryGraph's Stats (Gold Standard)
StoryGraph is praised for:
- Pages read by month (bar chart)
- Books read by month (bar chart)
- Genre/mood/pace breakdown (pie charts)
- Average rating over time
- Shortest/longest books
- Rating distribution histogram

### Our Approach
Start with the most impactful stats that can be computed from existing + newly added data (Features 01-03). No external data requirements.

## Design Implications

### New Tab or Section?

**Option A: New Tab** — Add a 4th tab "Stats" to the TabView
- Pro: Always accessible, clear entry point
- Con: Adds tab bar clutter, 4 tabs is still fine on iOS

**Option B: Section in Bookshelf** — Add stats summary at top of BookshelfView
- Pro: No navigation change, contextual
- Con: Crowds the main view, less room for detailed stats

**Recommended: Option A (New Tab)** — Stats deserve their own screen. Four tabs is standard for iOS apps.

### Stats Tab Layout

```
┌─────────────────────────────────┐
│  Stats                    2026 ▾│
│                                 │
│  ┌──── Overview ──────────────┐ │
│  │  📚 12 books read          │ │
│  │  📄 4,280 pages            │ │
│  │  ⭐ 3.8 avg rating         │ │
│  │  📅 18 days avg per book   │ │
│  └────────────────────────────┘ │
│                                 │
│  Books Read by Month            │
│  ┌────────────────────────────┐ │
│  │  ▌                         │ │
│  │  ▌   ▌      ▌              │ │
│  │  ▌ ▌ ▌   ▌  ▌  ▌           │ │
│  │  J F M A M J J A S O N D  │ │
│  └────────────────────────────┘ │
│                                 │
│  Pages Read by Month            │
│  ┌────────────────────────────┐ │
│  │  [similar bar chart]       │ │
│  └────────────────────────────┘ │
│                                 │
│  Rating Distribution            │
│  ┌────────────────────────────┐ │
│  │  ★★★★★  ████████  5       │ │
│  │  ★★★★☆  ████████████ 8    │ │
│  │  ★★★☆☆  ██████  4         │ │
│  │  ★★☆☆☆  ██  1             │ │
│  │  ★☆☆☆☆  █  0              │ │
│  └────────────────────────────┘ │
│                                 │
│  Highlights                     │
│  ┌────────────────────────────┐ │
│  │  📖 Longest: War & Peace   │ │
│  │     1,225 pages            │ │
│  │  📕 Shortest: The Old Man  │ │
│  │     127 pages              │ │
│  │  ⚡ Fastest: 3 days         │ │
│  │  🐌 Slowest: 45 days       │ │
│  └────────────────────────────┘ │
└─────────────────────────────────┘
```

### Year Selector
- Dropdown/picker in navigation bar to switch between years
- Default: current year
- "All Time" option for lifetime stats

### Card-Based Layout
Each stat group is a card with:
- Title header
- Content (chart or list)
- systemGray6 background, 12pt corner radius
- Consistent with existing DetailSection styling in BookDetailView

### Charts
Use Swift Charts framework (available since iOS 16):
- `BarMark` for monthly books/pages
- Horizontal `BarMark` for rating distribution
- Accent color for bars, secondary for labels

## Data Model Changes

### No New Models Required

All stats are **computed from existing data** (with Features 01-03):
- Books read count: `books.filter { $0.readStatus == .read }.count`
- Pages read: `books.filter { $0.readStatus == .read }.compactMap { $0.pageCount }.reduce(0, +)`
- Average rating: computed from `rating` values
- Books by month: group by `dateFinished` month
- Days to read: from `dateStarted` and `dateFinished`

### Stats Data Structure (Computed, not persisted)

```swift
struct ReadingStats {
    let booksRead: Int
    let pagesRead: Int
    let averageRating: Double?
    let averageDaysPerBook: Double?
    let booksByMonth: [Int: Int]        // month (1-12) → count
    let pagesByMonth: [Int: Int]        // month (1-12) → pages
    let ratingDistribution: [Int: Int]  // rating (1-5) → count
    let longestBook: Book?
    let shortestBook: Book?
    let fastestRead: Book?              // fewest days
    let slowestRead: Book?              // most days
}
```

## Architecture Changes

### New Files

| File | Purpose |
|------|---------|
| `Views/StatsView.swift` | Main stats tab view with ScrollView of stat cards |
| `Views/Stats/StatCardView.swift` | Reusable card component for each stat group |
| `Views/Stats/MonthlyBarChart.swift` | Bar chart using Swift Charts for monthly data |
| `Views/Stats/RatingDistributionChart.swift` | Horizontal bar chart for rating breakdown |
| `Views/Stats/StatsHighlightsView.swift` | Highlights card (longest, shortest, fastest, slowest) |
| `ViewModels/StatsViewModel.swift` | Computes all stats from book data |

### Modified Files

| File | Change |
|------|--------|
| `ContentView.swift` | Add 4th tab for StatsView |

## Implementation Steps

1. **Create StatsViewModel**
   - `@Observable` class, `@MainActor`
   - Takes `[Book]` as input (from shared ViewModel or direct fetch)
   - Method `computeStats(for year: Int?) -> ReadingStats`
   - Filter books by `dateFinished` year (or all time if nil)
   - Calculate all derived values

2. **Create StatCardView**
   - Reusable card with title + content ViewBuilder
   - Background: systemGray6, corner radius 12
   - Padding, max width infinity
   - Matches existing `DetailSection` styling

3. **Create MonthlyBarChart**
   - Uses Swift Charts `Chart { BarMark(...) }`
   - X axis: months (Jan-Dec)
   - Y axis: count
   - Accent color bars
   - Configurable data (books or pages)

4. **Create RatingDistributionChart**
   - Horizontal bar chart
   - 5 rows (★ to ★★★★★)
   - Bar width proportional to count
   - Count label at end of each bar

5. **Create StatsHighlightsView**
   - Grid or VStack of highlight items
   - Longest/shortest by page count
   - Fastest/slowest by days to read
   - Each with book title and value

6. **Create StatsView**
   - ScrollView with VStack of stat cards
   - Year picker in toolbar
   - Overview card (books, pages, avg rating, avg days)
   - Monthly bar charts
   - Rating distribution
   - Highlights

7. **Add Stats tab to ContentView**
   - Tab 3 (shift Search to tab 3, Stats to tab 3 or reorder)
   - Label: "Stats", systemImage: "chart.bar.fill"
   - Pass books data to StatsView

8. **Handle empty state**
   - If no books with `.read` status: show encouraging empty state
   - "Start reading to see your stats!"

## Testing Strategy

- Test with 0 books (empty state)
- Test with books missing dates (graceful nil handling)
- Test with books missing page counts
- Test year filtering
- Test rating distribution with various rating patterns
- Test monthly grouping across year boundaries
- Test highlights with tied values (same page count)
- Verify charts render correctly with small and large datasets
- Test "All Time" aggregation

## Dependencies

- **Strongly benefits from Feature 03** (Date Tracking) for monthly breakdowns, days-to-read, fastest/slowest
- Works partially without dates (books count, pages, ratings still available)
- Enhanced by Feature 02 (Reading Progress) for future progress-over-time charts

## Future Enhancements

- Genre breakdown (requires genre tagging)
- Reading streak tracking (consecutive days/weeks with reading activity)
- Mood/pace analysis (requires mood tagging from StoryGraph-style feature)
- Year-over-year comparison
- "Year in Review" shareable summary card (like Spotify Wrapped)
- Author diversity stats (most-read authors)
- Monthly reading goal progress overlay on bar chart
- Pages per day trend line
- Exportable stats as image for social sharing
