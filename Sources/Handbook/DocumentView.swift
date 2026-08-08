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
    /// Tapping a topic link. Targets arrive as file names (`matte-engines.html`), the same
    /// way they are written in the Markdown.
    var onOpen: (String) -> Void = { _ in }

    public init(document: HandbookDocument,
                theme: HandbookTheme = HandbookTheme(),
                images: URL? = nil,
                topInset: CGFloat = 0,
                onOpen: @escaping (String) -> Void = { _ in }) {
        self.document = document
        self.theme = theme
        self.images = images
        self.topInset = topInset
        self.onOpen = onOpen
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(HandbookMarkdown.inline(document.title))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(theme.heading(colorScheme))
                    .padding(.bottom, 2)

                ForEach(document.blocks) { block in
                    view(for: block)
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 34)
            .padding(.bottom, 30)
            .padding(.top, topInset + 24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .environment(\.openURL, OpenURLAction { url in
            // Topic links are relative file names; anything absolute belongs to the browser.
            let target = url.absoluteString
            guard !target.hasPrefix("http") else { return .systemAction }
            onOpen(URL(fileURLWithPath: target).deletingPathExtension().lastPathComponent)
            return .handled
        })
    }

    @ViewBuilder
    private func view(for block: HandbookBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(HandbookMarkdown.inline(text))
                .font(.system(size: level == 2 ? 19 : 16, weight: .semibold))
                .foregroundStyle(theme.heading(colorScheme))
                .padding(.top, level == 2 ? 14 : 8)

        case .paragraph(let text):
            Text(HandbookMarkdown.inline(text))
                .font(.system(size: 14))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

        case .note(let text):
            HStack(alignment: .top, spacing: 12) {
                // The stylesheet's left rule, which is what makes a note read as an aside
                // rather than another paragraph.
                Rectangle()
                    .fill(theme.link(colorScheme).opacity(0.55))
                    .frame(width: 3)
                Text(HandbookMarkdown.inline(text))
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(theme.secondaryColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    marker("•", HandbookMarkdown.inline(item))
                }
            }

        case .numbers(let items):
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    marker("\(index + 1).", HandbookMarkdown.inline(item))
                }
            }

        case .definitions(let entries):
            VStack(alignment: .leading, spacing: 11) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(HandbookMarkdown.inline(entry.term))
                            .font(.system(size: 14, weight: .semibold))
                        Text(HandbookMarkdown.inline(entry.description))
                            .font(.system(size: 14))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .table(let head, let rows):
            VStack(alignment: .leading, spacing: 0) {
                tableRow(head, weight: .semibold)
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    tableRow(row, weight: .regular)
                }
            }
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
                                Text(HandbookMarkdown.inline(entry.summary))
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
                        Text(HandbookMarkdown.inline(caption))
                            .font(.system(size: 12.5))
                            .foregroundStyle(theme.secondaryColor)
                    }
                }
                .padding(.vertical, 4)
            }

        case .code(let text):
            Text(text)
                .font(.system(size: 12.5, design: .monospaced))
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
        }
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
            Text(symbol)
                .font(.system(size: 14))
                .foregroundStyle(theme.secondaryColor)
                .frame(width: 16, alignment: .trailing)
            Text(text)
                .font(.system(size: 14))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tableRow(_ cells: [String], weight: Font.Weight) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                Text(HandbookMarkdown.inline(cell))
                    .font(.system(size: 13.5, weight: weight))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // The shortcut column is narrow and fixed; the description takes the rest.
                    .frame(width: index == 0 && cells.count == 2 ? 92 : nil, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 5)
    }
}
