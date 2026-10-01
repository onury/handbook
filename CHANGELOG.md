# Changelog

## 1.5.0

- An `accent` in the theme that every role derives its tones from; the sidebar's selection is a capsule that slides between rows; `sidebarWrapsTitles` keeps long titles to one line; a table's header fill spans the whole row; and the search field keeps one structure across focus, which froze and then crashed the window in 1.4.1.

## 1.4.1

- The search field is flat while it waits, and glass with a quiet rim once it has the cursor.

## 1.4.0

- The toolbar's buttons are flat: the sidebar toggle, Back, Forward and Home stand on a glass circle only while the pointer is over them, the way a macOS 27 toolbar reads. The search field and the language picker keep their capsules.

## 1.3.0

- Tables are drawn as tables: a rounded frame, a filled header and a rule between rows. Every column but the last is as wide as its widest cell and never wraps; the last takes the remaining width.

## 1.2.0

- `HandbookIcons.scale` multiplies the toolbar glyphs, for icon sets whose optical weight differs from SF Symbols.

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
