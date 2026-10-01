import AppKit
import SwiftUI
import XCTest
@testable import Handbook

/// The theme's roles and the fallback chain each one walks: a role the host pins wins, then the
/// host's accents, then a tone of the system accent. Colors are compared by their device RGB
/// components, since a derived color is a new value every time it is worked out.
final class ThemeTests: XCTestCase {
    private let brand = Color(red: 0.80, green: 0.25, blue: 0.10)
    private let second = Color(red: 0.10, green: 0.45, blue: 0.70)
    private let pinned = Color(red: 0.30, green: 0.60, blue: 0.20)

    private func rgba(_ color: Color) -> [CGFloat] {
        let ns = NSColor(color).usingColorSpace(.deviceRGB) ?? .clear
        return [ns.redComponent, ns.greenComponent, ns.blueComponent, ns.alphaComponent]
    }

    private func rgba(_ color: NSColor) -> [CGFloat] {
        let ns = color.usingColorSpace(.deviceRGB) ?? .clear
        return [ns.redComponent, ns.greenComponent, ns.blueComponent, ns.alphaComponent]
    }

    private func assertSame(_ a: Color, _ b: Color, file: StaticString = #filePath, line: UInt = #line) {
        let x = rgba(a), y = rgba(b)
        for i in 0..<4 { XCTAssertEqual(x[i], y[i], accuracy: 0.002, file: file, line: line) }
    }

    private func assertSame(_ a: Color, _ b: NSColor, file: StaticString = #filePath, line: UInt = #line) {
        let x = rgba(a), y = rgba(b)
        for i in 0..<4 { XCTAssertEqual(x[i], y[i], accuracy: 0.002, file: file, line: line) }
    }

    private func assertDiffers(_ a: Color, _ b: Color, file: StaticString = #filePath, line: UInt = #line) {
        let x = rgba(a), y = rgba(b)
        XCTAssertTrue(zip(x, y).contains { abs($0 - $1) > 0.01 }, "\(x) and \(y) are the same color",
                      file: file, line: line)
    }

    /// `color` blended toward `target` by `fraction`, the way the theme blends.
    private func blend(_ color: NSColor, _ fraction: CGFloat, toward target: NSColor) -> NSColor {
        let rgb = color.usingColorSpace(.deviceRGB)!
        return rgb.blended(withFraction: fraction, of: target)!
    }

    /// The comparisons below can fail: the fixture colors, and one color at two opacities, tell
    /// apart.
    func testColorsTellApart() {
        XCTAssertNotEqual(brand, second)
        XCTAssertNotEqual(brand, pinned)
        XCTAssertNotEqual(brand, .accentColor)
        XCTAssertNotEqual(brand.opacity(0.14), brand)
        XCTAssertNotEqual(Color.accentColor.opacity(0.08), Color.accentColor.opacity(0.10))
        assertDiffers(brand, second)
    }

    // ── The host's accent, exactly ────────────────────────────────────────────

    /// A brand color is not re-toned: the title is the accent as given, in either appearance.
    func testHeadingIsTheHostAccentExactly() {
        let theme = HandbookTheme(accent: brand)
        XCTAssertEqual(theme.heading(.light), brand)
        XCTAssertEqual(theme.heading(.dark), brand)
    }

    func testAPinnedHeadingBeatsTheAccent() {
        let theme = HandbookTheme(accent: brand, heading: pinned)
        XCTAssertEqual(theme.heading(.light), pinned)
        XCTAssertEqual(theme.heading(.dark), pinned)
    }

    func testSubheadingIsTheSecondaryAccentExactly() {
        let theme = HandbookTheme(accent: brand, secondaryAccent: second)
        XCTAssertEqual(theme.subheading(.light), second)
        XCTAssertEqual(theme.subheading(.dark), second)
    }

    // ── The secondary falls back to the primary ───────────────────────────────

    /// No secondary accent: section headings take the title's color, whatever made it.
    func testSubheadingFallsBackToTheHeading() {
        XCTAssertEqual(HandbookTheme(accent: brand).subheading(.light), brand)
        XCTAssertEqual(HandbookTheme(accent: brand, heading: pinned).subheading(.dark), pinned)
        assertSame(HandbookTheme().subheading(.dark), HandbookTheme.derivedHeading(.dark))
    }

    /// A callout's rule is the secondary accent, a shade deeper on a light page; with none, it
    /// is the link color.
    func testCalloutTakesTheSecondaryAccentElseTheLink() {
        let theme = HandbookTheme(accent: brand, secondaryAccent: second)
        XCTAssertEqual(theme.callout(.dark), second)
        assertSame(theme.callout(.light), blend(NSColor(second), 0.35, toward: .black))

        let primaryOnly = HandbookTheme(accent: brand)
        XCTAssertEqual(primaryOnly.callout(.dark), primaryOnly.link(.dark))
        assertSame(primaryOnly.callout(.light), primaryOnly.link(.light))

        let pinnedLink = HandbookTheme(accent: brand, link: pinned)
        XCTAssertEqual(pinnedLink.callout(.light), pinned)
    }

    // ── The accent as a role reads it ─────────────────────────────────────────

    /// On a dark page the accent as given; on a light one a shade deeper, so text in it keeps
    /// its contrast.
    func testAccentColorDeepensOnALightPageOnly() {
        let theme = HandbookTheme(accent: brand)
        XCTAssertEqual(theme.accentColor(.dark), brand)
        assertSame(theme.accentColor(.light), blend(NSColor(brand), 0.35, toward: .black))
        assertDiffers(theme.accentColor(.light), brand)
    }

