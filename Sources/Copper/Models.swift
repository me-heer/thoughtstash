import Foundation

struct CopperNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var sectionID: UUID
    var createdAt = Date()
    var isDone = false
}

struct CopperSection: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
}

enum CaptureShortcut: String, Codable, CaseIterable, Identifiable {
    case shift
    case option
    case control
    case command

    var id: Self { self }
    var title: String { "Double \(rawValue.capitalized)" }
}

struct CopperDocument: Codable {
    var sections: [CopperSection]
    var notes: [CopperNote]
    var captureShortcut: CaptureShortcut
    var captureInterval: Double

    static var empty: CopperDocument {
        CopperDocument(
            sections: [CopperSection(name: "Inbox")],
            notes: [],
            captureShortcut: .shift,
            captureInterval: 0.42
        )
    }
}
