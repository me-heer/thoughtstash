import XCTest
@testable import Copper

@MainActor
final class CopperStoreTests: XCTestCase {
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
        let store = CopperStore(fileURL: fileURL)
        store.addNote("First prompt")
        store.addNote("Second prompt")

        let reloaded = CopperStore(fileURL: fileURL)

        XCTAssertEqual(reloaded.notes.map(\.text), ["Second prompt", "First prompt"])
    }

    func testMergeCombinesSelectedNotesChronologically() throws {
        let store = CopperStore(fileURL: fileURL)
        store.addNote("First")
        store.addNote("Second")
        let ids = Set(store.notes.map(\.id))

        let mergedID = try XCTUnwrap(store.merge(ids))

        XCTAssertEqual(store.notes.count, 1)
        XCTAssertEqual(store.notes.first?.id, mergedID)
        XCTAssertEqual(store.notes.first?.text, "First\n\nSecond")
    }

    func testDeletingSectionMovesNotesToRemainingSection() throws {
        let store = CopperStore(fileURL: fileURL)
        store.addSection(named: "Research")
        let researchID = try XCTUnwrap(store.sections.last?.id)
        store.addNote("Keep this", sectionID: researchID)

        store.deleteSection(researchID)

        XCTAssertEqual(store.sections.count, 1)
        XCTAssertEqual(store.notes.first?.sectionID, store.sections[0].id)
    }
}
