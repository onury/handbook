import SwiftUI

@MainActor
@Observable
final class HandbookBrowser {
    private(set) var book: HandbookBook?
    let languages: [String]
    private(set) var topics: [HandbookTopic] = []
    private(set) var document: HandbookDocument?
    var query = ""
    /// Open by default: the contents list is how most readers move around a help book, and a
    /// hidden sidebar makes the window look like a single page with no way out.
    var showsSidebar = true
    var canGoBack = false
    var canGoForward = false

    /// Our own history, and the reason we do not use a web view's: back and forward should
    /// walk the TOPICS the reader visited. Switching language re-renders the same topic, and
    /// counting that as a step made Back walk into the other language.
    ///
    /// Entries are topic ids; `nil` is the contents page. Language is deliberately not part of
    /// an entry, which is what keeps it out of the history.
    private var history: [String?] = []
    private var cursor = -1

    var currentTopic: String? { history.indices.contains(cursor) ? history[cursor] : nil }

    let configuration: HandbookConfiguration

    init(configuration: HandbookConfiguration) {
        self.configuration = configuration
        languages = HandbookBook.available(configuration)
        book = HandbookBook.preferred(configuration)
        reloadCorpus()
    }

    var language: String { book?.language ?? "en" }

    /// Parses every topic once per language, for search. Thirteen small files.
    private func reloadCorpus() {
        guard let book else { topics = []; return }
        topics = book.chrome.order.compactMap { id in
            guard let source = book.markdown(for: id) else { return nil }
            let parsed = HandbookMarkdown.parse(source)
            var sections: [String] = []
            var prose: [String] = []
            for block in parsed.blocks {
                switch block {
                case .heading(_, let text): sections.append(text)
                case .paragraph(let text), .note(let text): prose.append(text)
                case .bullets(let items), .numbers(let items): prose.append(items.joined(separator: " "))
                case .definitions(let entries):
                    prose.append(entries.map { "\($0.term) \($0.description)" }.joined(separator: " "))
                case .table(let head, let rows):
                    prose.append((head + rows.flatMap { $0 }).joined(separator: " "))
                case .code(let text): prose.append(text)
                // Only ever present on generated pages (contents, results), never in a topic
                // file, so it contributes nothing to the search corpus.
                case .topicLinks: break
                // A caption is prose the reader can see, so it is searchable.
                case .image(_, let caption): prose.append(caption)
                }
            }
            return HandbookTopic(id: id, title: parsed.title,
                             summary: book.chrome.summaries[id] ?? "",
                             sections: sections, text: prose.joined(separator: " "))
        }
    }

    // ── Navigation ────────────────────────────────────────────────────────────

    /// The first page. Seeds the history rather than pushing, so Back is correctly disabled
    /// when the window opens.
    func start() {
        history = [nil]
        cursor = 0
        show(entry: nil)
    }

    func loadHome() {
        query = ""
        push(nil)
    }

    func open(topic id: String) {
        push(id)
    }

    func goBack() {
        guard cursor > 0 else { return }
        cursor -= 1
        show(entry: currentTopic)
    }

    func goForward() {
        guard cursor + 1 < history.count else { return }
        cursor += 1
        show(entry: currentTopic)
    }

    /// A new destination truncates anything ahead of the cursor, the way a browser does.
    private func push(_ entry: String?) {
        if currentTopic == entry, cursor >= 0 {
            show(entry: entry)
            return
        }
        if cursor < history.count - 1 { history.removeSubrange((cursor + 1)...) }
        history.append(entry)
        cursor = history.count - 1
        show(entry: entry)
    }

    /// Renders a history entry in the CURRENT language. Nothing here touches the history, so
    /// re-rendering after a language switch costs no step.
    private func show(entry: String?) {
        guard let book else { return }
        if let entry, let source = book.markdown(for: entry) {
            document = HandbookMarkdown.parse(source)
        } else {
            document = contentsPage(book)
        }
        canGoBack = cursor > 0
        canGoForward = cursor + 1 < history.count
    }

    /// Switching is instant: the window renders the topics itself, so there is nothing to
    /// re-register and no relaunch — exactly what the system help viewer could not do.
    func select(language: String) {
        guard language != book?.language, let next = HandbookBook.book(for: language, configuration) else { return }
        book = next
        reloadCorpus()
        query = ""
        // Re-render the SAME entry, so the reader stays on the topic they were reading.
        let entry = currentTopic
        show(entry: topics.contains(where: { $0.id == entry }) ? entry : nil)
    }

    // ── Contents and search ───────────────────────────────────────────────────

    private func contentsPage(_ book: HandbookBook) -> HandbookDocument {
        return HandbookDocument(title: book.chrome.bookTitle, blocks: [
            .paragraph(book.chrome.intro),
            .note(book.chrome.note),
            .topicLinks(topics.map { (id: $0.id, title: $0.title, summary: $0.summary) }),
        ])
    }

