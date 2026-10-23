import SwiftUI

// Native rendering for a help topic.
//
// A WKWebView over generated HTML is the obvious alternative and is not available to a
// sandboxed app: WebKit's render process refuses to start without
// com.apple.security.network.client, even for a file:// URL inside the app's own bundle, and it
// fails silently — no navigation begins, and no navigation delegate fires except
// webViewWebContentProcessDidTerminate. Requiring a network entitlement to show local help is a
// poor trade for any app, and a disqualifying one for an app that promises to be offline.
//
// Drawing the blocks natively also makes figures easy, which NSTextAttachment does not.

/// Draws a parsed topic. The measurements track Help/style.css so the in-app window and the
/// generated book read as the same document.
public struct HandbookDocumentView: View {
    @Environment(\.colorScheme) private var colorScheme
    let document: HandbookDocument
    let theme: HandbookTheme
    /// Where this locale's screenshots live. Nil disables images rather than showing a broken
    /// placeholder — a help page with a missing figure should still read.
    var images: URL?
    /// Space for the floating toolbar. The page scrolls UNDER the bar — that is what gives
    /// the frosted glass something to frost — so the first line needs clearing manually.
    var topInset: CGFloat = 0
    /// A count the host moves to send the page back to its top (the window's Home).
    var scrollsToTop = 0
    /// A count the host moves when a different page comes up. The page opens at its top, so
    /// a new topic never opens where the last one was left.
    var page = 0
    /// Tapping a topic link. Targets arrive as file names (`matte-engines.html`), the same
    /// way they are written in the Markdown.
    var onOpen: (String) -> Void = { _ in }

    public init(document: HandbookDocument,
                theme: HandbookTheme = HandbookTheme(),
                images: URL? = nil,
                topInset: CGFloat = 0,
                scrollsToTop: Int = 0,
                page: Int = 0,
                onOpen: @escaping (String) -> Void = { _ in }) {
        self.document = document
        self.theme = theme
        self.images = images
        self.topInset = topInset
        self.scrollsToTop = scrollsToTop
        self.page = page
        self.onOpen = onOpen
    }

    /// The page's top, which Home scrolls back to.
    private static let top = "handbook.document.top"

