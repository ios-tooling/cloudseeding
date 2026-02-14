// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CloudSeeding",
	 platforms: [
				 .macOS(.v14),
				 .iOS(.v17),
				 .watchOS(.v10)
		  ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CloudSeeding",
            targets: ["CloudSeeding"]
        ),
    ],
	 dependencies: [
		.package(url: "https://github.com/ios-tooling/Suite", .upToNextMajor(from: "1.3.4")),
	 ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CloudSeeding", dependencies: [
					.product(name: "Suite", package: "Suite"),
			 ]
        ),
		  .testTarget(
				name: "CloudSeedingTests",
				dependencies: ["CloudSeeding"]
		  ),
    ]
)
