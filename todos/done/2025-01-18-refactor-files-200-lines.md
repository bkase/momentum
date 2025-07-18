# Make sure all the files are less than 200 lines, refactor if needed
**Status:** Done
**Agent PID:** 4553

## Original Todo
## 3. Make sure all the files are less than 200 lines, refactor if needed

## Description
Refactor source files that exceed 200 lines to improve code maintainability, readability, and align with the project's coding standards. Four files currently exceed this limit: AppFeature.swift (460 lines), tests.rs (313 lines), PreparationFeature.swift (238 lines), and SessionManagementTests.swift (202 lines).

## Implementation Plan
1. **Refactor AppFeature.swift (460 → ~120 lines each)**
   - [x] Extract AppFeature+State.swift for state and related types (MomentumApp/Sources/AppFeature+State.swift)
   - [x] Extract AppFeature+Navigation.swift for destination handling (MomentumApp/Sources/AppFeature+Navigation.swift)
   - [x] Extract AppFeature+Effects.swift for side effects and async actions (MomentumApp/Sources/AppFeature+Effects.swift)
   - [x] Keep core reducer logic in AppFeature.swift

2. **Refactor tests.rs (313 → ~80 lines each)**
   - [x] Create tests/ directory in momentum/src/
   - [x] Extract tests/mock_helpers.rs for mock implementations
   - [x] Extract tests/start_tests.rs for start command tests
   - [x] Extract tests/stop_tests.rs for stop command tests
   - [x] Extract tests/analyze_tests.rs for analyze command tests
   - [x] Update tests.rs to be a module declaration file

3. **Refactor PreparationFeature.swift (238 → ~120 lines each)**
   - [x] Extract PreparationFeature+Checklist.swift for checklist-specific logic (MomentumApp/Sources/PreparationFeature+Checklist.swift)
   - [x] Keep core reducer and basic actions in PreparationFeature.swift

4. **Refactor SessionManagementTests.swift (202 → ~100 lines each)**
   - [x] Extract SessionManagementTests+StartStop.swift for start/stop tests
   - [x] Keep error handling and edge case tests in SessionManagementTests.swift

5. **Verify refactoring**
   - [x] Run all tests to ensure nothing broke
   - [x] Build the app successfully
   - [x] Verify all files are under 200 lines

## Notes
Following existing patterns in the codebase, using + notation for Swift file extensions and creating proper module structure for Rust tests.