    public var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            // The page's true top, above its margin, which Home scrolls back to: the title
            // scrolled to the top edge slid under the bar (1.7.0).
            Color.clear.frame(height: 0).id(Self.top)
            VStack(alignment: .leading, spacing: 16) {
                Text(styled(document.title))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(theme.heading(colorScheme))
                    .padding(.bottom, 2)

                ForEach(document.blocks) { block in
                    view(for: block)
                }
            }
            // The page is selectable: a reader copies from help. (A selectable Text shows the
            // text cursor over its links too, and SwiftUI offers no per-link cursor.)
            .textSelection(.enabled)
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 34)
            .padding(.bottom, 30)
            .padding(.top, topInset + 24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        // A new page is a scroll view of its own, which opens at its top (1.7.0). A jump to
        // the top as the page came up ran before the new page was laid out, and at times the
        // last page's offset stayed.
        .id(page)
        // A new count is a request to start from the top (the window's Home).
        .onChange(of: scrollsToTop) {
            withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(Self.top, anchor: .top) }
        }
        }
        .environment(\.openURL, OpenURLAction { url in
            // Topic links are relative file names; anything absolute belongs to the browser.
            let target = url.absoluteString
            guard !target.hasPrefix("http") else { return .systemAction }
            onOpen(URL(fileURLWithPath: target).deletingPathExtension().lastPathComponent)
            return .handled
        })
        // Inline links in running text take the theme's link colour, not the system accent.
        .tint(theme.link(colorScheme))
    }

    @ViewBuilder
    private func view(for block: HandbookBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(styled(text))
                .font(.system(size: level == 2 ? 19 : 16, weight: .semibold))
                .foregroundStyle(theme.subheading(colorScheme))
                .padding(.top, level == 2 ? 14 : 8)

        case .paragraph(let text):
            Text(styled(text))
                .font(.system(size: 14))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

        case .note(let text):
            HStack(alignment: .top, spacing: 12) {
                // The stylesheet's left rule, which is what makes a note read as an aside
                // rather than another paragraph.
                Rectangle()
                    .fill(theme.callout(colorScheme).opacity(0.7))
                    .frame(width: 3)
                Text(styled(text))
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(theme.secondaryColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    marker("•", styled(item))
                }
            }

        case .numbers(let items):
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    marker("\(index + 1).", styled(item))
                }
            }

        case .definitions(let entries):
            VStack(alignment: .leading, spacing: 16.5) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(styled(entry.term))
                            .font(.system(size: 14, weight: .semibold))
                        Text(styled(entry.description))
                            .font(.system(size: 14))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .table(let head, let rows):
            table(head: head, rows: rows)
                .padding(.vertical, 4)

        case .topicLinks(let entries):
            VStack(alignment: .leading, spacing: 13) {
                ForEach(entries, id: \.id) { entry in
                    Button { onOpen(entry.id) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.title)
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundStyle(theme.link(colorScheme))
                            if !entry.summary.isEmpty {
                                Text(styled(entry.summary))
                                    .font(.system(size: 14))
                                    .foregroundStyle(theme.bodyColor)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(entry.title))
                }
            }

        case .image(let source, let caption):
            if let image = loadImage(source) {
                VStack(alignment: .leading, spacing: 7) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        // Never upscale past its own size: a 600pt-wide screenshot blown up to
                        // the column width is mush.
                        .frame(maxWidth: min(image.size.width, 680))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .accessibilityLabel(Text(caption))
                    if !caption.isEmpty {
                        Text(styled(caption))
                            .font(.system(size: 12.5))
                            .foregroundStyle(theme.secondaryColor)
                    }
                }
                .padding(.vertical, 4)
            }

        case .code(let text):
            Text(text)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(theme.code(colorScheme))
                .textSelection(.enabled)
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.codeBackground(colorScheme), in: RoundedRectangle(cornerRadius: 7))
        }
    }

    /// Inline Markdown with its code runs in the theme's code colours.
    private func styled(_ text: String) -> AttributedString {
        var attributed = HandbookMarkdown.inline(text)
        for run in attributed.runs where run.inlinePresentationIntent?.contains(.code) == true {
            attributed[run.range].foregroundColor = theme.code(colorScheme)
            attributed[run.range].backgroundColor = theme.codeBackground(colorScheme)
        }
        return attributed
    }

    /// Looks in this locale's folder first, then the base language: a screenshot only needs
    /// re-capturing when the UI in it actually differs, so an untranslated locale still shows
    /// the English figure rather than nothing.
    private func loadImage(_ source: String) -> NSImage? {
        guard let images else { return nil }
        if let image = NSImage(contentsOf: images.appending(path: source)) { return image }
        let base = images.deletingLastPathComponent().appending(path: "en/images/\(source)")
        return NSImage(contentsOf: base)
    }

    private func marker(_ symbol: String, _ text: AttributedString) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            // A bullet drawn twice the text's size reads as a mark rather than a speck; a
            // number keeps the text's size.
            Text(symbol)
                .font(.system(size: symbol == "•" ? 28 : 14))
                .baselineOffset(symbol == "•" ? -3 : 0)
                .foregroundStyle(theme.secondaryColor)
                .frame(width: 16, alignment: .trailing)
            Text(text)
                .font(.system(size: 14))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A table drawn as one: a rounded frame, the header on a faint fill, a hairline between
    /// rows, its columns laid out by ``HandbookTableLayout``.
    private func table(head: [String], rows: [[String]]) -> some View {
        HandbookTable(head: head, rows: rows)
    }
}

/// A table: a rounded frame, a filled header band and a rule between rows, its columns
/// laid out by ``HandbookTableLayout``: a column of short cells (keys, a command's name, a
/// badge) stays on one line, as it reads wrong broken; the columns of sentences share the rest
/// of the width by how much each one says, and wrap. A table never runs past its page.
private struct HandbookTable: View {
    let head: [String]
    let rows: [[String]]

