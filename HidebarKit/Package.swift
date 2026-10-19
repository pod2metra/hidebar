// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "HidebarKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "HidebarCore", targets: ["HidebarCore"]),
        .library(name: "HidebarSystem", targets: ["HidebarSystem"]),
    ],
    targets: [
        .target(name: "HidebarCore"),
        .target(name: "HidebarSystem", dependencies: ["HidebarCore"]),
        .testTarget(name: "HidebarCoreTests", dependencies: ["HidebarCore"]),
    ],
    swiftLanguageModes: [.v6]
)
