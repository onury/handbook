import AppKit

// Your topics, in the Help menu's search field.
//
// That field is not fed only by a registered Apple Help Book. `NSUserInterfaceItemSearching`
// (AppKit, public since 10.6) lets an app answer it directly, and `performAction(forItem:)`
// lets the app handle the selection — so a result opens the in-app window rather than launching
// Help Viewer. Registering a handler also stops the menu padding its results with Apple's own
// macOS help topics, which is what makes that field look broken in an app with no help book.
//
// Register once, from `applicationDidFinishLaunching`, and hold a strong reference:
//
//     NSApp.registerUserInterfaceItemSearchHandler(handler)

/// A topic as the Help menu search sees it.
private struct SearchResult {
    let id: String
    let title: String
}

public final class HandbookSearchHandler: NSObject, NSUserInterfaceItemSearching {
    /// Built once per language and cached: the menu calls the search method on every
    /// keystroke, off the main thread, and re-reading thirteen files each time would be
    /// wasteful for no gain.
    private let corpus: [(id: String, title: String, haystack: String)]

    public init(configuration: HandbookConfiguration = HandbookConfiguration()) {
        let book = MainActor.assumeIsolated { HandbookBook.preferred(configuration) }
        corpus = (book?.chrome.order ?? []).compactMap { id in
            guard let source = book?.markdown(for: id) else { return nil }
            let parsed = HandbookMarkdown.parse(source)
            let summary = book?.chrome.summaries[id] ?? ""
            // Title, summary and section headings are enough: the menu is a jump list, not a
            // full-text search. The window's own field does the deep search.
            let sections = parsed.blocks.compactMap { block -> String? in
                if case .heading(_, let text) = block { return text }
                return nil
            }
            return (id, parsed.title, ([parsed.title, summary] + sections).joined(separator: " "))
        }
        super.init()
    }

    public func searchForItems(withSearch searchString: String,
                        resultLimit: Int,
                        matchedItemHandler handleMatchedItems: @escaping ([Any]) -> Void) {
        let needle = searchString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { handleMatchedItems([]); return }
        let matches = corpus
            .filter { $0.haystack.localizedCaseInsensitiveContains(needle) }
            .prefix(resultLimit)
            .map { SearchResult(id: $0.id, title: $0.title) }
        handleMatchedItems(Array(matches))
    }

    /// Just the topic. The array is joined with the system's separator, so returning the book
    /// name first prefixed every row with "Chromagic Help >" — noise in a menu that is already
    /// the app's own, and only ours appears there.
    public func localizedTitles(forItem item: Any) -> [String] {
        guard let result = item as? SearchResult else { return [] }
        return [result.title]
    }

    public func performAction(forItem item: Any) {
        guard let result = item as? SearchResult else { return }
        Task { @MainActor in HandbookLauncher.shared.open(topic: result.id) }
    }

    /// Implementing this is what puts "Show All Help Topics" in the menu — and it calls US,
    /// not Apple's help. It opens the window and runs the same query in the window's own
    /// search, which searches the full text rather than just titles and headings.
    public func showAllHelpTopics(forSearch searchString: String) {
        Task { @MainActor in HandbookLauncher.shared.open(search: searchString) }
    }
}