    var body: some View {
        let columns = max(head.count, rows.map(\.count).max() ?? 0)
        let rule = Color.primary.opacity(0.12)
        HandbookTableLayout(columns: columns) {
            ForEach(Array(([head] + rows).enumerated()), id: \.offset) { number, cells in
                ForEach(0..<columns, id: \.self) { index in
                    Text(HandbookMarkdown.inline(index < cells.count ? cells[index] : ""))
                        .font(.system(size: 13.5, weight: number == 0 ? .semibold : .regular))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        // The header's band and the rule over each row, cell by cell: the cells
                        // of a row stand edge to edge at one height, so they read as one.
                        .background { if number == 0 { Color.primary.opacity(0.05) } }
                        .overlay(alignment: .top) { if number > 0 { rule.frame(height: 1) } }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(rule, lineWidth: 1))
    }
}

/// The table's columns and rows (1.7.0; until then every column but the last never wrapped, so
/// a long middle column took the width and the last read a word a line, or ran past the page).
///
/// Each column's natural width is its widest cell on one line. A table whose columns fit side by
/// side keeps them so, the last one taking what is left. One that does not keeps its short
/// columns, up to `shortColumn` wide, on one line, and shares the rest of the width among the
/// others by their natural widths, none under `leastColumn`; they wrap. A row is as tall as its
/// tallest cell, every cell of it laid at that height.
struct HandbookTableLayout: Layout {
    let columns: Int

    /// The widest a column stays on one line in a table too wide for its page.
    static let shortColumn: CGFloat = 200
    /// The narrowest a wrapping column is made.
    static let leastColumn: CGFloat = 120

    /// The columns' widths across `width`, from their natural widths.
    static func widths(natural: [CGFloat], width: CGFloat) -> [CGFloat] {
        guard !natural.isEmpty else { return [] }
        let total = natural.reduce(0, +)
        if total <= width {
            var widths = natural
            widths[widths.count - 1] += width - total
            return widths
        }
        let short = natural.map { $0 <= shortColumn }
        let fixed = zip(natural, short).filter(\.1).map(\.0).reduce(0, +)
        let flexible = zip(natural, short).filter { !$0.1 }.map(\.0)
        // Nothing long, or the short ones alone too wide: every column shares the width.
        guard !flexible.isEmpty, fixed < width else {
            return natural.map { width * $0 / total }
        }
        let room = width - fixed
        let wants = flexible.reduce(0, +)
        var shares = flexible.map { max(leastColumn, room * $0 / wants) }
        let over = shares.reduce(0, +) - room
        if over > 0 {
            // The least widths took more than the room: take it back from the wider ones.
            let wide = shares.filter { $0 > leastColumn }.reduce(0, +)
            if wide > 0 { shares = shares.map { $0 > leastColumn ? $0 - over * $0 / wide : $0 } }
        }
        var next = shares.makeIterator()
        return zip(natural, short).map { $0.1 ? $0.0 : (next.next() ?? 0) }
    }

    private func layout(_ subviews: Subviews, width: CGFloat) -> (widths: [CGFloat], heights: [CGFloat]) {
        guard columns > 0 else { return ([], []) }
        var natural = [CGFloat](repeating: 0, count: columns)
        for (index, cell) in subviews.enumerated() {
            natural[index % columns] = max(natural[index % columns], cell.sizeThatFits(.unspecified).width)
        }
        let widths = Self.widths(natural: natural, width: width)
        let count = (subviews.count + columns - 1) / columns
        var heights = [CGFloat](repeating: 0, count: count)
        for (index, cell) in subviews.enumerated() {
            let size = cell.sizeThatFits(ProposedViewSize(width: widths[index % columns], height: nil))
            heights[index / columns] = max(heights[index / columns], size.height)
        }
        return (widths, heights)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        if width == .infinity {
            var natural = [CGFloat](repeating: 0, count: max(columns, 1))
            for (index, cell) in subviews.enumerated() where columns > 0 {
                natural[index % columns] = max(natural[index % columns], cell.sizeThatFits(.unspecified).width)
            }
            let (_, heights) = layout(subviews, width: natural.reduce(0, +))
            return CGSize(width: natural.reduce(0, +), height: heights.reduce(0, +))
        }
        let (_, heights) = layout(subviews, width: width)
        return CGSize(width: width, height: heights.reduce(0, +))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (widths, heights) = layout(subviews, width: bounds.width)
        var y = bounds.minY
        for row in heights.indices {
            var x = bounds.minX
            for column in 0..<columns {
                let index = row * columns + column
                guard index < subviews.count else { break }
                subviews[index].place(
                    at: CGPoint(x: x, y: y), anchor: .topLeading,
                    proposal: ProposedViewSize(width: widths[column], height: heights[row]))
                x += widths[column]
            }
            y += heights[row]
        }
    }
}
