// swift-tools-version: 6.0
import PackageDescription

// Throwaway spike: not part of HidebarKit. Swift 5 language mode on purpose,
// the private CGS shims and CGEvent code are not worth Sendable plumbing.
let package = Package(
    name: "MoveSpike",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "MoveSpike",
            path: "Sources/MoveSpike",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
