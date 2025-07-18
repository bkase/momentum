# Momentum

[![CI](https://github.com/bkase/momentum/actions/workflows/ci.yml/badge.svg)](https://github.com/bkase/momentum/actions/workflows/ci.yml)

A macOS productivity application for tracking focus sessions and generating AI-powered insights.

## Architecture

Momentum follows a decoupled architecture with two main components:

1. **SwiftUI Menu Bar App** - Built with The Composable Architecture (TCA)
2. **Rust CLI** - Built with an Elm-like architecture

The two components communicate through subprocess calls and JSON files on the file system.

## Building

### Prerequisites

- Xcode 15.0+
- Rust 1.75+
- Tuist 4.0+
- macOS 14.0+

### Build Steps

1. Install dependencies:
   ```bash
   # Install Tuist (if not already installed)
   curl -Ls https://install.tuist.io | bash
   
   # Install Rust (if not already installed)
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. Generate Xcode project:
   ```bash
   tuist generate
   ```

3. Build and run:
   ```bash
   # Build Rust CLI
   cd momentum
   cargo build --release
   cd ..
   
   # Open in Xcode
   open Momentum.xcworkspace
   ```

## Usage

### CLI Commands

- `momentum start --goal "<goal>" --time <minutes>` - Start a new focus session
- `momentum stop` - Stop the current session and create a reflection file
- `momentum analyze --file <path>` - Analyze a reflection file with Claude API

### Environment Variables

- `ANTHROPIC_API_KEY` - Required for AI analysis features

## Testing

### Rust Tests
```bash
cd momentum
cargo test
```

### Swift Tests
```bash
tuist test
```

## Project Structure

```
momentum/
├── Project.swift           # Tuist configuration
├── MomentumApp/           # SwiftUI application
│   ├── Sources/
│   │   ├── AppFeature.swift    # Main TCA reducer
│   │   ├── Dependencies/       # TCA dependencies
│   │   └── Views/             # SwiftUI views
│   └── Tests/
└── momentum/              # Rust CLI
    ├── src/
    │   ├── main.rs        # Entry point
    │   ├── state.rs       # State management
    │   ├── action.rs      # Action types
    │   ├── update.rs      # Pure update function
    │   ├── effects.rs     # Side effects
    │   └── environment.rs # Dependencies
    └── tests/
```

## Data Flow

1. User interacts with menu bar app
2. SwiftUI app dispatches actions to TCA reducer
3. Reducer calls RustCoreClient dependency
4. RustCoreClient executes Rust CLI as subprocess
5. Rust CLI performs operations and returns results
6. Results update SwiftUI app state

## State Management

- **session.json** - Transient state file for active sessions
- **YYYY-MM-DD-HHMM.md** - Reflection files created after each session
- Both components use unidirectional data flow patterns