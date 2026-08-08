import XCTest
@testable import Handbook

/// The parser is the part with real behaviour and no UI, so it is the part worth testing.
final class MarkdownTests: XCTestCase {
    func testTitleComesFromTheSingleH1() {
        let document = HandbookMarkdown.parse("# Quick Start\n\nSome prose.")
        XCTAssertEqual(document.title, "Quick Start")
        XCTAssertEqual(document.blocks.count, 1)
    }

    func testParagraphsJoinSoftWrappedLines() {
        let document = HandbookMarkdown.parse("# T\n\nOne line\nand its continuation.")
        guard case .paragraph(let text)? = document.blocks.first else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertEqual(text, "One line and its continuation.")
    }

    func testDefinitionEntriesGroupIntoOneList() {
        let source = """
        # T

        *Tolerance* — How far from the key color still counts as background.

        *Smoothness* — The width of the transition.
        """
        guard case .definitions(let entries)? = HandbookMarkdown.parse(source).blocks.first else {
            return XCTFail("expected a definition list")
        }
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.term, "Tolerance")
    }

    /// A blank line separates definition entries in the source, so it must NOT close the list —
    /// closing there emits a separate one-entry list per entry.
    func testBlankLinesDoNotSplitDefinitionLists() {
        let source = "# T\n\n*A* — one.\n\n*B* — two.\n\n*C* — three."
        let lists = HandbookMarkdown.parse(source).blocks.filter {
            if case .definitions = $0 { return true } else { return false }
        }
        XCTAssertEqual(lists.count, 1)
    }

    func testTableDropsTheSeparatorRow() {
        let source = "# T\n\n| Shortcut | Command |\n|---|---|\n| ⌘O | Open |\n| ⌘E | Export |"
        guard case .table(let head, let rows)? = HandbookMarkdown.parse(source).blocks.first else {
            return XCTFail("expected a table")
        }
        XCTAssertEqual(head, ["Shortcut", "Command"])
        XCTAssertEqual(rows.count, 2)
    }

    func testKeyboardSymbolsSurviveVerbatim() {
        let source = "# T\n\n| Key | What |\n|---|---|\n| ⇧⌘C | Copy Result |"
        guard case .table(_, let rows)? = HandbookMarkdown.parse(source).blocks.first else {
            return XCTFail("expected a table")
        }
        XCTAssertEqual(rows.first?.first, "⇧⌘C")
    }

    func testBlockquoteBecomesANote() {
        let document = HandbookMarkdown.parse("# T\n\n> Every control explains itself.")
        guard case .note(let text)? = document.blocks.first else {
            return XCTFail("expected a note")
        }
        XCTAssertEqual(text, "Every control explains itself.")
    }

    func testFencedCodeKeepsItsLineBreaks() {
        let document = HandbookMarkdown.parse("# T\n\n```\none\ntwo\n```")
        guard case .code(let text)? = document.blocks.first else {
            return XCTFail("expected code")
        }
        XCTAssertEqual(text, "one\ntwo")
    }

    func testFigureParsesSourceAndCaption() {
        let document = HandbookMarkdown.parse("# T\n\n![The export sheet.](export.png)")
        guard case .image(let source, let caption)? = document.blocks.first else {
            return XCTFail("expected an image")
        }
        XCTAssertEqual(source, "export.png")
        XCTAssertEqual(caption, "The export sheet.")
    }

    /// `**bold**` at the start of a line must not be read as a bullet or a definition term.
    func testBoldLeadingSpanIsNotMistakenForStructure() {
        let document = HandbookMarkdown.parse("# T\n\n**Use it when** you shot against a backdrop.")
        guard case .paragraph? = document.blocks.first else {
            return XCTFail("expected a paragraph, got \(String(describing: document.blocks.first))")
        }
    }

    func testNumberedAndBulletListsStaySeparate() {
        let source = "# T\n\n1. First\n2. Second\n\n- One\n- Two"
        let blocks = HandbookMarkdown.parse(source).blocks
        guard case .numbers(let numbers)? = blocks.first else { return XCTFail("expected numbers") }
        guard case .bullets(let bullets)? = blocks.last else { return XCTFail("expected bullets") }
        XCTAssertEqual(numbers.count, 2)
        XCTAssertEqual(bullets.count, 2)
    }

    func testLanguageNamesUseTheirOwnLocale() {
        // Turkish uppercases i to İ; a locale-blind uppercase spells its own name wrong.
        XCTAssertEqual(HandbookBook.name(for: "tr"), "Türkçe")
        XCTAssertEqual(HandbookBook.name(for: "en"), "English")
    }
}
