// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OrcaNotes",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "OrcaNotes",
            targets: ["OrcaNotes"]
        ),
        .library(
            name: "OrcaNotesCore",
            targets: ["OrcaNotesCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "OrcaNotesCore",
            dependencies: [.product(name: "WhisperKit", package: "WhisperKit")],
            path: "Sources/OrcaNotesCore"
        ),
        .executableTarget(
            name: "OrcaNotes",
            dependencies: ["OrcaNotesCore"],
            path: "Sources/OrcaNotes"
        ),
        .testTarget(
            name: "OrcaNotesTests",
            dependencies: ["OrcaNotesCore"],
            path: "Tests/OrcaNotesTests"
        )
    ]
)
