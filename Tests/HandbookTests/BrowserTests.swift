import XCTest
@testable import Handbook

/// The window's model over a book laid out on disk: which languages count, back and forward
/// over topics, a language switch that keeps the reader's place and costs no step, and search
/// ranked title, then section, then prose.
@MainActor
final class BrowserTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "handbook-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try write("topics/en/export.md", "# Export\n\nFormats and sizing.\n\n## Encoders\n\nHEIC and PNG.")
        try write("topics/en/masks.md", "# Masks\n\nRefine the edge. You can export the mask alone.")
        try write("topics/en/encoders.md", "# Encoders\n\nWhich encoder to pick.")
        try write("chrome/en.json", chrome(title: "Help", order: ["export", "masks", "encoders"]))
        try write("topics/tr/export.md", "# Dışa Aktar\n\nBiçimler.")
        try write("topics/tr/masks.md", "# Maskeler\n\nKenar.")
        try write("chrome/tr.json", chrome(title: "Yardım", order: ["export", "masks"]))
        // Topics with no chrome: not a language yet.
        try write("topics/de/export.md", "# Exportieren")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ path: String, _ text: String) throws {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func chrome(title: String, order: [String]) -> String {
        let ui = ["home", "back", "forward", "contents", "searchPlaceholder", "clear", "languageLabel",
                  "noResults", "unavailableTitle", "unavailableMessage"]
            .map { "\"\($0)\": \"\($0)\"" }.joined(separator: ", ")
        let ids = order.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        { "bookTitle": "\(title)", "intro": "Intro.", "note": "", "indexDescription": "",
          "order": [\(ids)], "summaries": { "export": "Out." },
          "ui": { \(ui), "resultsFor": "Results for %@" } }
        """
    }

    private func browser(_ language: String = "en") throws -> HandbookBrowser {
        let bundle = try XCTUnwrap(Bundle(url: root))
        return HandbookBrowser(configuration: HandbookConfiguration(bundle: bundle, fallbackLanguage: language))
    }

    func testOnlyLanguagesWithTopicsAndChromeCount() throws {
        let bundle = try XCTUnwrap(Bundle(url: root))
        XCTAssertEqual(Set(HandbookBook.available(HandbookConfiguration(bundle: bundle))), ["en", "tr"])
        XCTAssertNil(HandbookBook.book(for: "de", HandbookConfiguration(bundle: bundle)))
    }

    func testBackAndForwardWalkTopics() throws {
        let browser = try browser()
        browser.start()
        XCTAssertNil(browser.currentTopic)
        XCTAssertEqual(browser.document?.title, "Help")
        XCTAssertFalse(browser.canGoBack)

        browser.open(topic: "export")
        browser.open(topic: "masks")
        XCTAssertEqual(browser.document?.title, "Masks")
        XCTAssertTrue(browser.canGoBack)
        XCTAssertFalse(browser.canGoForward)

        browser.goBack()
        XCTAssertEqual(browser.currentTopic, "export")
        XCTAssertTrue(browser.canGoForward)
        // A new destination drops what was ahead, as a browser does.
        browser.open(topic: "encoders")
        XCTAssertFalse(browser.canGoForward)
        browser.goBack()
        browser.goBack()
        XCTAssertNil(browser.currentTopic)
        XCTAssertFalse(browser.canGoBack)
        browser.goBack()
        XCTAssertNil(browser.currentTopic)
    }

    /// Opening the topic already shown is no step.
    func testOpeningTheSameTopicAgainAddsNoStep() throws {
        let browser = try browser()
        browser.start()
        browser.open(topic: "export")
        browser.open(topic: "export")
        browser.goBack()
        XCTAssertNil(browser.currentTopic)
    }

    func testALanguageSwitchKeepsTheTopicAndCostsNoStep() throws {
        let browser = try browser()
        XCTAssertEqual(browser.language, "en")
        browser.start()
        browser.open(topic: "masks")
        browser.select(language: "tr")
        XCTAssertEqual(browser.language, "tr")
        XCTAssertEqual(browser.currentTopic, "masks")
        XCTAssertEqual(browser.document?.title, "Maskeler")
        browser.goBack()
        XCTAssertNil(browser.currentTopic)
        XCTAssertEqual(browser.document?.title, "Yardım")
    }

    /// A topic the other language lacks shows that language's contents page.
    func testALanguageWithoutTheTopicShowsItsContents() throws {
        let browser = try browser()
        browser.start()
        browser.open(topic: "encoders")
        browser.select(language: "tr")
        XCTAssertEqual(browser.document?.title, "Yardım")
    }

    /// A title hit beats a section heading, which beats prose; the title hit carries the summary
    /// and the section hit its heading.
    func testSearchRanksTitleThenSectionThenProse() throws {
        let browser = try browser()
        browser.start()
        browser.query = " export "
        browser.runSearch()
        XCTAssertEqual(browser.document?.title, "Results for export")
        guard case .topicLinks(let hits)? = browser.document?.blocks.first else {
            return XCTFail("expected results")
        }
        XCTAssertEqual(hits.map(\.id), ["export", "masks"])
        XCTAssertEqual(hits.first?.summary, "Out.")

        browser.query = "encoders"
        browser.runSearch()
        guard case .topicLinks(let ranked)? = browser.document?.blocks.first else {
            return XCTFail("expected results")
        }
        XCTAssertEqual(ranked.map(\.id), ["encoders", "export"])
        XCTAssertEqual(ranked.last?.summary, "Encoders")
    }

    func testNoMatchSaysSoAndAnEmptyQueryGoesHome() throws {
        let browser = try browser()
        browser.start()
        browser.open(topic: "masks")
        browser.query = "zebra"
        browser.runSearch()
        guard case .paragraph(let text)? = browser.document?.blocks.first else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertEqual(text, "noResults")

        browser.query = "   "
        browser.runSearch()
        XCTAssertNil(browser.currentTopic)
        XCTAssertEqual(browser.document?.title, "Help")
    }
}
