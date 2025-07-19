## Summary of Research Findings

Based on my analysis of the codebase, here's what I've discovered about the checklist state management and the interaction between Swift and Rust:

### 1. Where Checklist State is Currently Stored and Managed

**Swift Side:**
- Checklist state is stored in `PreparationPersistentState` which is persisted to `preparation.json` in the app support directory
- The state includes:
  - `checklistSlots`: Array of 4 visible slots that can hold checklist items
  - `totalItemsCompleted`: Counter tracking all completed items (up to 10)
  - `nextItemIndex`: Index tracking which item from the pool to show next

**Rust Side:**
- Currently has NO checklist state or awareness
- The session.json only contains: goal, start_time, time_expected, reflection_file_path

### 2. How Checklist Items are Defined

- **Static checklist definition** in `checklist.json` with 9 items (not 10 as expected)
- **Alternative pool** in `ChecklistItemPool` with 10 different items
- Items have: id, text, and isCompleted state
- Only 4 items visible at a time, with a rotation system when items are completed

### 3. Current Interaction Between Swift and Rust

**Communication Pattern:**
- Swift calls Rust CLI via subprocess using `RustCoreClient`
- Three main commands:
  - `start --goal <goal> --time <minutes>` → Returns session.json path
  - `stop` → Creates reflection file and returns its path
  - `analyze --file <path>` → Analyzes reflection with Claude API

**Data Exchange:**
- Session data stored in `session.json` (shared between Swift/Rust)
- Reflection files created by Rust using embedded template
- No checklist data is currently passed between Swift and Rust

### 4. CLI Command Patterns

**Rust Architecture:**
- Elm-like architecture with Actions, State, Update, and Effects
- Commands defined in enum: Start, Stop, Analyze
- State machine: Idle → SessionActive → Idle
- Effects handle all side effects (file I/O, API calls)

### 5. Session State Management and Validation

**Session Validation:**
- Swift validates: goal not empty, time > 0, all 10 checklist items completed
- Goal validation: no special characters (/:*?"<>|)
- Rust has minimal validation - just prevents starting when session active

**State Persistence:**
- `session.json`: Active session data (managed by both Swift and Rust)
- `preparation.json`: Checklist state (Swift only)
- Both use FileStorage with TCA's @Shared property wrapper

### Key Insights for Adding Checklist to CLI:

1. **No current checklist awareness in Rust** - would need to add checklist models and state
2. **Checklist completion is required** for session start in Swift (10 items must be completed)
3. **Could add new CLI command** like `checklist` to manage checklist state
4. **Would need to share checklist state** between Swift and Rust (possibly in session.json or separate file)
5. **Validation logic** would need to be duplicated or shared between Swift and Rust

## Research Summary: Adding New CLI Commands to the Rust Codebase

Based on my investigation of the Rust codebase, here's a detailed analysis of how to add new CLI commands:

### 1. **Command Parsing and Handling in main.rs**

Commands are parsed using the `clap` crate with a clean pattern:
- **CLI Structure**: The `Cli` struct at the top level contains a `Commands` enum via `#[command(subcommand)]`
- **Commands Enum**: Each command is defined as a variant with its arguments
- **Parsing**: `Cli::parse()` handles all argument parsing automatically
- **Conversion**: CLI commands are converted to internal `Action` enum variants

### 2. **Pattern for Adding New Commands to the Action Enum**

The process follows this pattern:
1. Add a new variant to the `Commands` enum in `main.rs` with appropriate clap attributes
2. Add a corresponding variant to the `Action` enum in `action.rs`
3. Map the CLI command to the action in `main.rs` (lines 56-60)
4. Handle the action in `update.rs` with state transitions and effects

### 3. **How Commands Return Data (Especially JSON) to stdout**

The codebase uses **Effects** for all side effects, including output:
- **Effect Pattern**: Commands don't directly print; they return effects
- **JSON Output Example**: The `analyze` command shows the pattern:
  ```rust
  // In effects.rs, Effect::AnalyzeReflection
  let json = serde_json::to_string(&result)?;
  println!("{json}");
  ```
- **Standard Output**: Use `println!()` for structured data output
- **Error Output**: Use `eprintln!()` or `Effect::PrintError` for errors

### 4. **Examples of Commands Returning Structured Data**

Current examples in the codebase:
- **Start Command**: Prints the session file path as plain text
- **Stop Command**: Prints the reflection file path as plain text
- **Analyze Command**: Prints JSON analysis results from Claude API

### 5. **Where Checklist State Would Be Stored**

Following the existing patterns:
- **Storage Location**: Similar to `session.json`, stored in the Momentum data directory
- **File Path**: Would use `Environment::get_session_path()` pattern but for `checklist.json`
- **Directory**: `~/Library/Application Support/Momentum/checklist.json` on macOS
- **State Management**: Could extend the `State` enum or create a separate checklist state

### Recommended Implementation Pattern for New Checklist Commands

Based on the codebase patterns, here's how to add checklist commands:

1. **Add to Commands enum** (main.rs):
   ```rust
   Checklist {
       #[command(subcommand)]
       subcommand: ChecklistCommand,
   }
   ```

2. **Add to Action enum** (action.rs):
   ```rust
   ChecklistGet,
   ChecklistUpdate { items: Vec<ChecklistItem> },
   ChecklistReset,
   ```

3. **Add new Effect variants** (effects.rs):
   ```rust
   GetChecklist,
   UpdateChecklist { items: Vec<ChecklistItem> },
   ResetChecklist,
   ```

4. **Handle in update function** (update.rs):
   - State transitions remain minimal
   - Effects handle the actual work

5. **Execute effects** (effects.rs):
   - Read/write checklist JSON files
   - Print JSON results to stdout for the GUI to consume

The architecture maintains clear separation between:
- **Pure state transitions** (in update.rs)
- **Side effects** (in effects.rs)
- **Dependency injection** (via Environment)

This pattern ensures testability and follows the existing Elm-like architecture consistently.