import SwiftUI

struct MarkdownPreview: View {
    let markdown: String
    var compact = false

    var body: some View {
        LazyVStack(alignment: .leading, spacing: compact ? 5 : 10) {
            ForEach(Array(MarkdownBlock.parse(markdown).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(.init(text))
                .font(headingFont(level: level))
                .fontWeight(.semibold)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").foregroundStyle(.secondary)
                Text(.init(text))
            }
        case .numbered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number).").foregroundStyle(.secondary)
                Text(.init(text))
            }
        case .quote(let text):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(.secondary.opacity(0.35))
                    .frame(width: 3)
                Text(.init(text)).foregroundStyle(.secondary)
            }
        case .code(let text):
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        case .paragraph(let text):
            Text(.init(text))
        }
    }

    private func headingFont(level: Int) -> Font {
        if compact {
            return level == 1 ? .headline : (level == 2 ? .subheadline : .body)
        }
        return level == 1 ? .title : (level == 2 ? .title2 : .headline)
    }
}

private enum MarkdownBlock {
    case heading(Int, String)
    case bullet(String)
    case numbered(Int, String)
    case quote(String)
    case code(String)
    case paragraph(String)

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var result: [MarkdownBlock] = []
        var paragraph: [String] = []
        var code: [String] = []
        var inCodeBlock = false

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            result.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph.removeAll()
        }

        for line in markdown.components(separatedBy: .newlines) {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    result.append(.code(code.joined(separator: "\n")))
                    code.removeAll()
                } else {
                    flushParagraph()
                }
                inCodeBlock.toggle()
                continue
            }
            if inCodeBlock {
                code.append(line)
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                flushParagraph()
                continue
            }
            if let heading = heading(from: trimmed) {
                flushParagraph()
                result.append(heading)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph()
                result.append(.bullet(String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("> ") {
                flushParagraph()
                result.append(.quote(String(trimmed.dropFirst(2))))
            } else if let numbered = numbered(from: trimmed) {
                flushParagraph()
                result.append(numbered)
            } else {
                paragraph.append(trimmed)
            }
        }
        flushParagraph()
        if !code.isEmpty { result.append(.code(code.joined(separator: "\n"))) }
        return result
    }

    private static func heading(from line: String) -> MarkdownBlock? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...3).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        return .heading(hashes, String(line.dropFirst(hashes + 1)))
    }

    private static func numbered(from line: String) -> MarkdownBlock? {
        guard let dot = line.firstIndex(of: "."),
              let number = Int(line[..<dot]),
              line.index(after: dot) < line.endIndex,
              line[line.index(after: dot)] == " " else { return nil }
        return .numbered(number, String(line[line.index(dot, offsetBy: 2)...]))
    }
}
