// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WordPop",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WordPop",
            path: "Sources/WordPop",
            resources: [
                .copy("Resources/wordpop.sqlite"),
            ]
        ),
        .testTarget(
            name: "WordPopTests",
            dependencies: ["WordPop"],
            path: "Tests/WordPopTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
