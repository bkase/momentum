# Remove the alerts
**Status:** InProgress
**Agent PID:** 82468

## Original Todo
Alert modals are lazy design. All errors should be presented inline, and we don't need "are you sure" dialogs, just do it.

## Description
Replace all alert modals and confirmation dialogs with inline error messages and direct actions. This includes removing error alerts, the "stop session" confirmation, and the "reset app" confirmation. All errors will be displayed inline within the relevant views, and confirmation actions will execute immediately without dialogs.

## Implementation Plan
- [x] Remove alert state and confirmation dialog state from AppFeature+State.swift
- [x] Remove alert presentation modifier from ContentView.swift
- [x] Add error state properties to each feature (Preparation, ActiveSession, Reflection, Analysis)
- [ ] Remove all alert-related actions and cases from AppFeature.swift
- [ ] Update error handling to set feature-specific error states instead of alerts
- [ ] Add inline error display UI to each view (following PreparationView pattern)
- [ ] Remove confirmation dialogs - make stop session and reset immediate actions
- [ ] Update tests to check for inline errors instead of alerts
- [ ] Remove AppFeature+Navigation.swift alert factory methods
- [ ] Add smart error dismissal: validation errors persist until fixed, operation errors auto-dismiss after 5 seconds
- [ ] Style errors consistently using red text below relevant UI elements

## Notes
[Implementation notes]