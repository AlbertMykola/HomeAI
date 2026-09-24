// swift-tools-version: 5.9
import PackageDescription

// Sentry Cocoa 9.29.0 static xcframework (official zip is SPM-valid).
// https://github.com/getsentry/sentry-cocoa/releases/download/9.29.0/Sentry.xcframework.zip
let package = Package(
    name: "SentryCocoa",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "Sentry", targets: ["Sentry"])
    ],
    targets: [
        .binaryTarget(
            name: "Sentry",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.0/Sentry.xcframework.zip",
            checksum: "63fe5a7258097fded9ef485bbb1d8e80e1e91d419ee6d8a6ad405454b5b50fef"
        )
    ]
)
