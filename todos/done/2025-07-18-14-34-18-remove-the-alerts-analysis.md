# Alert Removal Analysis

## Summary of Alert Usage in MomentumApp

### 1. **Alert Presentation in Views**
- **ContentView.swift:33** - `.alert($store.scope(state: \.alert, action: \.alert))` - Main alert presentation modifier

### 2. **Alert State Management**
- **AppFeature+State.swift:15** - `@Presents var alert: AlertState<Alert>?` - Alert state property

### 3. **Alert Actions in Reducer**
- **AppFeature.swift:146** - `case .alert(.presented(.dismiss)):`
- **AppFeature.swift:150** - `case .alert(.presented(.retry)):`
- **AppFeature.swift:156** - `case .alert(.presented(.openSettings)):`
- **AppFeature.swift:161** - `case .alert(.presented(.contactSupport)):`
- **AppFeature.swift:166** - `case .alert(.dismiss):`

### 4. **Error Alert Presentations**
- **AppFeature.swift:63** - `state.alert = .error(error)` - Error during session start
- **AppFeature.swift:81** - `state.alert = .error(error)` - Error during session stop
- **AppFeature.swift:100** - `state.alert = .error(error)` - Error during analysis
- **AppFeature.swift:134** - `state.alert = nil` - Clearing alert
- **AppFeature.swift:153** - `state.alert = nil` - Clearing alert after retry
- **AppFeature.swift:158** - `state.alert = nil` - Clearing alert after opening settings
- **AppFeature.swift:163** - `state.alert = nil` - Clearing alert after contact support

### 5. **Alert Factory Methods in AppFeature+Navigation.swift**
- **Lines 16-115** - Multiple alert factory methods:
  - `sessionAlreadyActive()` - Lines 17-27
  - `noActiveSession()` - Lines 29-39
  - `invalidTime()` - Lines 41-51
  - `error(_ error: Error)` - Lines 53-61
  - `rustCoreError(_ error: RustCoreError)` - Lines 63-86
  - `appError(_ error: AppError)` - Lines 88-102
  - `genericError(_ error: Error)` - Lines 104-114

### 6. **Test Files**
- **ErrorHandlingTests.swift:41** - `state.alert = .genericError(AppError.other("Test Error"))`
- **ErrorHandlingTests.swift:50** - `await store.send(.alert(.dismiss))`

## Confirmation Dialogs

### **Alert Types**
1. **Error Alerts** - Shown when operations fail:
   - Session start failures (line 63 in AppFeature.swift)
   - Session stop failures (line 81)
   - Analysis failures (line 100)
   - Various error types defined in AppFeature+Navigation.swift

### **Confirmation Dialogs** 
1. **Stop Session Confirmation** (line 67 in AppFeature.swift)
   - Triggered when user taps stop button during active session
   - Message: "Are you sure you want to stop the current session? You'll be prompted to write a reflection."
   - Actions: "Stop Session" (destructive) and "Continue Working" (cancel)

2. **Reset App Confirmation** (line 114 in AppFeature.swift)
   - Triggered when user taps reset button from analysis view
   - Message: "This will clear all session data and return to the preparation screen."
   - Actions: "Reset" (destructive) and "Cancel"

## Current Error Handling Patterns

### 1. **Alert-Based Error Display**
- **State Management**: `AppFeature.State` contains `@Presents var alert: AlertState<Alert>?`
- **Alert Display**: In `ContentView`, line 33: `.alert($store.scope(state: \.alert, action: \.alert))`
- **Error Triggering**: Errors are shown by setting `state.alert = .error(error)` in three places

### 2. **Error Flow Architecture**
The error handling follows a delegation pattern:
1. Child features (PreparationFeature, ActiveSessionFeature, ReflectionFeature) perform operations
2. On failure, they send delegate actions like `sessionFailedToStart(AppError)`
3. Parent AppFeature catches these and displays alerts

### 3. **Existing Inline Error Handling**
The app already has one example of inline error display:
- **PreparationView** (lines 53-59): Shows `goalValidationError` inline below the goal text field

## Changes Needed for Inline Error Display

### 1. **State Changes**
Each feature would need error state properties:
- Add `errorMessage: String?` to each feature state
- Add `errorType: AppError?` for specific error handling

### 2. **Remove Alert Dependencies**
- Remove `@Presents var alert: AlertState<Alert>?` from AppFeature.State
- Remove `.alert($store.scope(state: \.alert, action: \.alert))` from ContentView
- Remove `.ifLet(\.$alert, action: \.alert)` from AppFeature reducer

### 3. **Update Error Handling in AppFeature**
Replace alert setting with error state updates in each destination

### 4. **Update Views for Inline Display**
Each view would need an error display section similar to PreparationView

### 5. **Error Dismissal/Recovery**
- Automatic dismissal after timeout
- Manual dismissal on user interaction
- Clear errors when starting new operations

### 6. **Visual Design Considerations**
- Use consistent error styling across all views
- Consider animations for error appearance/disappearance
- Ensure errors don't disrupt layout flow