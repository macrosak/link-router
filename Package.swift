// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LinkRouter",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic (browser model, profile discovery, rules, matching, config):
        // no AppKit UI, so it stays fast to test.
        .target(
            name: "LinkRouterCore",
            path: "Sources/LinkRouterCore"
        ),
        .executableTarget(
            name: "LinkRouter",
            dependencies: ["LinkRouterCore"],
            path: "Sources/LinkRouter",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "LinkRouterTests",
            dependencies: ["LinkRouter", "LinkRouterCore"],
            path: "Tests/LinkRouterTests"
        )
    ]
)
