# UI sizing glitches on all the views

**Status:** Done
**Agent PID:** 29367

## Original Todo

## 2. UI sizing glitches on all the views

Basically the fixed size of the view causes background color inconsistency or clipping of the header. We don't want clipped headers or inconsistent colors.
Ask me to paste in the screenshots of the views and I will show you.

## Description

We need to fix UI sizing glitches across all views in the Momentum app. The main issues are:
1. Headers have inconsistent background colors that don't extend the full width
2. The app uses a nested container structure (360px outer, 320px inner) causing visual misalignment
3. Fixed sizing values cause potential content clipping
4. Existing style modifiers (`momentumContainer()`, `momentumTitleStyle()`) are defined but unused

## Implementation Plan

I'll fix the UI sizing glitches by addressing the root causes: inconsistent container structure, unused style modifiers, and header background issues. Here's the detailed plan:

- [x] Refactor ContentView to remove nested container structure and ensure consistent backgrounds (MomentumApp/Sources/Views/ContentView.swift)
- [x] Update all child views to use the existing `momentumContainer()` modifier (PreparationView.swift, ActiveSessionView.swift, AwaitingAnalysisView.swift, AnalysisResultView.swift)
- [x] Apply `momentumTitleStyle()` modifier to all headers for consistency
- [x] Fix PreparationView to use `.momentumTitleBottomPadding` constant instead of hardcoded value (MomentumApp/Sources/Views/PreparationView.swift:36)
- [x] Remove fixed height constraints where content might overflow (PreparationView.swift:104)
- [x] Automated test: Verify views render without clipping by checking view hierarchy
- [x] Fix header clipping by adjusting top padding (discovered during testing)
- [x] Implement dynamic height sizing based on content (discovered during testing)
- [x] User test: Open each view in the menu bar app and verify no background color bleeding or header clipping

## Notes

- Removed fixed height (156px) from checklist container to allow natural sizing
- User noted we may need to add this back depending on how it looks
- Added 8px spacer above header to prevent clipping by window chrome
- Implemented dynamic height sizing: window has minHeight 400, maxHeight 700, with content determining actual height
- Removed fixed contentSize from NSPopover to allow automatic sizing