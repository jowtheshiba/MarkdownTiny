import Foundation
import SwiftyTermUI

@MainActor
final class DocumentViewer {
    private let tui = SwiftyTermUI.shared
    private var styledLines: [StyledLine] = []
    private var allLinks: [ParsedLink] = []
    private var selectedLinkIndex: Int = -1
    private var scrollOffset: Int = 0
    private let filePath: String
    private var fileName: String
    private var termCols: Int = 80
    private var termRows: Int = 24

    var onNavigate: ((String) -> Void)?
    var onQuit: (() -> Void)?

    init(filePath: String) {
        self.filePath = filePath
        self.fileName = (filePath as NSString).lastPathComponent
    }

    func loadDocument(at url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        fileName = url.lastPathComponent
        let doc = MarkdownParser.parse(content)
        styledLines = doc.lines
        allLinks = doc.links
        scrollOffset = 0
        selectedLinkIndex = -1
    }

    var viewportHeight: Int {
        termRows - 4
    }

    func scrollUp() {
        if scrollOffset > 0 { scrollOffset -= 1 }
    }

    func scrollDown() {
        let maxScroll = max(0, totalLines - viewportHeight)
        if scrollOffset < maxScroll { scrollOffset += 1 }
    }

    func scrollPageUp() {
        scrollOffset = max(0, scrollOffset - viewportHeight)
    }

    func scrollPageDown() {
        let maxScroll = max(0, totalLines - viewportHeight)
        scrollOffset = min(maxScroll, scrollOffset + viewportHeight)
    }

    func scrollToTop() {
        scrollOffset = 0
    }

    func scrollToBottom() {
        scrollOffset = max(0, totalLines - viewportHeight)
    }

    var totalLines: Int {
        var count = 0
        for line in styledLines {
            count += max(1, wrappedLineCount(line))
        }
        return count
    }

    func selectNextLink() {
        let positions = layoutLinkPositions()
        guard !positions.isEmpty else { return }
        selectedLinkIndex = selectedLinkIndex < 0 ? 0 : (selectedLinkIndex + 1) % positions.count
        ensureLinkVisible(positions[selectedLinkIndex])
    }

    func selectPrevLink() {
        let positions = layoutLinkPositions()
        guard !positions.isEmpty else { return }
        if selectedLinkIndex <= 0 {
            selectedLinkIndex = positions.count - 1
        } else {
            selectedLinkIndex -= 1
        }
        ensureLinkVisible(positions[selectedLinkIndex])
    }

    func activateLink() -> String? {
        let positions = layoutLinkPositions()
        guard selectedLinkIndex >= 0, selectedLinkIndex < positions.count else { return nil }
        return positions[selectedLinkIndex].target
    }

    /// Visual rows of links across the whole document (wrap-aware).
    /// Order matches the traversal in render().
    private struct LinkPosition {
        let target: String
        let visualRow: Int
    }

    private func layoutLinkPositions() -> [LinkPosition] {
        let contentWidth = termCols - 4
        var positions: [LinkPosition] = []
        var visualRow = 0
        var lastKey: String? = nil

        for (lineIndex, styledLine) in styledLines.enumerated() {
            let wrapped = wrapStyledLine(styledLine, width: contentWidth)

            for wrappedSegments in wrapped {
                for segment in wrappedSegments {
                    if let target = segment.linkTarget {
                        // Wrapped continuation of the same link — don't duplicate.
                        let key = "\(lineIndex)\n\(target)"
                        if key != lastKey {
                            positions.append(LinkPosition(target: target, visualRow: visualRow))
                            lastKey = key
                        }
                    }
                }
                visualRow += 1
            }

            if wrapped.isEmpty {
                visualRow += 1
            }
        }

        return positions
    }

    /// Scroll the document so the link becomes visible.
    private func ensureLinkVisible(_ position: LinkPosition) {
        if position.visualRow < scrollOffset {
            scrollOffset = position.visualRow
        } else if position.visualRow >= scrollOffset + viewportHeight {
            scrollOffset = position.visualRow - viewportHeight + 1
        }
    }

