// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PaperBananaMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PaperBanana", targets: ["PaperBananaApp"])
    ],
    targets: [
        .executableTarget(
            name: "PaperBananaApp",
            path: "Sources/PaperBananaApp",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
