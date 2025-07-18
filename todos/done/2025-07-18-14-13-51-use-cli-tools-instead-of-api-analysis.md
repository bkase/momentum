# Analysis: Replace API calls with CLI tools

## Current API Usage Locations

### 1. **Rust CLI - Direct API Implementation**

**File: `/momentum/src/environment.rs` (lines 86-167)**
- Contains the `RealApiClient` struct that makes actual HTTP requests to Claude API
- Key details:
  - API endpoint: `https://api.anthropic.com/v1/messages`
  - Model: `claude-3-5-sonnet-20241022`
  - Uses `ANTHROPIC_API_KEY` environment variable
  - Makes POST request with JSON body containing the prompt
  - Headers: `x-api-key`, `anthropic-version`, `content-type`

**File: `/momentum/src/effects.rs` (lines 71-82)**
- The `AnalyzeReflection` effect calls the API client:
  ```rust
  Effect::AnalyzeReflection { path } => {
      let content = env.file_system.read(&path)?;
      let result = env.api_client.analyze(&content).await?;
      let json = serde_json::to_string(&result)?;
      println!("{}", json);
      Ok(())
  }
  ```

### 2. **Swift App - Indirect API Calls**

**File: `/MomentumApp/Sources/Dependencies/RustCoreClient.swift`**
- The Swift app doesn't make direct API calls
- Instead, it calls the Rust CLI's `analyze` command via subprocess
- Line 37-51: The `analyze` function executes `momentum analyze --file <path>`

**File: `/MomentumApp/Sources/Features/Reflection/ReflectionFeature.swift`**
- Line 30: Calls `rustCoreClient.analyze(reflectionPath)` which triggers the subprocess

### 3. **Environment Variable Usage**

**File: `/MomentumApp/Sources/Dependencies/ProcessHelpers.swift`**
- Lines 42-47: Sets `ANTHROPIC_API_KEY` environment variable for the subprocess
- Falls back to "dummy-key-for-development" if not set

### 4. **Test Mocks**

**File: `/momentum/src/tests/mock_helpers.rs`**
- Lines 51-62: `MockApiClient` provides a mock implementation that returns fixed test data

**Various Swift test files:**
- `/MomentumApp/Tests/ReflectionFeatureTests.swift`
- `/MomentumApp/Tests/FullFlowTests.swift`
- `/MomentumApp/Tests/SessionManagementTests.swift`
- All mock the `analyze` function to return test data

### Summary of Changes Needed:

1. **Primary change location**: `/momentum/src/environment.rs` - Replace the HTTP API call implementation with subprocess calls to CLI tools
2. **Effect handler**: `/momentum/src/effects.rs` - May need adjustment depending on how CLI tool output is handled
3. **Environment setup**: May need to update how API keys are handled if switching to CLI tools that use different authentication methods
4. **Tests**: All mock implementations will need to be updated to match the new CLI tool interface

The architecture is well-designed with clear separation of concerns - the API client is abstracted behind a trait (`ApiClient`), making it relatively straightforward to replace the implementation with CLI tool calls while keeping the rest of the codebase unchanged.

## Subprocess Pattern Analysis

### 1. **Current Subprocess Implementation Pattern**

The Swift app uses a dedicated `ProcessHelpers.swift` file that contains the `executeCommand` function. This function:
- Creates a `Process()` instance (Foundation's Process class)
- Sets the `executableURL` to the binary path
- Passes arguments as an array
- Handles environment variables (including `ANTHROPIC_API_KEY`)
- Uses pipes for stdout/stderr capture
- Returns a `ProcessResult` struct containing output, error, and exit code

### 2. **How the Rust CLI is Called**

In `RustCoreClient.swift`, the app calls the momentum binary with commands like:
```swift
executeCommand("start", arguments: ["--goal", goal, "--time", String(minutes)])
executeCommand("stop", arguments: [])
executeCommand("analyze", arguments: ["--file", filePath])
```

### 3. **Current API Integration**

The Rust CLI currently makes direct API calls to Claude's API endpoint (`https://api.anthropic.com/v1/messages`) using the `reqwest` library. It requires the `ANTHROPIC_API_KEY` environment variable.

### 4. **No Existing Shell Command Pattern**

There's no existing pattern for calling shell commands via `zsh -c` or similar. The current implementation directly executes binaries without going through a shell.

### 5. **Key Architectural Points**

- The `executeCommand` function is generic enough to execute any binary, not just the momentum CLI
- Environment variables are properly passed through from the parent process
- Error handling includes specific cases for missing binaries and command failures
- The system uses async/await with continuations for process execution

To integrate the `claude` and `gemini` CLI tools, we need to:
1. Replace the RealApiClient implementation to use subprocess calls
2. Use `zsh -c` to ensure user's shell configuration is loaded (for PATH and other settings)
3. Parse the output from these CLI tools to match our AnalysisResult structure
4. Update tests to mock the new subprocess-based implementation