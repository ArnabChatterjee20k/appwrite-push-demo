// swift-tools-version: 5.9

import AppleProductTypes
import PackageDescription

let package = Package(
    name: "AppwritePush",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "AppwritePush",
            targets: ["AppModule"],
            bundleIdentifier: "io.appwrite.pushusage.apple",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .bell),
            accentColor: .presetColor(.pink),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [.portrait]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/appwrite/sdk-for-apple.git", exact: "20.1.0-rc.3")
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            dependencies: [
                .product(name: "Appwrite", package: "sdk-for-apple")
            ],
            path: "."
        )
    ]
)
