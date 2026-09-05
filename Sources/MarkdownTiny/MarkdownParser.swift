import Foundation
import SwiftyTermUI
import Chroma

struct StyledSegment {
    let text: String
    let attributes: TextAttributes
    let foregroundColor: Color
    let backgroundColor: Color
    let linkTarget: String?
    let noWrap: Bool

    init(
        _ text: String,
        attributes: TextAttributes = [],
        foregroundColor: Color = .white,
        backgroundColor: Color = .default,
        linkTarget: String? = nil,
        noWrap: Bool = false
    ) {
        self.text = text
        self.attributes = attributes
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.linkTarget = linkTarget
        self.noWrap = noWrap
    }
}

typealias StyledLine = [StyledSegment]

struct ParsedLink {
    let displayText: String
    let target: String
    let lineNumber: Int
}

struct ParsedDocument {
    let lines: [StyledLine]
    let links: [ParsedLink]
}

struct MarkdownParser {

    static func parse(_ text: String) -> ParsedDocument {
        let rawLines = text.components(separatedBy: .newlines)
        var result: [StyledLine] = []
        var allLinks: [ParsedLink] = []
        var inCodeBlock = false
        var codeLang = ""
        var codeBuffer: [String] = []
        var tableBuffer: [String] = []
        var lastListDepth: Int? = nil
        var previousRawWasBlank = true

        func flushCode() {
            if inCodeBlock && !codeBuffer.isEmpty {
                result.append(contentsOf: renderCodeBlock(codeLang, lines: codeBuffer))
            }
            codeBuffer.removeAll()
        }

        func flushTable() {
            if !tableBuffer.isEmpty {
                result.append(contentsOf: parseTable(tableBuffer))
                tableBuffer.removeAll()
            }
        }

        for (lineIndex, rawLine) in rawLines.enumerated() {
            let rawIsBlank = rawLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            if rawLine.hasPrefix("```") {
                flushTable()
                if inCodeBlock {
                    flushCode()
                    inCodeBlock = false
                    codeLang = ""
                } else {
                    inCodeBlock = true
                    codeLang = String(rawLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                previousRawWasBlank = false
                lastListDepth = nil
                continue
            }

            if inCodeBlock {
                codeBuffer.append(rawLine)
                previousRawWasBlank = false
                lastListDepth = nil
                continue
            }

            if isTableRow(rawLine) {
                tableBuffer.append(rawLine)
                previousRawWasBlank = false
                lastListDepth = nil
                continue
            } else {
                flushTable()
            }

            // Blank line between a header/parent and the first list item,
            // for looks: before an item that opens a list after plain text
            // or changes the nesting level
            // (deeper or back to a less nested item).
            if !rawIsBlank, let match = listMatch(rawLine),
               !result.isEmpty, !previousRawWasBlank {
                let levelChanged = lastListDepth.map { match.depth != $0 } ?? true
                if levelChanged {
                    result.append([StyledSegment("")])
                }
            }

            let styled = parseLine(rawLine, lineNumber: lineIndex, links: &allLinks)
            result.append(styled)

            if rawIsBlank {
                previousRawWasBlank = true
            } else {
                previousRawWasBlank = false
                lastListDepth = listMatch(rawLine)?.depth
            }
        }

        flushTable()
        flushCode()
        return ParsedDocument(lines: result, links: allLinks)
    }

    private static func renderCodeBlock(_ lang: String, lines: [String]) -> [StyledLine] {
        var innerWidth = 0
        for line in lines {
            innerWidth = max(innerWidth, line.count)
        }
        let maxInnerWidth = 72
        let contentWidth = min(innerWidth, maxInnerWidth)
        let codeColor: Color = .brightGreen
        let codeBg: Color = .indexed(236)
        let borderColor: Color = .brightBlack

        var result: [StyledLine] = []

        let langBadge = lang.isEmpty ? " code " : " \(lang) "
        let rightDashCount = max(1, contentWidth + 1 - langBadge.count)
        var topLine: StyledLine = []
        topLine.append(StyledSegment("┌", foregroundColor: borderColor, noWrap: true))
        topLine.append(StyledSegment("─", foregroundColor: borderColor, noWrap: true))
        topLine.append(StyledSegment(langBadge, attributes: [.bold], foregroundColor: .brightYellow, noWrap: true))
        topLine.append(StyledSegment(String(repeating: "─", count: rightDashCount), foregroundColor: borderColor, noWrap: true))
        topLine.append(StyledSegment("┐", foregroundColor: borderColor, noWrap: true))
        result.append(topLine)

        for segments in highlightCodeLines(lines, lang: lang, fallbackColor: codeColor, background: codeBg) {
            var row: StyledLine = [StyledSegment("│ ", foregroundColor: borderColor, noWrap: true)]
            var remaining = contentWidth
            for seg in segments {
                guard remaining > 0 else { break }
                let take = min(seg.text.count, remaining)
                row.append(StyledSegment(
                    String(seg.text.prefix(take)),
                    attributes: seg.attributes,
                    foregroundColor: seg.foregroundColor,
                    backgroundColor: codeBg,
                    noWrap: true
                ))
                remaining -= take
            }
            if remaining > 0 {
                row.append(StyledSegment(
                    String(repeating: " ", count: remaining),
                    foregroundColor: codeColor,
                    backgroundColor: codeBg,
                    noWrap: true
                ))
            }
            row.append(StyledSegment(" │", foregroundColor: borderColor, noWrap: true))
            result.append(row)
        }

        var botLine: StyledLine = []
        botLine.append(StyledSegment("└", foregroundColor: borderColor, noWrap: true))
        botLine.append(StyledSegment(String(repeating: "─", count: contentWidth + 2), foregroundColor: borderColor, noWrap: true))
        botLine.append(StyledSegment("┘", foregroundColor: borderColor, noWrap: true))
        result.append(botLine)

        return result
    }

    // MARK: - Code syntax highlighting (Chroma)

    private final class HighlighterBox: @unchecked Sendable {
        let value: Highlighter
        let lock = NSLock()
        init() { value = Highlighter(theme: .dark) }
    }
    private static let codeHighlighterBox = HighlighterBox()

    private static func tokenizeCode(_ code: String, lang: String) -> [Token]? {
        let box = codeHighlighterBox
        box.lock.lock()
        defer { box.lock.unlock() }
        return try? box.value.tokenize(code, language: LanguageID(rawValue: lang))
    }

    private static func codeColor(for kind: TokenKind) -> Color {
        switch kind {
        case .keyword: return .brightMagenta
        case .string: return .brightYellow
        case .comment: return .brightBlack
        case .number: return .brightCyan
        case .type: return .cyan
        case .function: return .brightGreen
        case .property: return .brightBlue
        case .operator: return .white
        case .punctuation: return .brightBlack
        default: return .white
        }
    }

    /// Splits code lines into highlighted segments: one entry
    /// per source line, no borders or padding. Unknown language
    /// or error yields plain fallback-colored segments; highlighting
    /// never breaks rendering.
    private static func highlightCodeLines(
        _ lines: [String],
        lang: String,
        fallbackColor: Color,
        background: Color
    ) -> [StyledLine] {
        let plain: [StyledLine] = lines.map {
            [StyledSegment($0, foregroundColor: fallbackColor, backgroundColor: background, noWrap: true)]
        }
        let trimmedLang = lang.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedLang.isEmpty else { return plain }

        let joined = lines.joined(separator: "\n")
        guard let tokens = tokenizeCode(joined, lang: trimmedLang) else {
            return plain
        }

        let ns = joined as NSString
        var result: [StyledLine] = []
        var current: StyledLine = []
        var cursor = 0

        func push(_ text: String, kind: TokenKind) {
            let parts = text.split(separator: "\n", omittingEmptySubsequences: false)
            for (i, part) in parts.enumerated() {
                if i > 0 {
                    result.append(current)
                    current = []
                }
                if !part.isEmpty {
                    var attributes = TextAttributes()
                    if kind == .comment { attributes.insert(.italic) }
                    current.append(StyledSegment(
                        String(part),
                        attributes: attributes,
                        foregroundColor: codeColor(for: kind),
                        backgroundColor: background,
                        noWrap: true
                    ))
                }
            }
        }

        for token in tokens {
            if token.range.location > cursor {
                push(ns.substring(with: NSRange(location: cursor, length: token.range.location - cursor)), kind: .plain)
            }
            if token.range.length > 0 {
                push(ns.substring(with: token.range), kind: token.kind)
            }
            cursor = token.range.location + token.range.length
        }
        if cursor < ns.length {
            push(ns.substring(with: NSRange(location: cursor, length: ns.length - cursor)), kind: .plain)
        }
        result.append(current)

        // Strict invariant: one entry per source line.
        guard result.count == lines.count else { return plain }
        return result
    }

    private static func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|") && trimmed.hasSuffix("|") else { return false }
        guard trimmed.count > 2 else { return false }
        let inner = trimmed.dropFirst().dropLast()
        return inner.contains("|")
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let inner = trimmed.dropFirst().dropLast()
        let cells = inner.split(separator: "|", omittingEmptySubsequences: false)
        return cells.allSatisfy { cell in
            let t = cell.trimmingCharacters(in: .whitespaces)
            return t.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func parseTableCells(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let inner = trimmed.dropFirst().dropLast()
        return splitTableRow(String(inner))
    }

    private static func splitTableRow(_ inner: String) -> [String] {
        var cells: [String] = []
        var current = ""
        var inBacktick = false
        var i = inner.startIndex

        while i < inner.endIndex {
            let ch = inner[i]

            if ch == "`" {
                inBacktick.toggle()
                current.append(ch)
                i = inner.index(after: i)
                continue
            }

            if ch == "\\", i < inner.index(before: inner.endIndex) {
                let next = inner.index(after: i)
                if inner[next] == "|" {
                    current.append("|")
                    i = inner.index(after: next)
                    continue
                }
            }

            if ch == "|" && !inBacktick {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
                i = inner.index(after: i)
                continue
            }

            current.append(ch)
            i = inner.index(after: i)
        }

        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    private static func parseTable(_ rows: [String]) -> [StyledLine] {
        guard rows.count >= 2 else {
            return rows.map { [StyledSegment($0, foregroundColor: .white)] }
        }

        let headerCells = parseTableCells(rows[0])
        let dataRows = Array(rows.dropFirst(2))

        let plainHeader = headerCells.map { stripMarkdown($0).count }
        var colWidths = plainHeader
        for row in dataRows {
            let cells = parseTableCells(row)
            for (i, cell) in cells.enumerated() {
                if i < colWidths.count {
                    colWidths[i] = max(colWidths[i], stripMarkdown(cell).count)
                }
            }
        }

        var result: [StyledLine] = []

        var topLine: StyledLine = []
        topLine.append(StyledSegment("┌", foregroundColor: .brightBlack))
        for (i, w) in colWidths.enumerated() {
            topLine.append(StyledSegment(String(repeating: "─", count: w + 2), foregroundColor: .brightBlack))
            topLine.append(StyledSegment(i < colWidths.count - 1 ? "┬" : "┐", foregroundColor: .brightBlack))
        }
        result.append(topLine)

        var headerLine: StyledLine = []
        headerLine.append(StyledSegment("│ ", foregroundColor: .brightBlack))
        for (i, cell) in headerCells.enumerated() {
            let segs = parseInline(cell)
            let plain = stripMarkdown(cell)
            let padAmount = max(0, colWidths[i] - plain.count)
            for seg in segs {
                headerLine.append(StyledSegment(seg.text, attributes: seg.attributes.union([.bold]), foregroundColor: .brightYellow, backgroundColor: seg.backgroundColor))
            }
            if padAmount > 0 {
                headerLine.append(StyledSegment(String(repeating: " ", count: padAmount), foregroundColor: .brightYellow))
            }
            headerLine.append(StyledSegment(" │ ", foregroundColor: .brightBlack))
        }
        result.append(headerLine)

        var sepLine: StyledLine = []
        sepLine.append(StyledSegment("├", foregroundColor: .brightBlack))
        for (i, w) in colWidths.enumerated() {
            sepLine.append(StyledSegment(String(repeating: "─", count: w + 2), foregroundColor: .brightBlack))
            sepLine.append(StyledSegment(i < colWidths.count - 1 ? "┼" : "┤", foregroundColor: .brightBlack))
        }
        result.append(sepLine)

        for row in dataRows {
            let cells = parseTableCells(row)
            var dataLine: StyledLine = []
            dataLine.append(StyledSegment("│ ", foregroundColor: .brightBlack))
            for (i, w) in colWidths.enumerated() {
                let cell = i < cells.count ? cells[i] : ""
                let segs = parseInline(cell)
                let plain = stripMarkdown(cell)
                let padAmount = max(0, w - plain.count)
                for seg in segs {
                    dataLine.append(StyledSegment(seg.text, foregroundColor: seg.foregroundColor, backgroundColor: seg.backgroundColor))
                }
                if padAmount > 0 {
                    dataLine.append(StyledSegment(String(repeating: " ", count: padAmount), foregroundColor: .white))
                }
                dataLine.append(StyledSegment(" │ ", foregroundColor: .brightBlack))
            }
            result.append(dataLine)
        }

        var botLine: StyledLine = []
        botLine.append(StyledSegment("└", foregroundColor: .brightBlack))
        for (i, w) in colWidths.enumerated() {
            botLine.append(StyledSegment(String(repeating: "─", count: w + 2), foregroundColor: .brightBlack))
            botLine.append(StyledSegment(i < colWidths.count - 1 ? "┴" : "┘", foregroundColor: .brightBlack))
        }
        result.append(botLine)

        return result
    }

    private static func stripMarkdown(_ text: String) -> String {
        var result = ""
        var i = text.startIndex
        var inBacktick = false

        while i < text.endIndex {
            let ch = text[i]

            if ch == "`" {
                inBacktick.toggle()
                i = text.index(after: i)
                continue
            }

            if inBacktick {
                if ch == "\\", i < text.index(before: text.endIndex) {
                    let next = text.index(after: i)
                    result.append(text[next])
                    i = text.index(after: next)
                    continue
                }
                result.append(ch)
                i = text.index(after: i)
                continue
            }

            if ch == "\\" {
                i = text.index(after: i)
                if i < text.endIndex {
                    result.append(text[i])
                    i = text.index(after: i)
                }
                continue
            }

            if ch == "*" || ch == "_" {
                i = text.index(after: i)
                if i < text.endIndex && (text[i] == "*" || text[i] == "_") {
                    i = text.index(after: i)
                }
                continue
            }
            if ch == "[" {
                if let close = text[i...].firstIndex(of: "]") {
                    let inner = text[text.index(after: i)..<close]
                    result += inner
                    var cursor = text.index(after: close)
                    if cursor < text.endIndex && text[cursor] == "(" {
                        if let closeParen = text[cursor...].firstIndex(of: ")") {
                            cursor = text.index(after: closeParen)
                        }
                    }
                    i = cursor
                    continue
                }
            }
            result.append(ch)
            i = text.index(after: i)
        }
        return result
    }

    private static func parseLine(
        _ line: String,
        lineNumber: Int,
        links: inout [ParsedLink]
    ) -> StyledLine {
        if line == "---" || line == "***" || line == "___" {
            return [StyledSegment(String(repeating: "─", count: 60), foregroundColor: .brightBlack)]
        }

        if line.hasPrefix("###### ") {
            return [StyledSegment(String(line.dropFirst(7)), attributes: [.bold], foregroundColor: .cyan)]
        }
        if line.hasPrefix("##### ") {
            return [StyledSegment(String(line.dropFirst(6)), attributes: [.bold], foregroundColor: .brightCyan)]
        }
        if line.hasPrefix("#### ") {
            return [StyledSegment(String(line.dropFirst(5)), attributes: [.bold], foregroundColor: .green)]
        }
        if line.hasPrefix("### ") {
            return [StyledSegment(String(line.dropFirst(4)), attributes: [.bold], foregroundColor: .brightGreen)]
        }
        if line.hasPrefix("## ") {
            return [StyledSegment(String(line.dropFirst(3)), attributes: [.bold], foregroundColor: .yellow)]
        }
        if line.hasPrefix("# ") {
            return [StyledSegment(String(line.dropFirst(2)), attributes: [.bold], foregroundColor: .brightYellow)]
        }

        if line.hasPrefix("> ") {
            let quoteText = String(line.dropFirst(2))
            var segments = parseInline(quoteText)
            segments.insert(StyledSegment("│ ", attributes: [.italic], foregroundColor: .brightBlack), at: 0)
            for i in segments.indices where segments[i].linkTarget == nil {
                segments[i] = StyledSegment(
                    segments[i].text,
                    attributes: segments[i].attributes.union([.italic]),
                    foregroundColor: segments[i].foregroundColor == .white ? .brightBlack : segments[i].foregroundColor,
                    backgroundColor: segments[i].backgroundColor
                )
            }
            return segments
        }

        if let match = listMatch(line) {
            let indent = String(repeating: "  ", count: match.depth)
            let marker: String
            if let num = match.number {
                marker = "\(num). "
            } else {
                marker = "• "
            }
            var segments = parseInline(match.content)
            segments.insert(StyledSegment("\(indent)\(marker)", foregroundColor: .brightCyan), at: 0)
            return segments
        }

        if !line.trimmingCharacters(in: .whitespaces).isEmpty {
            return parseInline(line)
        }

        return [StyledSegment("")]
    }

    private struct ListMatch {
        let depth: Int
        let bullet: Character
        let number: String?
        let content: String
    }

    private static func listMatch(_ line: String) -> ListMatch? {
        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        let depth = leadingSpaces / 2
        let trimmed = String(line.dropFirst(leadingSpaces))

        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            let bullet = trimmed.first!
            let content = String(trimmed.dropFirst(2))
            return ListMatch(depth: depth, bullet: bullet, number: nil, content: content)
        }

        if let dotIndex = trimmed.firstIndex(of: "."),
           dotIndex != trimmed.startIndex {
            let numPart = String(trimmed[..<dotIndex])
            if numPart.allSatisfy(\.isNumber) {
                let afterDot = trimmed.index(after: dotIndex)
                let rest = String(trimmed[afterDot...])
                if rest.hasPrefix(" ") || rest.hasPrefix("\t") {
                    let content = rest.trimmingCharacters(in: .whitespaces)
                    return ListMatch(depth: depth, bullet: "-", number: numPart, content: content)
                }
            }
        }

        return nil
    }

    private static func parseInline(_ text: String) -> StyledLine {
        var segments: StyledLine = []
        var remaining = text[...]

        while !remaining.isEmpty {
            if remaining.hasPrefix("**") || remaining.hasPrefix("__") {
                let marker = remaining.prefix(2)
                remaining = remaining.dropFirst(2)
                if let endRange = remaining.range(of: marker) {
                    let bold = String(remaining[..<endRange.lowerBound])
                    segments.append(StyledSegment(bold, attributes: [.bold], foregroundColor: .brightWhite))
                    remaining = remaining[endRange.upperBound...]
                    continue
                } else {
                    segments.append(StyledSegment("**", foregroundColor: .white))
                    continue
                }
            }

            if remaining.hasPrefix("`") {
                remaining = remaining.dropFirst()
                if let endIdx = remaining.firstIndex(of: "`") {
                    let code = String(remaining[..<endIdx]).replacingOccurrences(of: "\\|", with: "|")
                    segments.append(StyledSegment(code, foregroundColor: .brightCyan, backgroundColor: .indexed(236)))
                    let afterClose = remaining.index(after: endIdx)
                    remaining = remaining[afterClose...]
                    continue
                } else {
                    segments.append(StyledSegment("`", foregroundColor: .white))
                    continue
                }
            }

            if remaining.hasPrefix("[") {
                remaining = remaining.dropFirst()
                if let closeBracket = remaining.firstIndex(of: "]"),
                   remaining.distance(from: remaining.startIndex, to: closeBracket) < 200 {
                    let display = String(remaining[..<closeBracket])
                    let afterBracket = remaining.index(after: closeBracket)
                    remaining = remaining[afterBracket...]
                    if remaining.hasPrefix("("),
                       let closeParen = remaining.firstIndex(of: ")") {
                        let afterParenOpen = remaining.index(after: remaining.startIndex)
                        let target = String(remaining[afterParenOpen..<closeParen])
                        remaining = remaining[remaining.index(after: closeParen)...]
                        segments.append(StyledSegment(
                            display,
                            attributes: [.underline],
                            foregroundColor: .brightBlue,
                            linkTarget: target
                        ))
                        continue
                    } else {
                        segments.append(StyledSegment("[\(display)", foregroundColor: .white))
                        continue
                    }
                } else {
                    segments.append(StyledSegment("[", foregroundColor: .white))
                    continue
                }
            }

            if remaining.hasPrefix("*") && !remaining.hasPrefix("**") {
                remaining = remaining.dropFirst()
                if let endIdx = remaining.firstIndex(of: "*") {
                    let italic = String(remaining[..<endIdx])
                    segments.append(StyledSegment(italic, attributes: [.italic], foregroundColor: .white))
                    remaining = remaining[remaining.index(after: endIdx)...]
                    continue
                } else {
                    segments.append(StyledSegment("*", foregroundColor: .white))
                    continue
                }
            }

            if remaining.hasPrefix("_") && !remaining.hasPrefix("__") {
                remaining = remaining.dropFirst()
                if let endIdx = remaining.firstIndex(of: "_") {
                    let italic = String(remaining[..<endIdx])
                    segments.append(StyledSegment(italic, attributes: [.italic], foregroundColor: .white))
                    remaining = remaining[remaining.index(after: endIdx)...]
                    continue
                } else {
                    segments.append(StyledSegment("_", foregroundColor: .white))
                    continue
                }
            }

            var nextSpecial = remaining.endIndex
            for prefix in ["**", "__", "`", "[", "*", "_"] {
                if let idx = remaining.range(of: prefix, range: remaining.startIndex..<nextSpecial) {
                    nextSpecial = idx.lowerBound
                }
            }

            let plain = String(remaining[..<nextSpecial])
            if !plain.isEmpty {
                segments.append(StyledSegment(plain, foregroundColor: .white))
            }
            remaining = remaining[nextSpecial...]
        }

        if segments.isEmpty {
            segments.append(StyledSegment(text))
        }

        return segments
    }
}
