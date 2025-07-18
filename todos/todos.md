# Todos

## 1. Make the ui consistent

This means for the ActiveSessionView, AnalysisResultView, and AwaitingAnalysisView be consistent with the design in PreparationView -- as part of this task we should refactor the styling in PreparationView into a brand asset catalog. Please generate a brand reference using the fonts and colors that are currently in PreparationView as the ground-truth but for anything missing refer to @docs/brand.md .

## 2. Better handling of application state

Application state must be saved while application is running in between the menu icon being clicked, but should be reset from scratch if the application process is starting for the first

At the moment, the application is forgetting about the checklist state across preparation view opens and it's remembering that it's within an active session across app terminations. We need to fix that.

