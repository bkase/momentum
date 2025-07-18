# Todos

## 1. Add Github actions CI

We should build and run the tests. Let's make sure it's a consistent environment to ours. So we may need to specify our tuist and rust versions locally as well as any other system deps. We should prefer `mise` for this (I think we're using stable rust, but just verify with whatever is in our path), and if there are other shell deps we need then we can also use a nix flake devshell and wrap the action in that (in that case let's install mise through the nix flake too)

## 2. Make the ui consistent

This means for the ActiveSessionView, AnalysisResultView, and AwaitingAnalysisView be consistent with the design in PreparationView -- as part of this task we should refactor the styling in PreparationView into a brand asset catalog. Please generate a brand reference using the fonts and colors that are currently in PreparationView as the ground-truth but for anything missing refer to @docs/brand.md .

## 3. Remove the alerts

Alert modals are lazy design. All errors should be presented inline, and we don't need "are you sure" dialogs, just do it.

## 4. Better handling of application state

Application state must be saved while application is running in between the menu icon being clicked, but should be reset from scratch if the application process is starting for the first

At the moment, the application is forgetting about the checklist state across preparation view opens and it's remembering that it's within an active session across app terminations. We need to fix that.

