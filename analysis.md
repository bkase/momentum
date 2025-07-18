## Summary

Based on my search through the codebase, here's what I found about reflection markdown file creation:

### 1. **Where the filename is generated**
- **Location**: `/Users/bkase/Documents/momentum/todos/worktrees/2025-07-18-13-51-44-add-goal-to-reflection-filename/momentum/src/effects.rs`, lines 35-37
- **Code**:
  ```rust
  let now = Local::now();
  let filename = now.format("%Y-%m-%d-%H%M.md").to_string();
  ```
- The filename format is `YYYY-MM-DD-HHMM.md` (e.g., `2025-07-18-1430.md`)

### 2. **What code creates/writes the reflection file**
- **Location**: `/Users/bkase/Documents/momentum/todos/worktrees/2025-07-18-13-51-44-add-goal-to-reflection-filename/momentum/src/effects.rs`, in the `Effect::CreateReflection` match arm (lines 34-68)
- **Process**:
  1. Generates timestamp-based filename
  2. Loads the reflection template (embedded in the binary)
  3. Replaces template variables (`{{goal}}`, `{{time_taken}}`, `{{time_expected}}`)
  4. Writes the file to the reflections directory
  5. Updates the session with the reflection file path
  6. Prints the reflection file path to stdout

### 3. **How the reflection template is used**
- **Template location**: `/Users/bkase/Documents/momentum/todos/worktrees/2025-07-18-13-51-44-add-goal-to-reflection-filename/reflection-template.md`
- **Embedded in binary**: Line 43 of `effects.rs`: `let template_content = include_str!("../../reflection-template.md");`
- **Template variables replaced**:
  - `{{goal}}` - The session goal
  - `{{time_taken}}` - Actual time spent (in minutes)
  - `{{time_expected}}` - Expected time (in minutes)

### 4. **Tests related to reflection file creation**
- **Unit tests**: `/Users/bkase/Documents/momentum/todos/worktrees/2025-07-18-13-51-44-add-goal-to-reflection-filename/momentum/src/tests/stop_tests.rs`
  - Tests that stopping a session creates a `CreateReflection` effect
  - Tests that you cannot stop when no session is active
- **Integration tests**: Various tests in `MomentumApp/Tests/` verify the reflection file path is properly handled in the session data

### Key Files Involved:
- **Rust side**:
  - `momentum/src/effects.rs` - Creates the reflection file
  - `momentum/src/update.rs` - Triggers the CreateReflection effect when stopping
  - `momentum/src/models.rs` - Defines the Session struct with reflection_file_path
  - `reflection-template.md` - The template used for reflections

- **Swift side**:
  - `MomentumApp/Sources/Models/RustCoreModels.swift` - Defines SessionData with reflectionFilePath
  - Various test files that verify the reflection file path handling

The reflection filename is currently based only on the timestamp and doesn't include the goal in the filename.

Based on my investigation, here's what I found about how the goal is stored in the session data structure:

## Summary

### 1. Data Type
The goal is stored as a **simple String** in both Rust and Swift:
- **Rust**: `pub goal: String` in the `Session` struct (momentum/src/models.rs)
- **Swift**: `let goal: String` in the `SessionData` struct (MomentumApp/Sources/Models/RustCoreModels.swift)

### 2. How It's Accessed When Creating Reflections
In the Rust code (momentum/src/effects.rs), when creating a reflection file:
- The filename is currently generated using only a timestamp: `let filename = now.format("%Y-%m-%d-%H%M.md").to_string();`
- The goal is used inside the reflection content via template replacement: `.replace("{{goal}}", &session.goal)`

### 3. Special Character Handling
Currently, there is **no special character handling or sanitization** for the goal when it's used. This is important because:
- The goal can contain characters that are invalid in filenames (e.g., `/`, `:`, `*`, `?`, `"`, `<`, `>`, `|` on most file systems)
- If you want to include the goal in the filename, you'll need to sanitize it first

### Key Files to Modify
1. **momentum/src/effects.rs** - Line 37: Where the filename is generated
2. **Tests to update**: The tests currently expect the format `YYYY-MM-DD-HHMM.md`, so they'll need updating if the filename format changes

### Recommendations for Implementation
If you want to add the goal to the filename, you should:
1. Create a sanitization function to replace invalid filename characters
2. Consider truncating long goals to keep filenames reasonable
3. Update the filename generation logic
4. Update all tests that expect the current filename format
5. Update documentation that references the filename format