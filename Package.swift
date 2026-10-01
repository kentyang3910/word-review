// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "WordReviewCore",
    products: [.library(name: "WordReviewCore", targets: ["WordReviewCore"])],
    targets: [
        .target(name: "WordReviewCore", path: "Core"),
        .testTarget(name: "WordReviewCoreTests", dependencies: ["WordReviewCore"], path: "Tests/WordReviewCoreTests")
    ]
)