    /// Ranked: a title hit beats a section heading, which beats body prose. Without it,
    /// searching a control's name surfaces whichever topic merely mentions it before the
    /// topic that documents it.
    func runSearch() {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { loadHome(); return }

        let hits = topics.compactMap { topic -> (HandbookTopic, Int, String)? in
            if topic.title.localizedCaseInsensitiveContains(needle) { return (topic, 0, topic.summary) }
            if let section = topic.sections.first(where: { $0.localizedCaseInsensitiveContains(needle) }) {
                return (topic, 1, section)
            }
            if let range = topic.text.range(of: needle, options: .caseInsensitive) {
                return (topic, 2, Self.snippet(topic.text, around: range))
            }
            return nil
        }
        .sorted { $0.1 < $1.1 }

        // Results are a rendered page, not a history entry: Back should return to the topic
        // the reader came from, not to a list they have already left.
        let ui = book?.chrome.ui
        document = HandbookDocument(
            title: String(format: ui?.resultsFor ?? "Results for “%@”", needle),
            blocks: hits.isEmpty
                ? [.paragraph(ui?.noResults ?? "Nothing matched.")]
                : [.topicLinks(hits.map { (id: $0.0.id, title: $0.0.title, summary: $0.2) })]
        )
    }

    /// ~150 characters of context around the hit, cut on word boundaries so a result never
    /// starts or ends mid-word.
    private static func snippet(_ text: String, around range: Range<String.Index>) -> String {
        let pad = 70
        let lower = text.index(range.lowerBound, offsetBy: -pad, limitedBy: text.startIndex) ?? text.startIndex
        let upper = text.index(range.upperBound, offsetBy: pad, limitedBy: text.endIndex) ?? text.endIndex
        var piece = String(text[lower..<upper])
        if lower > text.startIndex, let space = piece.firstIndex(of: " ") {
            piece = "…" + piece[piece.index(after: space)...]
        }
        if upper < text.endIndex, let space = piece.lastIndex(of: " ") {
            piece = piece[..<space] + "…"
        }
        return piece
    }
}

// ── Window ────────────────────────────────────────────────────────────────────

public struct HandbookWindow: View {
    @State private var browser: HandbookBrowser
    private let configuration: HandbookConfiguration

    public init(configuration: HandbookConfiguration = HandbookConfiguration()) {
        self.configuration = configuration
        _browser = State(initialValue: HandbookBrowser(configuration: configuration))
    }

    /// The bar's height, and the inset the page needs so its first line clears the glass.
    private static let barHeight: CGFloat = 52

    public var body: some View {
        ZStack(alignment: .top) {
            content
            HandbookBar(browser: browser, configuration: configuration)
        }
        // The bar occupies the titlebar strip itself, so the controls sit on ONE line with
        // the traffic lights instead of in a second row beneath them.
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 620, minHeight: 460)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(WindowConfigurator())
        .task {
            if browser.document == nil { browser.start() }
            consumePendingRequest()
        }
        // A result chosen while the window is ALREADY open reaches it here: `task` runs once,
        // and the app never resigns active for its own menu, so neither of those fires.
        .onChange(of: HandbookLauncher.shared.pendingTopic) { _, _ in consumePendingRequest() }
        .onChange(of: HandbookLauncher.shared.pendingSearch) { _, _ in consumePendingRequest() }
    }

    /// Anything the Help menu asked for on the way in — a topic, or a full search from
    /// "Show All Help Topics".
    private func consumePendingRequest() {
        if let topic = HandbookLauncher.shared.pendingTopic {
            HandbookLauncher.shared.pendingTopic = nil
            browser.open(topic: topic)
        }
        if let search = HandbookLauncher.shared.pendingSearch {
            HandbookLauncher.shared.pendingSearch = nil
            browser.query = search
            browser.runSearch()
        }
    }

    @ViewBuilder
    private var content: some View {
        if browser.book == nil {
            // Only reachable if the help resources are missing from the bundle, which is a
            // packaging fault. Say so rather than showing an empty window.
            ContentUnavailableView(
                "Help isn’t available",
                systemImage: "questionmark.circle",
                description: Text("The help content is missing from this copy of Chromagic.")
            )   // No book resolved, so there is no localized copy to show this in.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let document = browser.document {
            HStack(spacing: 0) {
                if browser.showsSidebar {
                    HandbookSidebar(browser: browser, theme: configuration.theme, topInset: Self.barHeight)
                    Divider()
                }
                HandbookDocumentView(document: document,
                                 images: browser.book?.topics.appending(path: "images"),
                                 topInset: Self.barHeight) { topic in
                    if topic == "index" { browser.loadHome() } else { browser.open(topic: topic) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            Color.clear
        }
    }
}

/// The contents list. Selecting a topic navigates through the same history as everything
/// else, so back and forward keep working after a sidebar jump.
private struct HandbookSidebar: View {
    @Environment(\.colorScheme) private var colorScheme
    let browser: HandbookBrowser
    let theme: HandbookTheme
    let topInset: CGFloat

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                // Named for what it does, not for the book — "Home" reads as a destination
                // where the book's own title reads as a heading.
                row(title: browser.book?.chrome.ui.home ?? "Home", topic: nil)
                ForEach(browser.topics) { topic in
                    row(title: topic.title, topic: topic.id)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
            .padding(.top, topInset + 8)
        }
        .frame(width: 216)
        // A shade darker than the page, so the list reads as a separate surface rather than
        // a column of the same document. The tint is its own layer over the material — as an
        // .overlay ON the material it barely registered.
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(Color.black.opacity(colorScheme == .dark ? 0.10 : 0.035))
            }
        }
    }

    private func row(title: String, topic: String?) -> some View {
        let selected = browser.currentTopic == topic
        return Button {
            if let topic { browser.open(topic: topic) } else { browser.loadHome() }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? theme.selection(colorScheme) : theme.bodyColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected ? theme.selectionBackground(colorScheme) : .clear)
                )
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// The toolbar, laid out like the system help viewer's: navigation on the left, the book's
/// name in the middle, search on the right.
private struct HandbookBar: View {
    let browser: HandbookBrowser
    let configuration: HandbookConfiguration
    @FocusState private var searching: Bool

