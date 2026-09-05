import Foundation

struct LinkResolver {
    let currentFileURL: URL

    func resolve(_ target: String) -> URL? {
        if target.hasPrefix("http://") || target.hasPrefix("https://") {
            return URL(string: target)
        }

        let currentDir = currentFileURL.deletingLastPathComponent()
        let resolved = currentDir.appendingPathComponent(target).standardized
        if FileManager.default.fileExists(atPath: resolved.path) {
            return resolved
        }
        return nil
    }

    static func openInBrowser(_ url: URL) {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
        try? process.run()
        #elseif os(Linux)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
        process.arguments = [url.absoluteString]
        try? process.run()
        #elseif os(Windows)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "cmd.exe")
        process.arguments = ["/c", "start", url.absoluteString]
        try? process.run()
        #endif
    }
}
