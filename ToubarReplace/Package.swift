 // swift-tools-version: 6.3
 
import PackageDescription

let package = Package(
    name: "ToubarReplace",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ToubarReplace",
            targets: ["ToubarReplace"]
        )
    ],
    targets: [
        .target(
            name: "MirrorFrameProcessing",
            path: "Sources/MirrorFrameProcessing",
            publicHeadersPath: "include"
        ),
        .target(
            name: "TouchBarPrivateAPI",
            path: "Sources/TouchBarPrivateAPI",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "ToubarReplace",
            dependencies: ["TouchBarPrivateAPI", "MirrorFrameProcessing"],
            resources: [
                .process("Resources")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
