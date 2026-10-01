import XCTest
@testable import Handbook

/// What a host gets when it configures nothing, and the language picker's rule.
final class ConfigurationTests: XCTestCase {
    func testDefaults() {
        let configuration = HandbookConfiguration()
        XCTAssertEqual(configuration.bundle, .main)
        XCTAssertEqual(configuration.topicsDirectory, "topics")
        XCTAssertEqual(configuration.chromeDirectory, "chrome")
        XCTAssertEqual(configuration.fallbackLanguage, "en")
        XCTAssertTrue(configuration.sidebarWrapsTitles)
        guard case .automatic = configuration.languagePicker else {
            return XCTFail("expected the automatic picker")
        }
    }

    /// Titles wrap unless the host says otherwise.
    func testSidebarWrapsTitlesUnlessTurnedOff() {
        XCTAssertTrue(HandbookConfiguration().sidebarWrapsTitles)
        XCTAssertFalse(HandbookConfiguration(sidebarWrapsTitles: false).sidebarWrapsTitles)
    }

    func testIconsDefaultToSymbols() {
        let icons = HandbookIcons()
        XCTAssertEqual(icons.sidebar, "sidebar.leading")
        XCTAssertEqual(icons.back, "chevron.backward")
        XCTAssertEqual(icons.forward, "chevron.forward")
        XCTAssertEqual(icons.home, "house")
        XCTAssertEqual(icons.search, "magnifyingglass")
        XCTAssertEqual(icons.clear, "xmark.circle.fill")
        XCTAssertEqual(icons.scale, 1)
    }

    /// A picker with a single choice is a control that does nothing, so `automatic` shows it
    /// only past one language.
    func testLanguagePickerVisibility() {
        for count in [0, 1, 2, 5] {
            XCTAssertEqual(HandbookLanguagePicker.automatic.isVisible(languageCount: count), count > 1)
            XCTAssertTrue(HandbookLanguagePicker.always.isVisible(languageCount: count))
            XCTAssertFalse(HandbookLanguagePicker.never.isVisible(languageCount: count))
        }
    }
}
