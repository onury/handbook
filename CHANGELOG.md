# Changelog

## 1.6.4

- The unavailable state names no particular app ("this copy of the app"), and the toolbar's title falls back to "Help". Tests now pin the theme's roles, the configuration's defaults, and the browser's history, languages and search.

## 1.6.3

- The search field's focus ring is 1.5 points.

## 1.6.2

- The search field is a quiet flat fill, no glass, and wears the Mac's focus ring in the theme's accent while it has the cursor.

## 1.6.1

- Headings take the host's accents exactly as given — the title the primary, section headings the secondary — re-toning only the system accent when the host gives none; and the page's text is selectable again.

## 1.6.0

- A `secondaryAccent` for section headings and callouts beside the primary `accent` (the title, the contents, links, code); code, fenced and inline, in a deeper shade of the accent on a pale wash of it; links show the arrow rather than the text cursor (code blocks stay selectable); half again the space between reference entries; bullets twice the size; and the focused search field's bright rim veiled on the edge itself.

## 1.5.1

- The page takes the theme's accent (headings, links, the quote bar); a table's header keeps its columns again, its fill one band behind the row; the selection is one capsule that slides to the row; a click anywhere below the bar ends a search field's edit; and a focused search field sits darker than a resting one.

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
