// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MarkdownTiny",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/jowtheshiba/SwiftyTermUI.git", branch: "main"),
        .package(url: "https://github.com/onevcat/Chroma.git", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "MarkdownTiny",
            dependencies: ["SwiftyTermUI", "Chroma"]
        )
    ]
)