    func testLinkSelectionAndTheirFills() {
        let theme = HandbookTheme(accent: brand)
        XCTAssertEqual(theme.link(.dark), brand)
        XCTAssertEqual(theme.selection(.dark), brand)
        XCTAssertEqual(theme.selectionBackground(.dark), brand.opacity(0.14))
        assertSame(theme.link(.light), theme.accentColor(.light))
        assertSame(theme.selection(.light), theme.accentColor(.light))

        let pinnedRoles = HandbookTheme(accent: brand, link: pinned, selection: second)
        XCTAssertEqual(pinnedRoles.link(.light), pinned)
        XCTAssertEqual(pinnedRoles.selection(.light), second)
        // The fill follows a pinned selection color, not the accent.
        XCTAssertEqual(pinnedRoles.selectionBackground(.light), second.opacity(0.14))

        let pinnedFill = HandbookTheme(accent: brand, selectionBackground: pinned)
        XCTAssertEqual(pinnedFill.selectionBackground(.dark), pinned)
    }

    /// Code is the primary accent a shade deeper, deeper still on a light page, on a pale wash of
    /// the accent.
    func testCodeIsTheAccentDeeperOnAPaleWash() {
        let theme = HandbookTheme(accent: brand, secondaryAccent: second)
        assertSame(theme.code(.dark), blend(NSColor(brand), 0.22, toward: .black))
        assertSame(theme.code(.light), blend(NSColor(brand), 0.45, toward: .black))
        XCTAssertEqual(theme.codeBackground(.dark), brand.opacity(0.08))
        XCTAssertEqual(theme.codeBackground(.light), brand.opacity(0.10))
    }

    func testBodyAndSecondaryText() {
        XCTAssertEqual(HandbookTheme().bodyColor, .primary)
        XCTAssertEqual(HandbookTheme().secondaryColor, .secondary)
        let theme = HandbookTheme(body: brand, secondary: second)
        XCTAssertEqual(theme.bodyColor, brand)
        XCTAssertEqual(theme.secondaryColor, second)
    }

    // ── No accent: the system's ───────────────────────────────────────────────

    /// The title with no accent anywhere: the system accent moved toward white on a dark page
    /// and toward black on a light one.
    func testNoAccentDerivesTheHeadingFromTheSystemAccent() {
        let theme = HandbookTheme()
        assertSame(theme.heading(.dark), blend(.controlAccentColor, 0.42, toward: .white))
        assertSame(theme.heading(.light), blend(.controlAccentColor, 0.18, toward: .black))
        assertDiffers(theme.heading(.dark), theme.heading(.light))
    }

    /// `derivedHeading` given an accent tones that accent rather than the system's.
    func testDerivedHeadingTonesTheAccentItIsGiven() {
        assertSame(HandbookTheme.derivedHeading(.dark, accent: brand), blend(NSColor(brand), 0.42, toward: .white))
        assertSame(HandbookTheme.derivedHeading(.light, accent: brand), blend(NSColor(brand), 0.18, toward: .black))
    }

    func testNoAccentLeavesEveryOtherRoleToTheSystemAccent() {
        let theme = HandbookTheme()
        XCTAssertEqual(theme.accentColor(.light), .accentColor)
        XCTAssertEqual(theme.accentColor(.dark), .accentColor)
        XCTAssertEqual(theme.link(.light), .accentColor)
        XCTAssertEqual(theme.selection(.dark), .accentColor)
        XCTAssertEqual(theme.selectionBackground(.dark), Color.accentColor.opacity(0.14))
        XCTAssertEqual(theme.callout(.light), .accentColor)
        assertSame(theme.code(.dark), blend(.controlAccentColor, 0.22, toward: .black))
        assertSame(theme.code(.light), blend(.controlAccentColor, 0.45, toward: .black))
        XCTAssertEqual(theme.codeBackground(.dark), Color.accentColor.opacity(0.08))
        XCTAssertEqual(theme.codeBackground(.light), Color.accentColor.opacity(0.10))
    }

    /// A secondary accent alone still leaves the primary roles to the system accent.
    func testASecondaryAccentAloneTouchesOnlyItsOwnRoles() {
        let theme = HandbookTheme(secondaryAccent: second)
        XCTAssertEqual(theme.subheading(.dark), second)
        XCTAssertEqual(theme.callout(.dark), second)
        XCTAssertEqual(theme.link(.dark), .accentColor)
        assertSame(theme.heading(.dark), blend(.controlAccentColor, 0.42, toward: .white))
    }

    // ── Toning ────────────────────────────────────────────────────────────────

    func testTonedDeepensOnALightPageOnly() {
        XCTAssertEqual(HandbookTheme.toned(brand, .dark), brand)
        assertSame(HandbookTheme.toned(brand, .light), blend(NSColor(brand), 0.35, toward: .black))
    }

    /// Every color starts unset, so a host that configures nothing gets the derived look.
    func testEveryRoleStartsUnset() {
        let theme = HandbookTheme()
        XCTAssertNil(theme.accent)
        XCTAssertNil(theme.secondaryAccent)
        XCTAssertNil(theme.heading)
        XCTAssertNil(theme.link)
        XCTAssertNil(theme.selection)
        XCTAssertNil(theme.selectionBackground)
        XCTAssertNil(theme.body)
        XCTAssertNil(theme.secondary)
    }
}
