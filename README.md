# Handbook

An in-app help book for macOS apps. Write your help as Markdown, ship it in your bundle, and get a native window with a contents sidebar, search, back/forward, figures, and per-language switching — plus your topics in the system Help menu's search field.

No web view, no Apple Help Book, no build step.

## Why not an Apple Help Book

Two things pushed this into existence, both measured rather than assumed.

**A help book cannot follow your app's own language setting.** `helpd` resolves a book's `.lproj` from the *system* language list, once, at registration, and never sees a per-app `AppleLanguages` override. An app that lets the reader pick a language in its own settings will show them help in a different one.

**A `WKWebView` cannot render local help in a sandboxed app.** WebKit's render process refuses to start without `com.apple.security.network.client` — even for a `file://` URL inside your own bundle — and it fails silently: no navigation starts, and no navigation delegate fires except `webViewWebContentProcessDidTerminate`. Requiring a network entitlement to display local documentation is a poor trade for any app and a disqualifying one for an app that promises to be offline.

So Handbook parses the Markdown and draws it in SwiftUI.

## Install

```swift
.package(url: "https://github.com/onury/handbook", from: "1.0.0")
```

## Content layout

Ship two folder references in your app bundle:

```
topics/
  en/
    quick-start.md
    export.md
    images/
      export-sheet.png
  tr/
    quick-start.md
    export.md
chrome/
  en.json
  tr.json
```

A locale appears in the language picker the moment both its topic folder and its `chrome/<locale>.json` exist — and never before. Figures fall back to the base language per file, so a screenshot only needs recapturing when the UI inside it actually differs.

`chrome/<locale>.json` carries the contents-page copy and the window's own labels, so a translator touches one file per language:

```json
{
  "bookTitle": "Chromagic Help",
  "intro": "Chromagic removes the background from an image on your Mac.",
  "note": "**Every control explains itself.** Turn on *Show control tips* in Settings.",
  "indexDescription": "Help for Chromagic, the background remover for macOS.",
  "order": ["quick-start", "export"],
  "summaries": {
    "quick-start": "Drop an image in, check the result, export it.",
    "export": "Formats, encoders, sizing."
  },
  "ui": {
    "home": "Home", "back": "Back", "forward": "Forward", "contents": "Contents",
    "searchPlaceholder": "Search", "clear": "Clear", "languageLabel": "Help language",
    "resultsFor": "Results for “%@”", "noResults": "Nothing matched.",
    "unavailableTitle": "Help isn’t available",
    "unavailableMessage": "The help content is missing from this copy."
  }
}
```

The window's labels live there rather than in your string catalog on purpose: they follow the **help** language, so a Turkish page never appears under an English toolbar.

## Use

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }

        Window("My App Help", id: "help") {
            HandbookWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 660)
    }
}
```

Open it from anywhere:

```swift
HandbookLauncher.shared.open()                 // contents page
HandbookLauncher.shared.open(topic: "export")  // straight to a topic
```

Install the opener once, from a view that has SwiftUI's `openWindow`:

```swift
.onAppear { HandbookLauncher.shared.openWindow = { openWindow(id: "help") } }
```

### Your topics in the Help menu

`NSUserInterfaceItemSearching` has been public since 10.6 and lets an app answer the Help menu's search field directly. Registering a handler also stops that menu padding its results with Apple's own macOS help topics — which is what makes it look broken in an app with no help book.

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let search = HandbookSearchHandler()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.registerUserInterfaceItemSearchHandler(search)
    }
}
```

Selecting a result opens your window on that topic — Help Viewer is never involved.

## Configuration

```swift
HandbookWindow(configuration: HandbookConfiguration(
    languagePicker: .automatic,          // .always · .never
    theme: HandbookTheme(
        heading: .orange,                // nil for any role = derive from the system accent
        link: .orange,
        selection: .orange
    )
))
```

Toolbar glyphs are configurable the same way:

```swift
HandbookConfiguration(icons: HandbookIcons(sidebar: "IconSidebar", home: "IconHome", scale: 1.15))
```

Each defaults to an SF Symbol name, so the package ships no artwork and carries no icon licence. Pass a name from your own asset catalog and it is used instead — an asset is resolved first, with the symbol as the fallback. `scale` multiplies every toolbar glyph, since a stroked 24pt set reads smaller than an SF Symbol at the same point size.

Left alone, every colour follows the accent the reader chose in System Settings — headings lightened toward white on a dark page and toward black on a light one, so they lead without competing with body text.

## The Markdown subset

Headings, paragraphs, bullet and numbered lists, tables, blockquote notes, fenced code, figures (`![caption](shot.png)`), and reference entries written as `*Term* — description`. Inline **bold**, *italic*, `code` and links go through `AttributedString`'s own Markdown support.

It is deliberately small. A help book that needs arbitrary Markdown has outgrown being a help book.

## Requirements

macOS 14+. No dependencies.

## License

MIT
