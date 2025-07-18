# CLAUDE.md

## Using Gemini for Code Critique

When asked to use Gemini for critiquing code, use the following pattern:
```bash
# Concatenate files into a single file
cat file1.rs file2.rs > combined.txt

# Send to Gemini with specific critique request
cat combined.txt | gemini -y -p "Please critique this code focusing on: 1) Architecture, 2) Error handling, 3) Performance, 4) Best practices, 5) Testing. Provide specific actionable feedback."
```

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CI Notes

- CI takes around ~3min so we know how long to wait when checking ci status if it's in progress

## Important Build Notes

### Swift Package Manager Macros
When building with xcodebuild, you'll encounter macro trust issues with TCA and its dependencies. Use `-skipMacroValidation` flag:
```bash
xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp -configuration Debug build -skipMacroValidation
```

### Known Issues and Solutions

1. **"Failed to create session" error**: 
   - The Rust CLI requires `ANTHROPIC_API_KEY` environment variable
   - The SwiftUI app needs to pass this to the subprocess
   - Solution implemented: Auto-set dummy key for development in `RustCoreClient.swift`

2. **"Multiple commands produce" error**:
   - Caused by duplicate resource copying in Project.swift
   - Solution: Remove `folderReference` for momentum directory, only use build script

3. **Binary not found errors**:
   - The Rust binary must be in `MomentumApp/Resources/`
   - Build script handles this automatically
   - For development, falls back to `momentum/target/release/momentum`

4. **Test timing issues**:
   - TCA tests require deterministic state
   - Use fixed timestamps in tests (e.g., `1700000000`)
   - Update both test and mock implementations

## Project Overview

Momentum is a macOS productivity application currently in the design phase. It consists of:
- A SwiftUI menu bar app using The Composable Architecture (TCA)
- A Rust CLI tool (`momentum`) with Elm-like architecture
- Communication between components via subprocess calls and JSON state files

## Development Commands

### Swift/macOS Development
```bash
# Generate Xcode project with Tuist
tuist generate

# Build from command line (with macro validation skipped)
xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp -configuration Debug build -skipMacroValidation

# Run Swift tests from command line
xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp -configuration Debug test -skipMacroValidation

# Run the built app
open /Users/bkase/Library/Developer/Xcode/DerivedData/Momentum-*/Build/Products/Debug/MomentumApp.app
```

### Rust CLI Development
```bash
# Build the Rust CLI
cargo build --release

# Run Rust tests
cargo test

# Run the CLI directly
cargo run -- [command] [options]
```

### CLI Commands
- `momentum start --goal <GOAL> --time <MINUTES>` - Creates session.json
- `momentum stop` - Creates reflection markdown file
- `momentum analyze --file <PATH>` - Analyzes reflection file via Claude API

## Architecture

### State Management
The system uses `session.json` as the single source of truth for active sessions:
```json
{
  "goal": "string",
  "start_time": "u64",
  "time_expected": "u64",
  "reflection_file_path": "string"
}
```

### Key Design Principles
1. **Unidirectional Data Flow**: Both SwiftUI (TCA) and Rust (Elm-like) use explicit actions to modify state
2. **Extreme Testability**: All side effects are managed through dependencies that can be mocked
3. **Decoupled Architecture**: GUI and CLI communicate only through subprocess calls and file system
4. **Local-First**: All data stored locally as JSON and markdown files

### Code Organization
- **Maximum file length**: 200 lines per file
- **Refactoring requirement**: When any code file exceeds 200 lines, it must be refactored into multiple smaller files
- **Benefits**: Improves readability, maintainability, and makes code reviews easier
- **Always keep files to 200 lines max**

### Testing Strategy
- **Swift Tests**: Use TCA's `TestStore` with mocked `RustCoreClient` dependency
- **Rust Tests**: Mock the `Environment` struct containing file system and API dependencies
- Both test suites run in complete isolation without external dependencies

### File Locations
- `session.json`: Application support directory
- Reflection files: `YYYY-MM-DD-HHMM.md` format in data directory
- Template: `reflection-template.md` embedded in app resources
- Rust binary: `Momentum.app/Contents/Resources/momentum`

## Testing Commands

```bash
# Run all tests
cd momentum && cargo test && cd .. && xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp test -skipMacroValidation

# Run Rust tests only
cd momentum && cargo test

# Run Swift tests only (from project root)
xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp test -skipMacroValidation

# Check Rust code without building
cd momentum && cargo check

# Format Rust code
cd momentum && cargo fmt

# Lint Rust code
cd momentum && cargo clippy

# Quick test script
./test-app.sh  # Runs all tests and validates the build
```

## Important Task Completion Checklist

When completing any task (especially from docs/todos/):
1. ALWAYS read `@docs/swift-composable-architecture.md` BEFORE starting work on any Swift tasks to understand TCA patterns
2. Build the app: `xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp build -skipMacroValidation`
3. Run ALL tests: `xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp test -skipMacroValidation`
4. Ensure ALL tests pass with no failures
5. Only then commit the changes
6. Delete the corresponding todo file from docs/todos/
7. Mark the task as completed in the todo list

NEVER mark a task as done if tests are failing!

## Setting Environment Variables in Xcode

To set `ANTHROPIC_API_KEY` for the app:
1. In Xcode, click the scheme selector → "Edit Scheme..."
2. Select "Run" → "Arguments" tab
3. Under "Environment Variables", add:
   - Name: `ANTHROPIC_API_KEY`
   - Value: Your actual API key

## API Integration

The Rust CLI now makes real Claude API calls:
- Endpoint: `https://api.anthropic.com/v1/messages`
- Model: `claude-3-5-sonnet-20241022`
- Requires valid `ANTHROPIC_API_KEY` environment variable
- Returns structured JSON with summary, suggestion, and reasoning

## Project Structure
```
Momentum/
├── Project.swift           # Tuist configuration
├── MomentumApp/           # SwiftUI application
│   ├── AppFeature.swift   # Main TCA reducer
│   └── RustCoreClient.swift # Subprocess dependency
├── momentum/              # Rust CLI
│   ├── Cargo.toml
│   └── src/
│       └── main.rs        # Elm-like architecture
└── Tests/
    ├── MomentumAppTests/
    └── MomentumCoreTests/

## Common Development Workflows

### Making Changes to Rust CLI
1. Edit files in `momentum/src/`
2. Build: `cd momentum && cargo build --release`
3. Copy to app: `cp target/release/momentum ../MomentumApp/Resources/`
4. Rebuild app: `cd .. && xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp build -skipMacroValidation`

### Making Changes to SwiftUI App
1. Edit files in `MomentumApp/Sources/`
2. If changing dependencies, regenerate: `tuist generate`
3. Build: `xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp build -skipMacroValidation`

### Debugging "Failed to create session" errors
1. Check if momentum binary exists in app bundle
2. Verify ANTHROPIC_API_KEY is set
3. Check console output for specific error messages
4. The app falls back to development binary at `momentum/target/release/momentum`

### Type Visibility Issues
When moving types between files/extensions in Swift:
- Move shared types (ProcessResult, SessionData, etc.) to top level
- Avoid nested types in extensions when used across files
- Use explicit module imports if needed
```