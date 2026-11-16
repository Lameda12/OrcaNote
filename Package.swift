// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OrcaNotes",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "OrcaNotes",
            targets: ["OrcaNotes"]
        ),
        .library(
            name: "OrcaShared",
            targets: ["OrcaShared"]
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
            name: "OrcaShared",
            dependencies: [.product(name: "WhisperKit", package: "WhisperKit")],
            path: "Sources/OrcaShared"
        ),
        .target(
            name: "OrcaNotesCore",
            dependencies: ["OrcaShared"],
            path: "Sources/OrcaNotesCore"
        ),
        .executableTarget(
            name: "OrcaNotes",
            dependencies: ["OrcaNotesCore"],
            path: "Sources/OrcaNotes"
        ),
        .testTarget(
            name: "OrcaNotesTests",
            dependencies: ["OrcaNotesCore", "OrcaShared"],
            path: "Tests/OrcaNotesTests"
        )
    ]
)