    var body: some View {
        HStack(spacing: 12) {
            barButton(configuration.icons.sidebar, ui.contents, enabled: true) {
                withAnimation(.easeOut(duration: 0.18)) { browser.showsSidebar.toggle() }
            }
            .glassCapsule()

            HStack(spacing: 0) {
                barButton(configuration.icons.back, ui.back, enabled: browser.canGoBack) {
                    browser.goBack()
                }
                barButton(configuration.icons.forward, ui.forward, enabled: browser.canGoForward) {
                    browser.goForward()
                }
            }
            .glassCapsule()

            barButton(configuration.icons.home, ui.contents, enabled: true) { browser.loadHome() }
                .glassCapsule()

            Spacer(minLength: 12)
            Text(browser.book?.chrome.bookTitle ?? "Chromagic Help")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 12)

            searchField
            languagePicker
        }
        // The window hides its title bar so this row IS the chrome; the leading inset keeps
        // the first control clear of the traffic lights.
        // Leading inset clears the traffic lights, with room to breathe after them.
        .padding(.leading, 108)
        .padding(.trailing, 14)
        .frame(height: 52)
        // Frosted, so the page blurs through as it scrolls beneath. Note the material carries
        // its own opacity AND its blur: putting .opacity() on it composites the material at a
        // fraction and lets the text through razor sharp — translucent, but not frosted.
        // .ultraThin is already the most see-through of the materials.
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
        // Dragging the bar — including the title — moves the window, which is what a real
        // titlebar does and what this row is standing in for.
        .background(WindowDragArea())
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            HandbookBar.glyph(configuration.icons.search, size: 13)
                .foregroundStyle(.secondary)
            TextField(ui.searchPlaceholder, text: Binding(
                get: { browser.query },
                set: { browser.query = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .focused($searching)
            .onSubmit { browser.runSearch() }
            if !browser.query.isEmpty {
                Button {
                    browser.query = ""
                    browser.loadHome()
                } label: {
                    HandbookBar.glyph(configuration.icons.clear, size: 13)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(ui.clear))
            }
        }
        .padding(.horizontal, 11)
        .frame(width: 280, height: 32)
        .glassCapsule()
    }

    /// Reads the help in a different language from the app's, without changing the app's own
    /// setting — useful for checking a translation, and for a reader whose interface language
    /// is not the one they read documentation in. Hidden when only one language is built,
    /// where it would be a control with a single choice.
    @ViewBuilder private var languagePicker: some View {
        if configuration.languagePicker.isVisible(languageCount: browser.languages.count) {
            Picker("Language", selection: Binding(
                get: { browser.language },
                set: { browser.select(language: $0) }
            )) {
                ForEach(browser.languages, id: \.self) { language in
                    Text(HandbookBook.name(for: language)).tag(language)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .buttonStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 32)
            .glassCapsule()
            .help(Text(ui.languageLabel))
        }
    }

    /// The current book's labels, with English as the fallback for the unreachable case where
    /// no book resolved at all.
    private var ui: HandbookChrome.UI {
        browser.book?.chrome.ui ?? HandbookChrome.UI(
            home: "Home", back: "Back", forward: "Forward", contents: "Contents",
            searchPlaceholder: "Search", clear: "Clear", languageLabel: "Help language",
            resultsFor: "Results for “%@”", noResults: "Nothing matched.",
            unavailableTitle: "Help isn’t available",
            unavailableMessage: "The help content is missing from this copy of Chromagic.")
    }

    /// Asset first, SF Symbol second, so a host can pass either kind of name.
    @ViewBuilder
    static func glyph(_ name: String, size: CGFloat = 14) -> some View {
        if NSImage(named: name) != nil {
            Image(name).renderingMode(.template).resizable().scaledToFit()
                .frame(width: size + 1, height: size + 1)
        } else {
            Image(systemName: name).font(.system(size: size, weight: .medium))
        }
    }

    private func barButton(_ symbol: String, _ label: String,
                           enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Self.glyph(symbol)
                .frame(width: 36, height: 32)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .foregroundStyle(enabled ? .primary : .tertiary)
        .accessibilityLabel(Text(label))
        .help(Text(label))
    }
}
