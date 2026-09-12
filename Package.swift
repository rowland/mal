// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "Mal", platforms: [.macOS(.v26)],
    products: [.executable(name: "Mal", targets: ["MalApp"]), .executable(name: "mal-bank", targets: ["MalBankValidator"]), .library(name: "MalCore", targets: ["MalCore"])],
    dependencies: [.package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.2")],
    targets: [
        .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
        .target(name: "MalCore"),
        .target(name: "MalNative", dependencies: ["MalCore"]),
        .target(name: "MalStorage", dependencies: ["MalCore", "CSQLite", "Yams"]),
        .executableTarget(name: "MalApp", dependencies: ["MalCore", "MalStorage", "MalNative"], resources: [.copy("Resources/Banks"), .copy("Resources/Notices")]),
        .executableTarget(name: "MalBankValidator", dependencies: ["MalCore", "MalStorage"]),
        .testTarget(name: "MalCoreTests", dependencies: ["MalCore"]),
        .testTarget(name: "MalNativeTests", dependencies: ["MalNative"]),
        .testTarget(name: "MalStorageTests", dependencies: ["MalStorage"])
    ])
