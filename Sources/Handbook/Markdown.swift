import SwiftUI

// The Markdown subset a Handbook topic may use.
//
// Deliberately small: headings, paragraphs, bullet and numbered lists, `*term* — description`
// reference entries, tables, blockquote notes, fenced code, and figures. Anything outside it is
// a bug in the topic rather than a missing case here — a help book that needs arbitrary
// Markdown has outgrown being a help book.
//
// Only block structure is parsed. Every inline span (**bold**, *italic*, `code`, links) goes
// through AttributedString's own Markdown support.

/// One block of a topic. The set mirrors the Markdown subset build-help.py accepts — anything
/// outside it is a bug in the topic, not a missing case here.
public enum HandbookBlock: Identifiable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case note(String)                       // > blockquote
    case bullets([String])
    case numbers([String])
    case definitions([(term: String, description: String)])
    case table(head: [String], rows: [[String]])
    case code(String)
    /// Contents-page and search-result entries. A real button rather than a Markdown link:
    /// the whole row is the target, and it does not depend on intercepting `openURL`.
    case topicLinks([(id: String, title: String, summary: String)])
    /// `![caption](shot.png)` on its own line. Screenshots are per-locale, because the UI in
    /// them is localized; the renderer falls back to the base language when a locale has not
    /// been captured yet.
    case image(source: String, caption: String)

    public var id: String {
        switch self {
        case .heading(let level, let text): "h\(level):\(text)"
        case .paragraph(let text): "p:\(text.prefix(48))"
        case .note(let text): "n:\(text.prefix(48))"
        case .bullets(let items): "u:\(items.first?.prefix(32) ?? "")\(items.count)"
        case .numbers(let items): "o:\(items.first?.prefix(32) ?? "")\(items.count)"
        case .definitions(let entries): "d:\(entries.first?.term ?? "")\(entries.count)"
        case .table(let head, let rows): "t:\(head.joined())\(rows.count)"
        case .code(let text): "c:\(text.prefix(32))"
        case .topicLinks(let entries): "l:\(entries.first?.id ?? "")\(entries.count)"
        case .image(let source, _): "i:\(source)"
        }
    }
}

public struct HandbookDocument: Sendable {
    public let title: String
    public let blocks: [HandbookBlock]

    public init(title: String, blocks: [HandbookBlock]) {
        self.title = title
        self.blocks = blocks
    }
}

public enum HandbookMarkdown {
    /// Parses the same subset build-help.py renders. Kept deliberately small: a topic that
    /// needs something else should be rewritten, not accommodated here.
    public static func parse(_ markdown: String) -> HandbookDocument {
        var title = ""
        var blocks: [HandbookBlock] = []
        let lines = markdown.components(separatedBy: "\n")
        var i = 0

        func flush<T>(_ buffer: inout [T], _ make: ([T]) -> HandbookBlock) {
            if !buffer.isEmpty { blocks.append(make(buffer)); buffer.removeAll() }
        }

        var bullets: [String] = []
        var numbers: [String] = []
        var definitions: [(term: String, description: String)] = []

        func flushAll() {
            flush(&bullets) { .bullets($0) }
            flush(&numbers) { .numbers($0) }
            flush(&definitions) { .definitions($0) }
        }

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                // A blank line closes lists, but NOT a definition run: entries are separated
                // by blank lines, exactly as in the source files.
                flush(&bullets) { .bullets($0) }
                flush(&numbers) { .numbers($0) }
                i += 1
                continue
            }

            if line.hasPrefix("```") {
                flushAll()
                var body: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    body.append(lines[i])
                    i += 1
                }
                i += 1
                blocks.append(.code(body.joined(separator: "\n")))
                continue
            }

            if line.hasPrefix("!["), let close = line.firstIndex(of: "]"),
               let open = line.firstIndex(of: "("), line.hasSuffix(")") {
                flushAll()
                let caption = String(line[line.index(line.startIndex, offsetBy: 2)..<close])
                let source = String(line[line.index(after: open)..<line.index(before: line.endIndex)])
                blocks.append(.image(source: source, caption: caption))
                i += 1
                continue
            }

            if line.hasPrefix("#") {
                flushAll()
                let level = line.prefix(while: { $0 == "#" }).count
                let text = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
                if level == 1 { title = text } else { blocks.append(.heading(level: level, text: text)) }
                i += 1
                continue
            }

            if line.hasPrefix("> ") {
                flushAll()
                var body: [String] = []
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("> ") {
                    body.append(String(lines[i].trimmingCharacters(in: .whitespaces).dropFirst(2)))
                    i += 1
                }
                blocks.append(.note(body.joined(separator: " ")))
                continue
            }

            if line.hasPrefix("|") {
                flushAll()
                var rows: [[String]] = []
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    let cells = lines[i].trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                        .components(separatedBy: "|")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                    // The |---|---| separator carries no content.
                    if !cells.allSatisfy({ $0.allSatisfy { c in c == "-" || c == ":" } && !$0.isEmpty }) {
                        rows.append(cells)
                    }
                    i += 1
                }
                if let head = rows.first {
                    blocks.append(.table(head: head, rows: Array(rows.dropFirst())))
                }
                continue
            }

            // `*term* — description`, the reference-entry pattern.
            if let match = definitionEntry(line) {
                flush(&bullets) { .bullets($0) }
                flush(&numbers) { .numbers($0) }
                definitions.append(match)
                i += 1
                continue
            }

            if line.hasPrefix("- ") || (line.hasPrefix("* ") && !line.hasPrefix("**")) {
                flush(&numbers) { .numbers($0) }
                flush(&definitions) { .definitions($0) }
                bullets.append(String(line.dropFirst(2)))
                i += 1
                continue
            }

            if let dot = line.firstIndex(of: "."), line[line.startIndex..<dot].allSatisfy(\.isNumber),
               line.index(after: dot) < line.endIndex, line[line.index(after: dot)] == " " {
                flush(&bullets) { .bullets($0) }
                flush(&definitions) { .definitions($0) }
                numbers.append(String(line[line.index(dot, offsetBy: 2)...]))
                i += 1
                continue
            }

            flushAll()
            var paragraph = [line]
            i += 1
            while i < lines.count {
                let next = lines[i].trimmingCharacters(in: .whitespaces)
                if next.isEmpty || next.hasPrefix("#") || next.hasPrefix("- ") || next.hasPrefix("> ")
                    || next.hasPrefix("|") || next.hasPrefix("```") || definitionEntry(next) != nil {
                    break
                }
                paragraph.append(next)
                i += 1
            }
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
        }

        flushAll()
        return HandbookDocument(title: title, blocks: blocks)
    }

    private static func definitionEntry(_ line: String) -> (term: String, description: String)? {
        guard line.hasPrefix("*"), !line.hasPrefix("**") else { return nil }
        let rest = line.dropFirst()
        guard let close = rest.firstIndex(of: "*") else { return nil }
        let term = String(rest[rest.startIndex..<close])
        let after = rest[rest.index(after: close)...].trimmingCharacters(in: .whitespaces)
        guard after.hasPrefix("—") else { return nil }
        return (term, String(after.dropFirst()).trimmingCharacters(in: .whitespaces))
    }

    /// Inline spans, via AttributedString's own Markdown parsing. `.inlineOnlyPreservingWhitespace`
    /// keeps a stray list marker inside a sentence from being read as structure.
    public static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

