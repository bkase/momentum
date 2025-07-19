# Better handling of application state

**Status:** Done
**Agent PID:** 46030

## Original Todo

Checklist state should be handled by the Rust CLI because the whole application should be completely controllable headlessly. So, I think what we want to do is change the Swift code to not store any state about the checked items; it should be a hundred percent reliant on the Rust CLI. There should be new CLI commands:

- `momentum checklist-view`
- `momentum check <id>`

Additionally:

- You shouldn't be allowed to get to the next state in a session if you haven't checked all of the items on the checklist.
- There should be a command to list the checklist items, and that checklist item list command should return both the unchecked and checked checklist items to standard out.
  We can then parse that on the Swift layer. I'm thinking that JSON makes sense still for that because then it's easy to parse. I think it should be a list with a consistent order, and within the list, there's a JSON object that has the checked state (just call it `on` and `on` can be `true` or `false`). It's confusing, but a small word that means checked is fewer characters if possible. Then there's the actual copy and an `id`. So yeah, so there's a command to list it and then there's also a command to check a specific item; you give it the id and then it gives you back the full list again with that item updated.

## Description

Implement a system where the Rust CLI manages all checklist state, making the app fully controllable headlessly. The Swift UI will become a pure view layer that queries the CLI for state.

**Key changes:**
- Add `check list` and `check toggle <id>` commands to the Rust CLI
- Store checklist state in a `checklist.json` file managed by Rust
- Return checklist data as JSON with `{id, text, on}` format
- Enforce checklist completion before allowing session start
- Remove checklist state storage from Swift, making it purely display-driven

## Implementation Plan

**Rust CLI Changes:**
- [x] Add checklist data models and storage (momentum/src/models.rs)
- [x] Implement `check list` command to return JSON checklist state (momentum/src/main.rs, action.rs, update.rs, effects.rs)
- [x] Implement `check toggle <id>` command to toggle item and return updated state (momentum/src/main.rs, action.rs, update.rs, effects.rs)
- [x] Add checklist validation to `start` command - require all items checked (momentum/src/update.rs)
- [x] Create checklist state file management (momentum/src/environment.rs, effects.rs)

**Swift UI Changes:**
- [x] Replace ChecklistClient with calls to RustCoreClient (MomentumApp/Sources/Dependencies/RustCoreClient.swift)
- [x] Remove PreparationPersistentState and checklist state storage (MomentumApp/Sources/Features/Preparation/PreparationFeature.swift)
- [x] Update PreparationFeature to fetch checklist from CLI (MomentumApp/Sources/Features/Preparation/PreparationFeature.swift)
- [x] Modify checklist toggle action to call CLI command (MomentumApp/Sources/Features/Preparation/PreparationFeature.swift)
- [x] Update tests to mock new CLI commands (MomentumApp/Tests/)

**Integration:**
- [x] Ensure proper JSON parsing between Swift and Rust
- [x] Handle edge cases (missing checklist file, invalid IDs)

**Testing:**
- [x] Automated test: Add Rust tests for new checklist commands
- [x] Automated test: Update Swift tests with mocked checklist responses
- [x] User test: Complete full flow - toggle all checklist items via CLI, start session, verify UI updates
- [x] Fix Swift test compilation errors in ChecklistTests.swift - Update to use slotId parameter
- [x] Fix Swift test compilation errors in PreparationFeatureTests.swift - Update for concurrent execution issues
- [x] Fix remaining Swift test failures in ChecklistTests - Update test expectations for slot-based UI
- [x] Address code review feedback - Keep minimal SharedKeys, remove hardcoded checklist, reduce test complexity, refactor duplicated Rust code

## Notes

Implementation completed successfully:

1. **Rust CLI Changes**: Added `check list` and `check toggle <id>` commands that manage checklist state in a JSON file. The checklist is automatically initialized from the embedded template if missing.

2. **Swift UI Updates**: Removed all local checklist state management from Swift. The UI now queries the Rust CLI for checklist state and sends toggle commands to it.

3. **Session Start Validation**: The Rust CLI now validates that all checklist items are checked before allowing a session to start. It provides clear error messages listing unchecked items.

4. **Checklist Reset**: After successfully starting a session, the checklist is automatically reset to all unchecked for the next session.

5. **Edge Cases Handled**:
   - Missing checklist file: Automatically created from template
   - Invalid item IDs: Silently ignored (no items changed)
   - Consistent JSON format between Swift and Rust

6. **Testing**: Added comprehensive Rust tests for all checklist functionality and updated Swift tests to mock the new CLI commands.

The app is now fully headless-controllable via the CLI for checklist management.