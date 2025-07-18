# The title of the markdown file containing the reflection should contain the goal
**Status:** InProgress
**Agent PID:** 74156

## Original Todo
## 6. The title of the markdown file containing the reflection should contain the goal

It can have the date too, but it should also have the goal so it's queryable later.

## Description
We need to modify the reflection file naming to include the session goal in addition to the timestamp. Goals will be converted to lowercase with spaces replaced by hyphens (e.g., "Implement Vim Mode" becomes "implement-vim-mode"). If the goal contains other special characters that are invalid for filenames (`/`, `:`, `*`, `?`, `"`, `<`, `>`, `|`, etc.), the PreparationView should display an error and require the user to rename their goal before starting a session. The final filename format will be `YYYY-MM-DD-HHMM-goal-text.md`.

## Implementation Plan
- [x] Add goal validation to PreparationFeature that checks for invalid filename characters (momentum/src/effects.rs)
- [ ] Create goal sanitization function in Rust that converts to lowercase and replaces spaces with hyphens (momentum/src/effects.rs:35-40)
- [ ] Update filename generation to include sanitized goal after timestamp (momentum/src/effects.rs:37)
- [ ] Update Swift tests that expect the old filename format in SessionManagementTests (MomentumApp/Tests/SessionManagementTests.swift)
- [ ] Update Rust tests that verify reflection file creation in stop_tests (momentum/src/tests/stop_tests.rs)
- [ ] Add test cases for goal validation in PreparationFeature (MomentumApp/Tests/PreparationFeatureTests.swift)
- [ ] Add test cases for filename generation with various goal texts (momentum/src/tests/stop_tests.rs)
- [ ] Manual test: Start session with normal goal, verify reflection file has goal in name
- [ ] Manual test: Try to start session with invalid characters in goal, verify error appears

## Notes
The goal is stored as a simple String in both Rust and Swift. Currently no sanitization is done when using the goal. The reflection filename is generated in momentum/src/effects.rs line 37.