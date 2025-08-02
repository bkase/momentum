# Bug when checking checklist items too fast

**Status:** Done
**Agent PID:** 7830

## Original Todo

If you check the items on the checklist too quickly, then there's some kind of erase that occurs, which in the UI, two of the same checklist items show up at once. This shouldn't be possible. I think to fix it, we'd need to do something with the state machine so that the states change eagerly and you don't wait for the animation to happen to change the state. In addition to this, we should make it so that after you check a box, you can't uncheck it even while the animation is happening. The check is just once and final, and that way we can apply the state transition immediately. We'll never have this issue. Same at the moment that we check. We need to acquire some kind of lock around the item that we're going to pull in so that we don't accidentally pull in the same one twice when two animations are happening in parallel.

## Description

We need to fix a race condition bug in the checklist feature where rapidly checking multiple items causes duplicate items to appear in the UI. The bug occurs because the item selection logic uses stale state during overlapping animations, allowing the same "next available item" to be assigned to multiple slots. The fix requires implementing eager state updates, proper concurrency control, and preventing duplicate item assignments during transitions.

## Implementation Plan

Based on the analysis, here's how we'll fix the race condition:

- [x] Add immediate optimistic state updates in `checklistSlotToggled` action (MomentumApp/Sources/Features/Preparation/PreparationFeature.swift:140-148)
- [x] Implement item reservation system to prevent duplicate assignments (PreparationFeature+Checklist.swift:60-70)
- [x] Add slot-level locking to prevent overlapping transitions on same slot (PreparationFeature+Checklist.swift)
- [x] Make checkbox clicks final and non-reversible during animations (ChecklistRowView.swift)
- [x] Update item selection logic to consider reserved/transitioning items (PreparationFeature+Checklist.swift:60-70)
- [x] Automated test: Create TCA test for rapid clicking scenario with deterministic timing
- [x] User test: Verify rapid clicking no longer creates duplicates and animations work smoothly
- [x] Fix critical flaw: Change guard clause from !item.on to !slot.isTransitioning to allow animation flow with optimistic updates
- [x] Fix text jiggling during animations by removing conflicting text animations and using fixed frame alignment

## Notes

Implementation completed with the following key changes:

### 1. Immediate Optimistic State Updates
- Modified `checklistSlotToggled` action to immediately mark items as checked in local state
- Prevents stale state issues when multiple items are clicked rapidly
- Only allows checking (not unchecking) to maintain UI consistency

### 2. Item Reservation System  
- Added `reservedItemIds: Set<String>` to state to track items pending transition
- Items are reserved immediately when a transition starts
- Reservations are cleaned up when items are placed in slots
- Prevents the same item from being assigned to multiple slots

### 3. Slot-Level Locking
- Added checks to prevent overlapping transitions on the same slot
- Modified `handleChecklistSlotToggled` to check `isTransitioning` flag
- Ensures only one transition per slot at a time

### 4. Final Checkbox Clicks
- Modified Toggle logic in ChecklistRowView to only allow checking (false -> true)
- Combined with existing `allowsHitTesting` logic to prevent clicks during animations
- Makes checkbox behavior deterministic and prevents race conditions

### 5. Updated Item Selection Logic
- Modified replacement item selection to exclude both currently displayed items AND reserved items
- Ensures each rapid click gets a unique replacement item
- Prevents duplicate items from appearing in the UI

### 6. Comprehensive Test Coverage
- Added `rapidClickingRaceConditionPrevention` test in ChecklistTests.swift
- Tests rapid clicking scenarios with deterministic timing using ImmediateClock
- Verifies no duplicate items are assigned and reservations are properly managed

The fix addresses the root cause identified in the original bug report: multiple rapid clicks seeing stale state and selecting the same replacement items. The solution provides immediate feedback, proper concurrency control, and maintains smooth animations.

### 7. Critical Fix Applied
- **Issue discovered**: The optimistic update immediately set `item.on = true`, causing the guard clause `!item.on` to block the animation flow
- **Root cause**: After optimistic update, `handleChecklistSlotToggled` would see the item as already checked and prevent the animation sequence
- **Solution**: Removed the `!item.on` guard clause, keeping only `!slot.isTransitioning` to prevent duplicate clicks during transitions
- **Result**: Animation flow now works correctly with optimistic updates - items get immediate visual feedback AND proper fade-out animations

### 8. Text Jiggling Fix Applied
- **Issue discovered**: Text was jiggling left/right during checkbox animations due to multiple conflicting animations
- **Root causes**: 
  - Text color animation (0.2s) + checkbox press animation (0.1s) causing layout recalculations
  - Spacer() adjustments during HStack layout changes
  - Multiple animation contexts interfering with each other
- **Solutions implemented**:
  - Wrapped checkbox in fixed-size container to prevent layout shifts during press animation
  - Removed text color animation to eliminate layout recalculations
  - Replaced Spacer() with fixed frame alignment (.frame(maxWidth: .infinity, alignment: .leading))
- **Result**: Text remains perfectly stable during all animations while preserving visual feedback