    func render() {
        termCols = tui.columns
        termRows = tui.rows

        tui.clear()

        let contentWidth = termCols - 4
        // Link ordinal in document order (as in layoutLinkPositions),
        // counted over all rows including hidden ones, to stay in sync.
        var linkOrdinal = -1
        var lastLinkKey: String? = nil

        tui.drawString(
            row: 0, column: 0,
            text: TextUtils.padRight("  \(fileName)", to: termCols),
            attributes: [.bold],
            foregroundColor: .brightWhite,
            backgroundColor: .indexed(236)
        )

        var visualRow = 0
        var lineIndex = 0
        let maxVisualRow = scrollOffset + viewportHeight

        while lineIndex < styledLines.count && visualRow < maxVisualRow {
            let styledLine = styledLines[lineIndex]
            let wrapped = wrapStyledLine(styledLine, width: contentWidth)

            for (_, wrappedSegments) in wrapped.enumerated() {
                if visualRow >= scrollOffset && visualRow < maxVisualRow {
                    let screenRow = visualRow - scrollOffset + 2
                    renderSegments(wrappedSegments, at: screenRow, contentWidth: contentWidth)
                }

                var segCol = 2
                for segment in wrappedSegments {
                    let segWidth = min(segment.text.count, contentWidth - (segCol - 2))
                    if let target = segment.linkTarget {
                        let key = "\(lineIndex)\n\(target)"
                        if key != lastLinkKey {
                            linkOrdinal += 1
                            lastLinkKey = key
                        }
                        if linkOrdinal == selectedLinkIndex
                            && visualRow >= scrollOffset && visualRow < maxVisualRow {
                            let screenRow = visualRow - scrollOffset + 2
                            highlightLink(at: screenRow, column: segCol, segment: segment)
                        }
                    }
                    segCol += segWidth
                }
                visualRow += 1
            }

            if wrapped.isEmpty {
                if visualRow >= scrollOffset && visualRow < maxVisualRow {
                    let screenRow = visualRow - scrollOffset + 2
                    tui.drawString(row: screenRow, column: 2, text: "")
                }
                visualRow += 1
            }

            lineIndex += 1
        }

        let scrollPercent = totalLines > viewportHeight
            ? Int((Double(scrollOffset) / Double(totalLines - viewportHeight)) * 100)
            : 100
        let statusText = " \(fileName)  |  \(scrollOffset + 1)/\(totalLines)  |  \(scrollPercent)%  |  Tab:links  Enter:open  Esc:quit  "
        tui.drawString(
            row: termRows - 1, column: 0,
            text: TextUtils.padRight(statusText, to: termCols),
            foregroundColor: .brightBlack,
            backgroundColor: .indexed(236)
        )

        if totalLines > viewportHeight {
            let barHeight = viewportHeight
            let thumbSize = max(1, Int(Double(viewportHeight) * Double(viewportHeight) / Double(totalLines)))
            let thumbOffset = totalLines - viewportHeight > 0
                ? Int(Double(scrollOffset) / Double(totalLines - viewportHeight) * Double(barHeight - thumbSize))
                : 0

            for i in 0..<barHeight {
                let ch: Character = (i >= thumbOffset && i < thumbOffset + thumbSize) ? "█" : "│"
                tui.drawChar(
                    row: i + 2,
                    column: termCols - 2,
                    character: ch,
                    foregroundColor: .brightBlue
                )
            }
        }
    }

    private func renderSegments(_ segments: StyledLine, at row: Int, contentWidth: Int) {
        var col = 2
        for segment in segments {
            let remaining = contentWidth - (col - 2)
            guard remaining > 0 else { break }
            let displayText = String(segment.text.prefix(remaining))
            tui.drawString(
                row: row,
                column: col,
                text: displayText,
                attributes: segment.attributes,
                foregroundColor: segment.foregroundColor,
                backgroundColor: segment.backgroundColor
            )
            col += displayText.count
        }
    }

    private func highlightLink(at row: Int, column: Int, segment: StyledSegment) {
        let displayText = String(segment.text.prefix(termCols - column))
        tui.drawString(
            row: row,
            column: column,
            text: displayText,
            attributes: [.bold, .underline],
            foregroundColor: .brightWhite,
            backgroundColor: .indexed(236)
        )
    }

    private func wrapStyledLine(_ line: StyledLine, width: Int) -> [StyledLine] {
        guard width > 0 else { return [line] }

        if line.contains(where: { $0.noWrap }) {
            return [line]
        }

        var result: [StyledLine] = []
        var currentLine: StyledLine = []
        var currentWidth = 0
        // Leading spaces of the first visual line are significant (nested-list
        // indent); on wrapped continuation lines the leading space is dropped.
        var isFirstVisualLine = true

        for segment in line {
            let words = segment.text.split(separator: " ", omittingEmptySubsequences: false)

            for (wordIndex, word) in words.enumerated() {
                let wordStr = String(word)
                let spacePrefix = wordIndex > 0 ? " " : ""
                let totalAdd = spacePrefix.count + wordStr.count

                if currentWidth + totalAdd > width && currentWidth > 0 {
                    result.append(currentLine)
                    currentLine = []
                    currentWidth = 0
                    isFirstVisualLine = false
                }

                if wordStr.count > width {
                    if currentWidth > 0 {
                        result.append(currentLine)
                        currentLine = []
                        currentWidth = 0
                        isFirstVisualLine = false
                    }
                    var remaining = wordStr
                    while remaining.count > width {
                        let chunk = String(remaining.prefix(width))
                        result.append([StyledSegment(chunk, attributes: segment.attributes, foregroundColor: segment.foregroundColor, backgroundColor: segment.backgroundColor, linkTarget: segment.linkTarget)])
                        remaining = String(remaining.dropFirst(width))
                        isFirstVisualLine = false
                    }
                    if !remaining.isEmpty {
                        currentLine.append(StyledSegment(remaining, attributes: segment.attributes, foregroundColor: segment.foregroundColor, backgroundColor: segment.backgroundColor, linkTarget: segment.linkTarget))
                        currentWidth = remaining.count
                    }
                    continue
                }

                if !spacePrefix.isEmpty && (currentWidth > 0 || isFirstVisualLine) {
                    currentLine.append(StyledSegment(spacePrefix, foregroundColor: segment.foregroundColor))
                    currentWidth += 1
                }

                currentLine.append(StyledSegment(wordStr, attributes: segment.attributes, foregroundColor: segment.foregroundColor, backgroundColor: segment.backgroundColor, linkTarget: segment.linkTarget))
                currentWidth += wordStr.count
            }
        }

        if !currentLine.isEmpty {
            result.append(currentLine)
        }

        return result.isEmpty ? [line] : result
    }

    private func wrappedLineCount(_ line: StyledLine) -> Int {
        let contentWidth = termCols - 4
        return wrapStyledLine(line, width: contentWidth).count
    }
}
