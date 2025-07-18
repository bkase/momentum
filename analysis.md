# AppFeature Refactoring Analysis

## Analysis Summary

Based on my analysis of the AppFeature implementation, here's what I found:

### 1. Current Structure of AppFeature Files

The AppFeature is split across multiple files following the 200-line limit:
- **AppFeature.swift** (171 lines) - Main reducer logic with action handling
- **AppFeature+State.swift** (72 lines) - State and Action definitions  
- **AppFeature+Navigation.swift** (148 lines) - Destination enum and alert/dialog helpers
- **AppFeature+Effects.swift** (120 lines) - Effect helper functions

### 2. Child Features

Four child features exist:
- **PreparationFeature** - Complex feature (163 lines) with checklist management
- **ActiveSessionFeature** - Very simple (25 lines) with just stop button handling
- **ReflectionFeature** - Very simple (26 lines) with analyze/cancel buttons
- **AnalysisFeature** - Very simple (26 lines) with reset/dismiss buttons

### 3. Current Dependencies

- **rustCoreClient** - Used only in AppFeature for:
  - Starting sessions (`rustCoreClient.start`)
  - Stopping sessions (`rustCoreClient.stop`)
  - Analyzing reflections (`rustCoreClient.analyze`)

### 4. Actions/Effects That Should Be Moved to Child Features

Currently, AppFeature handles too much business logic that belongs in child features:

**PreparationFeature should handle:**
- Input validation for goal/time
- The actual session start effect (currently in AppFeature)

**ActiveSessionFeature should handle:**
- The session stop effect (currently in AppFeature)
- Session state management

**ReflectionFeature should handle:**
- The analyze reflection effect (currently in AppFeature)
- Reflection path management

**AnalysisFeature should handle:**
- Reset logic (clearing all data)

### 5. Existing Patterns for Child Feature Communication

The current pattern uses:
- **Destination actions** - Parent listens to child actions via `.destination(.presented(.childFeature(.action)))`
- **Shared state** - Using `@Shared` for cross-feature state (`sessionData`, `lastGoal`, etc.)
- **Parent orchestration** - Parent decides navigation flow based on child actions

### Key Refactoring Opportunities

1. **Move business logic to children**: Each child feature should own its effects and communicate results back to parent
2. **Delegate pattern**: Children should have delegate actions that parent responds to
3. **Dependency injection**: Pass `rustCoreClient` to child features that need it
4. **Simplify parent**: AppFeature should focus on navigation and coordination, not business logic

The current architecture has AppFeature doing too much - it's acting as both coordinator and business logic handler. The child features are mostly just UI state holders rather than proper features with their own logic.