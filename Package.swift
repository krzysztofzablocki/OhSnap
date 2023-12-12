// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OhSnap",
    platforms: [.iOS(.v15), .macCatalyst(.v15), .macOS(.v13), .tvOS(.v15), .watchOS(.v8)],
    products: [
        .library(
            name: "OhSnap",
            targets: ["OhSnap"]
        ),
        .library(
            name: "OhSnapFirebase",
            targets: ["OhSnapFirebase"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", exact: "10.19.0")
    ],
    targets: [
        .target(
            name: "OhSnap",
            dependencies: []
        ),
        .target(
            name: "OhSnapFirebase",
            dependencies: [
                "OhSnap",
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk")
            ]
        ),
        .testTarget(
            name: "OhSnapTests",
            dependencies: ["OhSnap"]
        ),
    ]
)
