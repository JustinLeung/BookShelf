# Feature 11: Affiliate Links for Amazon & Audible

## Overview

Convert the existing Amazon and Audible convenience links into affiliate links to generate revenue when users purchase books through the app. Currently, the links are plain direct URLs with no tracking parameters. By joining the Amazon Associates program, the app can append an affiliate tag and earn a commission (typically 4.5% on physical books, varies for Kindle/Audible) at no extra cost to the user.

## Current Implementation

### Book.swift — Computed Properties

```swift
var amazonURL: URL? {
    let cleanISBN = isbn.replacingOccurrences(of: "-", with: "")
    return URL(string: "https://www.amazon.com/dp/\(cleanISBN)")
}

var audibleURL: URL? {
    let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
    return URL(string: "https://www.audible.com/search?keywords=\(encodedTitle)")
}
```

These generate direct links with no affiliate parameters.

## Affiliate Programs

### Amazon Associates

- **Program:** [Amazon Associates](https://affiliate-program.amazon.com/)
- **Tag format:** `?tag=<associate-id>` appended to any Amazon product URL
- **Commission:** ~4.5% on physical books, ~4% on Kindle, varies for Audible
- **Cookie window:** 24 hours (if user purchases within 24h of clicking, you earn commission)
- **Requirements:** Must disclose affiliate relationship to users (FTC requirement)

### Audible

- Audible links can use the same Amazon Associates tag since Audible is an Amazon subsidiary
- Alternatively, Audible has its own bounty program that pays a flat fee per trial signup
- **Tag format:** Same `tag=<associate-id>` parameter works on audible.com URLs

## Design Implications

### User-Facing Changes

**Affiliate Disclosure** (FTC required):
- Add a brief disclosure near the purchase links, e.g. "We may earn a commission from purchases"
- Alternatively, include disclosure in the App Store description and/or a Settings > About screen
- The disclosure must be clear and conspicuous — not buried in fine print

**No visual change to buttons** — the pill-style links stay the same; only the underlying URL changes.

### Settings Screen (Optional)

Consider adding a toggle in Settings to let users opt out of affiliate tracking if they prefer direct links. This builds trust and is a good practice, though not legally required.

## Data Model Changes

### No Model Changes Required

The affiliate tag is a static string appended to the URL. No new stored properties needed.

### Configuration

The affiliate tag should be stored as a constant, not hardcoded across multiple files:

```swift
enum AffiliateConfig {
    static let amazonAssociateTag = "bookshelf-20"  // Replace with actual tag
    static let isEnabled = true
}
```

## Architecture Changes

### Files Modified

| File | Change |
|------|--------|
| `Models/Book.swift` | Update `amazonURL` and `audibleURL` to append affiliate tag |
| `Views/BookDetailView.swift` | Add small affiliate disclosure text below purchase links |
| `Config/AffiliateConfig.swift` | New file — centralized affiliate tag constant and enable flag |

### Book.swift — Updated Computed Properties

```swift
var amazonURL: URL? {
    let cleanISBN = isbn.replacingOccurrences(of: "-", with: "")
    let tag = AffiliateConfig.isEnabled ? "&tag=\(AffiliateConfig.amazonAssociateTag)" : ""
    return URL(string: "https://www.amazon.com/dp/\(cleanISBN)?tag=\(AffiliateConfig.amazonAssociateTag)")
}

var audibleURL: URL? {
    let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
    return URL(string: "https://www.audible.com/search?keywords=\(encodedTitle)&tag=\(AffiliateConfig.amazonAssociateTag)")
}
```

### BookDetailView.swift — Disclosure

Add a subtle disclosure below the purchase link pills:

```swift
Text("We may earn a small commission from purchases.")
    .font(.caption2)
    .foregroundStyle(.tertiary)
```

## Implementation Steps

1. **Sign up for Amazon Associates** — Apply at affiliate-program.amazon.com, get approved, and receive an associate tag (e.g. `bookshelf-20`)

2. **Create AffiliateConfig** — New file with the tag constant and an enable toggle

3. **Update Book.swift URLs** — Append `tag=` parameter to both `amazonURL` and `audibleURL`

4. **Add FTC disclosure** — Small caption text below the purchase links in `BookDetailView`

5. **Update App Store description** — Add affiliate disclosure to the app's description or privacy policy

6. **Test links** — Verify affiliate tag appears in URLs, links resolve correctly, and Amazon attributes clicks to the associate account

## Legal / Compliance Requirements

- **FTC Disclosure:** Required in the US. Must clearly state the affiliate relationship wherever links appear.
- **Amazon Associates Operating Agreement:** Must comply with their terms — no incentivizing clicks, no misleading link text, no cloaking URLs.
- **App Store Guidelines:** Apple allows affiliate links in apps. No known restrictions as of 2025.
- **International:** Amazon Associates programs are region-specific. A US tag only works for amazon.com. For international users, consider Amazon OneLink to redirect to local Amazon stores.

## Testing Strategy

- Verify `amazonURL` contains the `tag=` parameter
- Verify `audibleURL` contains the `tag=` parameter
- Verify links resolve correctly in Safari (no broken URLs from encoding)
- Verify disclosure text renders below purchase links
- Verify `AffiliateConfig.isEnabled = false` produces clean URLs without tags
- Test with various ISBNs (10-digit, 13-digit, with hyphens)

## Future Enhancements

- **Amazon OneLink** for international support (auto-redirects to user's local Amazon)
- **Settings toggle** to let users opt out of affiliate tracking
- **Analytics** to track click-through rates on purchase links
- **Additional retailers** (Bookshop.org has a generous affiliate program at 10% commission and supports independent bookstores)
