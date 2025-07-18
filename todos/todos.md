# Todos

## 1. Remove the alerts

Alert modals are lazy design. All errors should be presented inline, and we don't need "are you sure" dialogs, just do it.

## 2. Better handling of application state

Application state must be saved while application is running in between the menu icon being clicked, but should be reset from scratch if the application process is starting for the first

At the moment, the application is forgetting about the checklist state across preparation view opens and it's remembering that it's within an active session across app terminations. We need to fix that.

