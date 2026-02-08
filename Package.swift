// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Guroute",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Guroute",
            targets: ["Guroute"]
        ),
    ],
    dependencies: [
        // Supabase Swift SDK
        .package(url: "https://github.com/supabase-community/supabase-swift.git", from: "2.0.0"),
        // Networking
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        // Image Loading
        .package(url: "https://github.com/kean/Nuke.git", from: "12.0.0"),
        // Keychain
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
        // Lottie Animations
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.3.0"),
    ],
    targets: [
        .target(
            name: "Guroute",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                "Alamofire",
                "Nuke",
                .product(name: "NukeUI", package: "Nuke"),
                "KeychainAccess",
                .product(name: "Lottie", package: "lottie-ios"),
            ],
            path: "Guroute",
            exclude: ["Info.plist", "Config.xcconfig", "Guroute.entitlements"],
            resources: [
                .process("Resources"),
                .process("Assets.xcassets")
            ]
        ),
    ]
)
