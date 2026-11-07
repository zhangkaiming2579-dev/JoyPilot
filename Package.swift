// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "JoyPilot", platforms: [.macOS(.v14)],
    products: [.executable(name: "JoyPilot", targets: ["JoyPilot"]), .library(name: "JoyPilotCore", targets: ["JoyPilotCore"])],
    targets: [
        .target(name: "JoyPilotCore"),
        .executableTarget(name: "JoyPilot", dependencies: ["JoyPilotCore"],
                          exclude: ["Hardware/JoyConSwift/CLAUDE.md", "Hardware/JoyConSwift/LICENSE"],
                          linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("IOKit"), .linkedFramework("SceneKit"), .linkedFramework("Carbon")]),
        .testTarget(name: "JoyPilotCoreTests", dependencies: ["JoyPilotCore"])
    ], swiftLanguageVersions: [.v5]
)
