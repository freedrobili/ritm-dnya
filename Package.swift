// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Planer",
    platforms: [.macOS(.v14)],
    targets: [
        .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
        .executableTarget(
            name: "Planer",
            dependencies: ["CSQLite"],
            path: "Sources/Planer",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
