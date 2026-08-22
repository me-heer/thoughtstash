import AppKit
import XCTest
@testable import ThoughtStash

@MainActor
final class StashStoreTests: XCTestCase {
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

    func testNotesPersistAndReload() {
        let store = StashStore(fileURL: fileURL)
        store.addNote("First prompt")
        store.addNote("Second prompt")

        let reloaded = StashStore(fileURL: fileURL)

        XCTAssertEqual(reloaded.notes.map(\.text), ["Second prompt", "First prompt"])
    }

    func testMergeCombinesSelectedNotesChronologically() throws {
        let store = StashStore(fileURL: fileURL)
        store.addNote("First")
        store.addNote("Second")
        let ids = Set(store.notes.map(\.id))

        let mergedID = try XCTUnwrap(store.merge(ids))

        XCTAssertEqual(store.notes.count, 1)
        XCTAssertEqual(store.notes.first?.id, mergedID)
        XCTAssertEqual(store.notes.first?.text, "First\n\nSecond")
    }

    func testDeletingSectionMovesNotesToRemainingSection() throws {
        let store = StashStore(fileURL: fileURL)
        store.addSection(named: "Research")
        let researchID = try XCTUnwrap(store.sections.last?.id)
        store.addNote("Keep this", sectionID: researchID)

        store.deleteSection(researchID)

        XCTAssertEqual(store.sections.count, 1)
        XCTAssertEqual(store.notes.first?.sectionID, store.sections[0].id)
    }

    func testFirstMeaningfulLineProvidesHeadlineAndRemainingBody() throws {
        let store = StashStore(fileURL: fileURL)
        store.addNote("# Launch plan\n\nThis is **important**.")

        let note = try XCTUnwrap(store.notes.first)

        XCTAssertEqual(note.headline, "Launch plan")
        XCTAssertEqual(note.bodyPreview, "This is **important**.")
    }

    func testLegacyHeadingMigratesIntoCanonicalTextOnce() throws {
        let sectionID = UUID()
        let noteID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let json: [String: Any] = [
            "sections": [["id": sectionID.uuidString, "name": "Inbox"]],
            "notes": [[
                "id": noteID.uuidString,
                "text": "This is **important**.",
                "sectionID": sectionID.uuidString,
                "createdAt": createdAt.timeIntervalSinceReferenceDate,
                "isDone": true,
                "title": "Launch plan",
                "richTextRTF": Data("body-only".utf8).base64EncodedString()
            ]],
            "captureShortcut": "shift",
            "captureInterval": 0.42
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        try data.write(to: fileURL)

        let store = StashStore(fileURL: fileURL)
        let migrated = try XCTUnwrap(store.notes.first)
        XCTAssertEqual(migrated.id, noteID)
        XCTAssertEqual(migrated.createdAt, createdAt)
        XCTAssertTrue(migrated.isDone)
        XCTAssertEqual(migrated.text, "Launch plan\n\nThis is **important**.")
        XCTAssertNil(migrated.richTextRTF)

        store.updateNote(id: migrated.id, text: migrated.text)
        let reloaded = StashStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.notes.first?.text, "Launch plan\n\nThis is **important**.")
    }

    func testRichTextPersistsAndIsClearedByPlainTextEdit() throws {
        let richText = NSAttributedString(
            string: "Formatted",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]
        )
        let rtf = try XCTUnwrap(RichTextCodec.rtfData(from: richText))
        let store = StashStore(fileURL: fileURL)
        store.addNote("Formatted", richTextRTF: rtf)

        let reloaded = StashStore(fileURL: fileURL)
        let note = try XCTUnwrap(reloaded.notes.first)
        XCTAssertNotNil(note.richTextRTF)

        reloaded.updateNote(id: note.id, text: "Plain")
        XCTAssertNil(reloaded.notes.first?.richTextRTF)
    }
}
