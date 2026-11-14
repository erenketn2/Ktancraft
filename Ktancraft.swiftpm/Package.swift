// swift-tools-version: 5.9
// Ktancraft — Swift Playgrounds app project.
// Ktan Labs
//
// Open Ktancraft.swiftpm in Swift Playgrounds on iPhone or iPad and press Run.
// Nothing else is needed: no Mac, no Xcode, no game files to copy over.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Ktancraft",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "Ktancraft",
            targets: ["AppModule"],
            bundleIdentifier: "dev.ktanlabs.ktancraft",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .running),
            accentColor: .presetColor(.green),
            supportedDeviceFamilies: [
                .phone,
                .pad
            ],
            supportedInterfaceOrientations: [
                .landscapeRight,
                .landscapeLeft
            ],
            additionalInfoPlistContentFilePath: "Info.plist"
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
