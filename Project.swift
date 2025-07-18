import ProjectDescription

let project = Project(
    name: "Momentum",
    organizationName: "com.momentum",
    options: .options(
        textSettings: .textSettings(
            indentWidth: 4,
            tabWidth: 4
        )
    ),
    packages: [
        .remote(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            requirement: .upToNextMajor(from: "1.15.0")
        )
    ],
    settings: .settings(
        base: [
            "MACOSX_DEPLOYMENT_TARGET": "14.0",
            "SWIFT_VERSION": "6.0",
            "PRODUCT_BUNDLE_IDENTIFIER": "com.momentum.Momentum",
            "DEVELOPMENT_TEAM": "$(DEVELOPMENT_TEAM)",
            "CODE_SIGN_STYLE": "Automatic",
            "ENABLE_USER_SCRIPT_SANDBOXING": "NO"
        ],
        configurations: [
            .debug(name: .debug, settings: [
                "OTHER_SWIFT_FLAGS": "$(inherited) -D DEBUG -enable-experimental-feature StrictConcurrency"
            ]),
            .release(name: .release)
        ]
    ),
    targets: [
        .target(
            name: "MomentumApp",
            destinations: .macOS,
            product: .app,
            bundleId: "com.momentum.Momentum",
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Momentum",
                "LSUIElement": true, // Hide from dock by default (menu bar app)
                "NSHumanReadableCopyright": "Copyright © 2025 Momentum. All rights reserved.",
                "CFBundleVersion": "1",
                "CFBundleShortVersionString": "1.0.0"
            ]),
            sources: ["MomentumApp/Sources/**"],
            resources: [
                "MomentumApp/Resources/**"
            ],
            entitlements: .file(path: "MomentumApp/Resources/Momentum.entitlements"),
            scripts: [
                .pre(
                    script: """
                    #!/bin/bash
                    set -e
                    
                    echo "Building Rust CLI..."
                    cd "$SRCROOT/momentum"
                    
                    # Setup mise environment if available
                    if command -v mise &> /dev/null; then
                        eval "$(mise activate bash)"
                    fi
                    
                    # Check if cargo is available
                    if ! command -v cargo &> /dev/null; then
                        echo "Error: cargo not found. Please install Rust."
                        exit 1
                    fi
                    
                    # Build the Rust binary
                    cargo build --release
                    
                    # Ensure Resources directory exists
                    mkdir -p "$SRCROOT/MomentumApp/Resources"
                    
                    # Copy binary to resources
                    echo "Copying momentum binary to Resources..."
                    cp -f "target/release/momentum" "$SRCROOT/MomentumApp/Resources/momentum"
                    chmod +x "$SRCROOT/MomentumApp/Resources/momentum"
                    
                    # Verify the binary was copied
                    if [ ! -f "$SRCROOT/MomentumApp/Resources/momentum" ]; then
                        echo "Error: Failed to copy momentum binary"
                        exit 1
                    fi
                    
                    echo "Rust CLI build complete"
                    """,
                    name: "Build Rust CLI",
                    inputPaths: [
                        "$(SRCROOT)/momentum/Cargo.toml",
                        "$(SRCROOT)/momentum/src"
                    ],
                    outputPaths: [
                        "$(SRCROOT)/MomentumApp/Resources/momentum"
                    ],
                    basedOnDependencyAnalysis: false
                )
            ],
            dependencies: [
                .package(product: "ComposableArchitecture")
            ]
        ),
        .target(
            name: "MomentumAppTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.momentum.MomentumTests",
            sources: ["MomentumApp/Tests/**"],
            dependencies: [
                .target(name: "MomentumApp")
            ]
        )
    ],
    schemes: [
        .scheme(
            name: "MomentumApp",
            shared: true,
            buildAction: .buildAction(targets: ["MomentumApp"]),
            testAction: .targets(
                ["MomentumAppTests"],
                configuration: .debug
            ),
            runAction: .runAction(
                configuration: .debug,
                executable: "MomentumApp"
            )
        )
    ]
)