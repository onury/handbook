import SwiftUI

/// Where a help book's content lives, and how it looks.
///
/// The content is Markdown that ships with the *app*, not with this package: topics under
/// `<topics>/<locale>/`, and one `<chrome>/<locale>.json` per locale carrying the contents-page
/// copy and the window's own labels. See the README for the file layout.
public struct HandbookConfiguration: Sendable {
    /// The bundle holding the help resources. Defaults to the app's.
    public var bundle: Bundle
    /// Folder-reference name for the topic directories.
    public var topicsDirectory: String
    /// Folder-reference name for the per-locale chrome files.
    public var chromeDirectory: String
    /// The language used when the reader's own is not among the ones shipped.
    public var fallbackLanguage: String
    /// Whether the toolbar offers a language selector.
    public var languagePicker: HandbookLanguagePicker
    public var theme: HandbookTheme

    public init(bundle: Bundle = .main,
                topicsDirectory: String = "topics",
                chromeDirectory: String = "chrome",
                fallbackLanguage: String = "en",
                languagePicker: HandbookLanguagePicker = .automatic,
                theme: HandbookTheme = HandbookTheme()) {
        self.bundle = bundle
        self.topicsDirectory = topicsDirectory
        self.chromeDirectory = chromeDirectory
        self.fallbackLanguage = fallbackLanguage
        self.languagePicker = languagePicker
        self.theme = theme
    }
}

/// When the toolbar shows its language selector.
public enum HandbookLanguagePicker: Sendable {
    /// Shown only when the book ships more than one language — a picker with a single choice
    /// is a control that does nothing.
    case automatic
    /// Always shown, even with one language.
    case always
    /// Never shown. The book still opens in the reader's language; they just cannot change it
    /// independently of the app.
    case never

    func isVisible(languageCount: Int) -> Bool {
        switch self {
        case .automatic: languageCount > 1
        case .always: true
        case .never: false
        }
    }
}

/// The colours the help window uses.
///
/// Every one defaults to `nil`, meaning "derive it from the system accent" — so a host app that
/// sets nothing follows whatever accent the reader chose in System Settings. Set any of them to
/// pin that role to a brand colour instead.
public struct HandbookTheme: Sendable {
    /// Titles and section headings. Default: the accent, lightened, so headings lead the page
    /// without competing with the body text.
    public var heading: Color?
    /// Inline links, and the topic titles on the contents page.
    public var link: Color?
    /// The selected row in the sidebar — its text.
    public var selection: Color?
    /// The selected row's fill. Default: the selection colour at low opacity.
    public var selectionBackground: Color?
    /// Body text. Default: the system's primary label colour.
    public var body: Color?
    /// Captions, summaries, note text. Default: the system's secondary label colour.
    public var secondary: Color?

    public init(heading: Color? = nil,
                link: Color? = nil,
                selection: Color? = nil,
                selectionBackground: Color? = nil,
                body: Color? = nil,
                secondary: Color? = nil) {
        self.heading = heading
        self.link = link
        self.selection = selection
        self.selectionBackground = selectionBackground
        self.body = body
        self.secondary = secondary
    }

    // ── Resolution ────────────────────────────────────────────────────────────
    // Each role falls back to a value derived from the system accent, so an app that
    // configures nothing still looks deliberate rather than default-blue-on-everything.

    /// The accent, moved toward white on a dark page and toward black on a light one: the same
    /// hue either way, still recognisably the accent, never a wash.
    static func derivedHeading(_ scheme: ColorScheme) -> Color {
        let accent = NSColor.controlAccentColor.usingColorSpace(.deviceRGB) ?? .systemBlue
        let target: NSColor = scheme == .dark ? .white : .black
        let fraction: CGFloat = scheme == .dark ? 0.42 : 0.18
        return Color(nsColor: accent.blended(withFraction: fraction, of: target) ?? accent)
    }

    func heading(_ scheme: ColorScheme) -> Color { heading ?? Self.derivedHeading(scheme) }
    func link(_ scheme: ColorScheme) -> Color { link ?? .accentColor }
    func selection(_ scheme: ColorScheme) -> Color { selection ?? .accentColor }
    func selectionBackground(_ scheme: ColorScheme) -> Color {
        selectionBackground ?? (selection ?? .accentColor).opacity(0.14)
    }
    var bodyColor: Color { body ?? .primary }
    var secondaryColor: Color { secondary ?? .secondary }
}

/// The one way anything outside the help window asks it to open — the Help menu's search
/// results, a "What's this?" button, a keyboard shortcut.
@MainActor
@Observable
public final class HandbookLauncher {
    public static let shared = HandbookLauncher()

    /// Installed by the host app, which is the only place with a SwiftUI `openWindow` to
    /// capture. Without it, nothing outside the window can open it.
    public var openWindow: (() -> Void)?

    /// Set just before opening and cleared by the window as it reads them.
    public internal(set) var pendingTopic: String?
    public internal(set) var pendingSearch: String?

    private init() {}

    /// Opens the book, optionally on a specific topic (the file name without `.md`).
    public func open(topic: String? = nil) {
        pendingTopic = topic
        openWindow?()
    }

    /// Opens the book showing results for a query.
    public func open(search: String) {
        pendingSearch = search
        openWindow?()
    }
}
