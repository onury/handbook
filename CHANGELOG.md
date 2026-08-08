# Changelog

## 1.1.0

- `HandbookIcons` makes the toolbar's glyphs configurable. Each defaults to an SF Symbol, so the package still ships no artwork; pass an asset-catalog name to use your own set.

## 1.0.0

First release.

- Markdown help topics rendered natively in SwiftUI — headings, lists, tables, notes, fenced code, figures, and `*Term* — description` reference entries.
- A window with a contents sidebar, ranked search, and back/forward that walks topic paths rather than every load.
- Per-language books discovered from the bundle, with a picker that switches instantly and keeps the reader on their topic.
- Window labels per locale, so the chrome follows the help language rather than the app's.
- The app's topics in the Help menu's search field via `NSUserInterfaceItemSearching`, with selection handled in-app.
- Configurable theme; every colour defaults to being derived from the system accent.
