// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HelloWork",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "HelloWork",
            resources: [
                .process("Resources/Media.xcassets"),
                .copy("Resources/Legends")
            ]
        ),
        .executableTarget(
            name: "HelloWorkStub"
        )
    ]
)
