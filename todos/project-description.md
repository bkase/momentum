# Project: Momentum

Momentum is a macOS menu bar productivity application that helps users track and optimize deep work sessions through AI-powered reflective practice.

## Features
- Focus session management with goals and time tracking
- Pre-session preparation checklist (10 items)
- Post-session structured reflection templates
- AI-powered analysis using Claude API for insights
- Local-first data storage (JSON and markdown files)
- Built-in test server for debugging (DEBUG builds only)

## Tech Stack
- **Languages**: Swift 6.0, Rust (edition 2021)
- **Frameworks**: SwiftUI, The Composable Architecture (TCA) v1.20.2
- **Build Tools**: Tuist, Xcode/xcodebuild, Cargo
- **Testing**: Swift Testing + TCA TestStore, Rust built-in testing
- **Dependencies**: See Cargo.toml and Package.resolved for full list

## Structure
- **MomentumApp/**: SwiftUI application code
  - Sources/: Feature reducers, views, dependencies
  - Resources/: Binary, templates, config files
  - Tests/: Swift unit tests
- **momentum/**: Rust CLI tool
  - src/: Elm-like architecture implementation
- **docs/**: Documentation and task tracking

## Architecture
- **Frontend**: SwiftUI menu bar app using TCA pattern
- **Backend**: Rust CLI with Elm-like architecture
- **Communication**: Subprocess calls and JSON state files
- **State Management**: Unidirectional data flow in both components
- **Key Files**: AppFeature.swift (root reducer), main.rs (CLI entry)

## Commands
### Using Makefile (Recommended)
- Build all: `make build`
- Test all: `make test`
- Format all: `make format`
- Lint all: `make lint`
- Rust test: `make rust-test`
- Rust lint: `make rust-lint`
- Rust format: `make rust-format`
- Swift test: `make swift-test`
- Swift lint: `make swift-lint`
- Swift format: `make swift-format` (uses Apple's swift-format)
- Swift generate: `make swift-generate` (generates Xcode project)
- Clean: `make clean`

### Manual Commands
- Build: `xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp build -skipMacroValidation`
- Test: `cd momentum && cargo test && cd .. && xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp test -skipMacroValidation`
- Lint: `cd momentum && cargo fmt && cargo clippy`
- Dev/Run: `open /Users/bkase/Library/Developer/Xcode/DerivedData/Momentum-*/Build/Products/Debug/MomentumApp.app`

## Testing
- **Swift**: Create tests in MomentumApp/Tests/ using @Test attribute and TCA TestStore
- **Rust**: Add tests in src/tests.rs using #[test] attribute
- **Pattern**: Mock all dependencies, use deterministic data, test state transitions
- **Test Server**: HTTP server on port 8765 for debugging (see docs/test-server.md)

## Editor
- Open folder: I will open a new ghostty window and open the folder with `nvim`, you will provide an nvim invocation I can copy+paste
