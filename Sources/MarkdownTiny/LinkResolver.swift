import Foundation

struct LinkResolver {
    let currentFileURL: URL

    func resolve(_ target: String) -> URL? {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }

        // Strip #anchor and ?query for local file lookup.
        var pathPart = trimmed
        if let hash = pathPart.firstIndex(of: "#") {
            pathPart = String(pathPart[..<hash])
        }
        if let q = pathPart.firstIndex(of: "?") {
            pathPart = String(pathPart[..<q])
        }
        pathPart = pathPart.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pathPart.isEmpty else { return nil }

        let currentDir = currentFileURL.deletingLastPathComponent()
        let resolved = currentDir.appendingPathComponent(pathPart).standardized
        if FileManager.default.fileExists(atPath: resolved.path) {
            return resolved
        }
        // Case-insensitive fallback (INDEX.md vs index.md on Linux).
        if let files = try? FileManager.default.contentsOfDirectory(atPath: currentDir.path) {
            let lower = resolved.lastPathComponent.lowercased()
            if let match = files.first(where: { $0.lowercased() == lower }) {
                let candidate = currentDir.appendingPathComponent(match)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
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
