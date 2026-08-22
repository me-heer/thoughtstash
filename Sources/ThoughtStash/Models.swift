import Foundation

struct StashNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var sectionID: UUID
    var createdAt = Date()
    var isDone = false
    var richTextRTF: Data?

    init(
        id: UUID = UUID(),
        text: String,
        sectionID: UUID,
        createdAt: Date = Date(),
        isDone: Bool = false,
        richTextRTF: Data? = nil
    ) {
        self.id = id
        self.text = text
        self.sectionID = sectionID
        self.createdAt = createdAt
        self.isDone = isDone
        self.richTextRTF = richTextRTF
    }

    var headline: String {
        guard let line = meaningfulLines.first?.element else { return "Untitled note" }
        return Self.cleanHeadline(line)
    }

    var bodyPreview: String {
        guard let headlineIndex = meaningfulLines.first?.offset else { return "" }
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .dropFirst(headlineIndex + 1)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var meaningfulLines: [(offset: Int, element: Substring)] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .filter { !$0.element.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private static func cleanHeadline(_ rawLine: Substring) -> String {
        var value = rawLine.trimmingCharacters(in: .whitespaces)
        if let match = value.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
            value.removeSubrange(match)
        }
        if let match = value.range(of: #"^[-*+]\s+(\[[ xX]\]\s+)?"#, options: .regularExpression) {
            value.removeSubrange(match)
        }
        return value.isEmpty ? "Untitled note" : value
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, sectionID, createdAt, isDone, richTextRTF
        case legacyHeading = "title"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sectionID = try container.decode(UUID.self, forKey: .sectionID)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false

        let savedText = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        let legacyHeading = try container.decodeIfPresent(String.self, forKey: .legacyHeading)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if legacyHeading.isEmpty {
            text = savedText
            richTextRTF = try container.decodeIfPresent(Data.self, forKey: .richTextRTF)
        } else {
            text = savedText.isEmpty ? legacyHeading : "\(legacyHeading)\n\n\(savedText)"
            // The old attributed payload contains only the body. Keeping it would hide
            // the migrated first line on rich-text display surfaces.
            richTextRTF = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(sectionID, forKey: .sectionID)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isDone, forKey: .isDone)
        try container.encodeIfPresent(richTextRTF, forKey: .richTextRTF)
    }
}

struct StashSection: Identifiable, Codable, Equatable {
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

struct StashDocument: Codable {
    var sections: [StashSection]
    var notes: [StashNote]
    var captureShortcut: CaptureShortcut
    var captureInterval: Double

    static var empty: StashDocument {
        StashDocument(
            sections: [StashSection(name: "Inbox")],
            notes: [],
            captureShortcut: .shift,
            captureInterval: 0.42
        )
    }
}
