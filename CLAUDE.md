# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the Momentum codebase. Momentum is a macOS menu bar productivity app that helps users track and optimize deep work sessions through AI-powered reflective practice.

## Using Gemini for Code Critique

When asked to use Gemini for critiquing code, use the following pattern:
```bash
# Concatenate files into a single file
cat file1.rs file2.rs > combined.txt

# Send to Gemini with specific critique request
cat combined.txt | gemini -y -p "Please critique this code focusing on: 1) Architecture, 2) Error handling, 3) Performance, 4) Best practices, 5) Testing. Provide specific actionable feedback."
```

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

Momentum is a macOS menu bar productivity application that helps users track and optimize deep work sessions through AI-powered reflective practice. It consists of:
- A SwiftUI menu bar app using The Composable Architecture (TCA) v1.20.2
- A Rust CLI tool (`momentum`) with Elm-like architecture
- Communication between components via subprocess calls and JSON state files

### Key Features
- Focus session management with goals and time tracking
- Pre-session preparation checklist (10 items)
- Post-session structured reflection templates
- AI-powered analysis using Claude API for insights
- Local-first data storage (JSON and markdown files)

## Development Commands

### Using Makefile (Recommended)
```bash
# Build everything (Swift app + Rust CLI)
make build

# Run all tests
make test

# Run Rust tests only
make rust-test

# Run Swift tests only
make swift-test

# Lint Rust code
make rust-lint

# Clean build artifacts
make clean
```

### Manual Commands

#### Swift/macOS Development
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

#### Rust CLI Development
```bash
# Build the Rust CLI
cd momentum && cargo build --release

# Run Rust tests
cd momentum && cargo test

# Run the CLI directly
cd momentum && cargo run -- [command] [options]

# Format Rust code
cd momentum && cargo fmt

# Lint Rust code
cd momentum && cargo clippy
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


### File Locations
- `session.json`: Application support directory
- Reflection files: `YYYY-MM-DD-HHMM.md` format in data directory
- Template: `reflection-template.md` embedded in app resources
- Rust binary: `Momentum.app/Contents/Resources/momentum`

## Testing

### Testing Strategy
- **Swift Tests**: Use TCA's `TestStore` with mocked `RustCoreClient` dependency
  - Location: `MomentumApp/Tests/`
  - Pattern: Use `@Test` attribute and TCA TestStore
  - Mock all dependencies with deterministic data
- **Rust Tests**: Mock the `Environment` struct containing file system and API dependencies
  - Location: `momentum/src/tests/`
  - Pattern: Use `#[test]` attribute
  - Test state transitions and side effects
- Both test suites run in complete isolation without external dependencies

### Testing Commands

```bash
# Using Makefile (Recommended)
make test          # Run all tests
make rust-test     # Run Rust tests only
make swift-test    # Run Swift tests only

# Manual Commands
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
```

## Important Task Completion Checklist

When completing any task (especially from todos/):
1. ALWAYS read `docs/swift-composable-architecture.md` BEFORE starting work on any Swift tasks to understand TCA patterns
2. Build the app: `make build` or `xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp build -skipMacroValidation`
3. Run ALL tests: `make test` or individual test commands
4. Ensure ALL tests pass with no failures
5. Only then commit the changes (when explicitly asked)
6. Move the todo file to `todos/done/` with analysis
7. Update `todos/todos.md` main list

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
├── Project.swift               # Tuist configuration
├── Makefile                   # Build automation
├── reflection-template.md     # Reflection template
├── CLAUDE.md                  # This file - project guidance
├── README.md                  # Main documentation
├── XCODE_SETUP.md            # Xcode setup guide
├── .github/
│   └── workflows/
│       └── ci.yml            # GitHub Actions CI
├── MomentumApp/              # SwiftUI application
│   ├── Resources/
│   │   ├── momentum          # Rust CLI binary (copied)
│   │   ├── checklist.json    # Checklist configuration
│   │   └── reflection-template.md
│   ├── Sources/
│   │   ├── MomentumApp.swift # App entry point
│   │   ├── AppDelegate.swift
│   │   ├── AppFeature*.swift # Main TCA reducer files
│   │   ├── Dependencies/     # Dependency injection
│   │   │   ├── RustCoreClient.swift
│   │   │   ├── ChecklistClient.swift
│   │   │   └── ProcessRunner.swift
│   │   ├── Features/         # TCA features
│   │   │   ├── ActiveSession/
│   │   │   ├── Analysis/
│   │   │   ├── Preparation/
│   │   │   └── Reflection/
│   │   ├── Models/           # Data models
│   │   ├── Views/            # SwiftUI views
│   │   └── Styles/           # Custom styles
│   └── Tests/                # Swift unit tests
├── momentum/                 # Rust CLI
│   ├── Cargo.toml
│   ├── src/
│   │   ├── main.rs          # CLI entry point
│   │   ├── action.rs        # Action definitions
│   │   ├── effects.rs       # Side effects
│   │   ├── environment.rs   # Dependencies
│   │   ├── models.rs        # Data models
│   │   ├── state.rs         # State management
│   │   ├── update.rs        # State transitions
│   │   └── tests/           # Rust tests
│   └── target/
│       └── release/
│           └── momentum     # Built binary
├── docs/                    # Documentation
│   ├── brand.md
│   ├── checklist-spec.md
│   ├── initial-spec.md
│   └── swift-*.md
└── todos/                   # Task management
    ├── todos.md            # Main todo list
    ├── project-description.md
    ├── done/               # Completed tasks
    └── worktrees/          # Git worktrees

## Common Development Workflows

### Making Changes to Rust CLI
1. Edit files in `momentum/src/`
2. Build: `cd momentum && cargo build --release`
3. Copy to app: `cp target/release/momentum ../MomentumApp/Resources/`
4. Rebuild app: `cd .. && xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp build -skipMacroValidation`
   - Or use `make build` to do all steps automatically

### Making Changes to SwiftUI App
1. Edit files in `MomentumApp/Sources/`
2. If changing dependencies, regenerate: `tuist generate`
3. Build: `xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp build -skipMacroValidation`
   - Or use `make build` to build everything

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

### Working with Todos
- Active tasks: `todos/*.md`
- Completed tasks: `todos/done/`
- Git worktrees for features: `todos/worktrees/`
- Main todo list: `todos/todos.md`

### Editor Setup
When requested to open files in Neovim:
```bash
# Open folder in new ghostty window with nvim
cd /Users/bkase/Documents/momentum && nvim .
```