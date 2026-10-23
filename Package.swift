// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FreePdforall",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "FreePdforall", targets: ["FreePdforall"])],
    targets: [
        .target(name: "PDFCore"),
        .executableTarget(name: "FreePdforall", dependencies: ["PDFCore"]),
        .testTarget(name: "PDFCoreTests", dependencies: ["PDFCore"])
    ]
)
