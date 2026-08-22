import AppKit
import XCTest
@testable import ThoughtStash

@MainActor
final class AppFontThemeTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        fileURL = temporaryDirectory.appendingPathComponent("notes.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testCyclingWrapsThroughAllThreeFontsAndPersists() {
        let store = StashStore(fileURL: fileURL)
        XCTAssertEqual(store.fontTheme, .sans)

        XCTAssertEqual(store.cycleFontTheme(), .serif)
        XCTAssertEqual(store.cycleFontTheme(), .mono)
        XCTAssertEqual(store.cycleFontTheme(), .sans)

        store.setFontTheme(.serif)
        XCTAssertEqual(StashStore(fileURL: fileURL).fontTheme, .serif)
    }

    func testDocumentsSavedBeforeTheFontSettingStillDecode() throws {
        let legacy = """
        {
          "captureInterval": 0.42,
          "captureShortcut": "shift",
          "notes": [],
          "sections": [{"id": "\(UUID().uuidString)", "name": "Inbox"}]
        }
        """
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        try Data(legacy.utf8).write(to: fileURL)

        let store = StashStore(fileURL: fileURL)

        XCTAssertEqual(store.sections.map(\.name), ["Inbox"])
        XCTAssertEqual(store.fontTheme, .sans)
    }

    func testEachThemeResolvesADistinctSystemFont() {
        let names = AppFontTheme.allCases.map { $0.nsFont(size: 16).fontName }

        XCTAssertEqual(Set(names).count, AppFontTheme.allCases.count, "themes resolved to \(names)")
    }

    func testCycleFontShortcutIsCommandShiftT() {
        let entry = ShortcutMap.matchingEntry(
            keyCode: 17,
            charactersIgnoringModifiers: "t",
            modifierFlags: [.command, .shift]
        )

        XCTAssertEqual(entry?.slug, "cycleFont")
        XCTAssertEqual(ShortcutMap.entry(slug: "cycleFont")?.displayString, "⇧⌘T")
    }
}
