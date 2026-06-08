// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "InfoMeKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "InfoMeKit", targets: ["InfoMeKit"]),
    ],
    targets: [
        .target(
            name: "InfoMeKit",
            path: "Sources/InfoMeKit"
        ),
        .testTarget(
            name: "InfoMeKitTests",
            dependencies: ["InfoMeKit"],
            path: "Tests/InfoMeKitTests"
        ),
    ]
)
