// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Buttons",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Buttons", targets: ["Buttons"]),
    ],
    targets: [
        .target(
            name: "MultitouchBridge",
            path: "Sources/MultitouchBridge",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "Buttons",
            dependencies: ["MultitouchBridge"],
            path: "Sources/Buttons",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
    ]
)
