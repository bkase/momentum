# Bug when checking checklist items too fast

**Status:** InProgress
**Agent PID:** 29931

## Original Todo

If you check the items on the checklist too quickly, then there's some kind of erase that occurs, which in the UI, two of the same checklist items show up at once. This shouldn't be possible. I think to fix it, we'd need to do something with the state machine so that the states change eagerly and you don't wait for the animation to happen to change the state. In addition to this, we should make it so that after you check a box, you can't uncheck it even while the animation is happening. The check is just once and final, and that way we can apply the state transition immediately. We'll never have this issue. Same at the moment that we check. We need to acquire some kind of lock around the item that we're going to pull in so that we don't accidentally pull in the same one twice when two animations are happening in parallel.

## Description

We need to fix a race condition bug in the checklist feature where rapidly checking multiple items causes duplicate items to appear in the UI. The bug occurs because the item selection logic uses stale state during overlapping animations, allowing the same "next available item" to be assigned to multiple slots. The fix requires implementing eager state updates, proper concurrency control, and preventing duplicate item assignments during transitions.

## Implementation Plan

Based on the analysis, here's how we'll fix the race condition:

- [ ] Add immediate optimistic state updates in `checklistSlotToggled` action (MomentumApp/Sources/Features/Preparation/PreparationFeature.swift:140-148)
- [ ] Implement item reservation system to prevent duplicate assignments (PreparationFeature+Checklist.swift:60-70)
- [ ] Add slot-level locking to prevent overlapping transitions on same slot (PreparationFeature+Checklist.swift)
- [ ] Make checkbox clicks final and non-reversible during animations (ChecklistRowView.swift)
- [ ] Update item selection logic to consider reserved/transitioning items (PreparationFeature+Checklist.swift:60-70)
- [ ] Automated test: Create TCA test for rapid clicking scenario with deterministic timing
- [ ] User test: Verify rapid clicking no longer creates duplicates and animations work smoothly

## Notes

[Implementation notes]