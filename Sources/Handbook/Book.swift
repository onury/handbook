import SwiftUI

/// The contents-page copy and window labels for one language, read from
/// `<chrome>/<locale>.json`. Everything a translator touches lives in this one file.
public struct HandbookChrome: Decodable, Sendable {
    /// The window's own labels.
    public struct UI: Decodable, Sendable {
        public let home, back, forward, contents, searchPlaceholder, clear, languageLabel: String
        public let resultsFor, noResults, unavailableTitle, unavailableMessage: String
    }

    public let ui: UI
    /// The book's name, shown in the toolbar.
    public let bookTitle: String
    /// The paragraph under the title on the contents page.
    public let intro: String
    /// A callout under the intro. Markdown; may be empty.
    public let note: String
    /// A one-line description, for search engines and metadata.
    public let indexDescription: String
    /// Topic id → the one-line summary under its contents-page entry.
    public let summaries: [String: String]
    /// Topic ids, in contents order.
    public let order: [String]
}

/// A book in one language: its topics directory and its chrome.
public struct HandbookBook: Sendable {
    public let language: String
    /// `<topics>/<language>`, where the Markdown lives.
    public let topics: URL
    public let chrome: HandbookChrome

    /// Screenshots for this language, falling back to the base language per figure.
    public var images: URL { topics.appending(path: "images") }

    public func markdown(for topic: String) -> String? {
        try? String(contentsOf: topics.appending(path: "\(topic).md"), encoding: .utf8)
    }

    // ── Lookup ────────────────────────────────────────────────────────────────

    /// Every language shipping BOTH topics and chrome, read off the bundle rather than
    /// hard-coded — a locale appears the moment its files are there, and never before.
    public static func available(_ configuration: HandbookConfiguration) -> [String] {
        guard let root = topicsRoot(configuration),
              let entries = try? FileManager.default.contentsOfDirectory(atPath: root.path)
        else { return [] }
        return entries
            .filter { book(for: $0, configuration) != nil }
            .sorted { name(for: $0).localizedCompare(name(for: $1)) == .orderedAscending }
    }

    public static func book(for language: String,
                            _ configuration: HandbookConfiguration) -> HandbookBook? {
        guard let root = topicsRoot(configuration),
              let chromeRoot = configuration.bundle.url(
                  forResource: configuration.chromeDirectory, withExtension: nil)
        else { return nil }
        let directory = root.appending(path: language)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              let data = try? Data(contentsOf: chromeRoot.appending(path: "\(language).json")),
              let chrome = try? JSONDecoder().decode(HandbookChrome.self, from: data)
        else { return nil }
        return HandbookBook(language: language, topics: directory, chrome: chrome)
    }

    /// The book for the app's current language. `preferredLocalizations` is the point: it
    /// follows an in-app language override (which writes `AppleLanguages` into the app's own
    /// defaults domain), so the help matches the app rather than the system.
    public static func preferred(_ configuration: HandbookConfiguration) -> HandbookBook? {
        for language in configuration.bundle.preferredLocalizations + [configuration.fallbackLanguage] {
            if let book = book(for: language, configuration) { return book }
        }
        return nil
    }

    /// Each language named in ITSELF — a reader looking for Turkish scans for "Türkçe", not for
    /// whatever the current interface language calls it.
    public static func name(for language: String) -> String {
        let locale = Locale(identifier: language)
        let raw = locale.localizedString(forIdentifier: language) ?? language
        // Uppercased IN that locale: Turkish maps i to İ, so a locale-blind uppercase would
        // spell its own language's name wrong.
        return raw.prefix(1).uppercased(with: locale) + raw.dropFirst()
    }

    private static func topicsRoot(_ configuration: HandbookConfiguration) -> URL? {
        configuration.bundle.url(forResource: configuration.topicsDirectory, withExtension: nil)
    }
}

/// A topic reduced to what search needs.
public struct HandbookTopic: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let sections: [String]
    public let text: String
}
