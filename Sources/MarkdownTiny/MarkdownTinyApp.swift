import Foundation
import SwiftyTermUI

@main
@MainActor
struct MarkdownTinyApp {
    static let version = "1.0.0"

    static func printHelp() {
        print("""
        MarkdownTiny \(version)
        A cross-platform terminal markdown viewer.

        Usage:
          MarkdownTiny <file.md>    Open a markdown file

        Options:
          -h, --help                Show this help message and exit
          -V, --version             Show version information and exit

        Keys:
          j / ↓                     Scroll down
          k / ↑                     Scroll up
          g / Home                  Jump to top
          G / End                   Jump to bottom
          PgUp / PgDn               Page up / down
          Tab / Shift+Tab           Select next / previous link
          Enter                     Open selected link
          q / Esc                   Quit
        """)
    }

    static func main() async throws {
        let args = CommandLine.arguments

        switch args.dropFirst().first {
        case "-h", "--help":
            printHelp()
            return
        case "-V", "--version":
            print("MarkdownTiny \(version)")
            return
        default:
            break
        }

        guard args.count > 1 else {
            printHelp()
            return
        }

        let filePath = args[1]
        let fileURL = URL(fileURLWithPath: filePath)

        guard FileManager.default.fileExists(atPath: filePath) else {
            print("Error: File not found: \(filePath)")
            print("Try 'MarkdownTiny --help' for usage.")
            return
        }

        if !filePath.hasSuffix(".md") && !filePath.hasSuffix(".markdown") && !filePath.hasSuffix(".mdown") {
            print("Warning: File does not have a .md extension. Attempting to parse anyway.")
        }

        let tui = SwiftyTermUI.shared
        // The library enters the alternate screen itself (?1049h before the first frame)
        // and leaves it in shutdown() (?1049l after clearing the alt buffer),
        // like mc: scrollback is hidden, the terminal screen is restored untouched.
        try tui.initialize()
        defer { tui.shutdown() }

        tui.hideCursor()
        tui.clear()

        let viewer = DocumentViewer(filePath: filePath)
        viewer.loadDocument(at: fileURL)
        viewer.render()
        try tui.refresh()

        var running = true

        while running {
            if let event = tui.readEvent() {
                var needsRender = true

                switch event {
                case .keyPress(let key):
                    switch key {
                    case .escape:
                        running = false

                    case .up:
                        viewer.scrollUp()
                    case .down:
                        viewer.scrollDown()
                    case .pageUp:
                        viewer.scrollPageUp()
                    case .pageDown:
                        viewer.scrollPageDown()
                    case .home:
                        viewer.scrollToTop()
                    case .end:
                        viewer.scrollToBottom()

                    case .character(let char):
                        switch char {
                        case "j":
                            viewer.scrollDown()
                        case "k":
                            viewer.scrollUp()
                        case "q":
                            running = false
                        case "g":
                            viewer.scrollToTop()
                        case "G":
                            viewer.scrollToBottom()
                        default:
                            needsRender = false
                        }

                    case .tab:
                        viewer.selectNextLink()
                    case .shiftTab:
                        viewer.selectPrevLink()

                    case .enter:
                        if let target = viewer.activateLink() {
                            if target.hasPrefix("http://") || target.hasPrefix("https://") {
                                if let url = URL(string: target) {
                                    LinkResolver.openInBrowser(url)
                                }
                            } else {
                                let resolver = LinkResolver(currentFileURL: fileURL)
                                if let resolved = resolver.resolve(target) {
                                    if resolved.pathExtension == "md" || resolved.pathExtension == "markdown" || resolved.pathExtension == "mdown" {
                                        viewer.loadDocument(at: resolved)
                                    } else {
                                        LinkResolver.openInBrowser(resolved)
                                    }
                                }
                            }
                        }

                    default:
                        needsRender = false
                    }

                case .terminalResize:
                    break

                case .paste:
                    break

                case .mouse:
                    break
                }

                if running && needsRender {
                    viewer.render()
                    try tui.refresh()
                }
            }

            try await Task.sleep(for: .milliseconds(16))
        }
    }
}
