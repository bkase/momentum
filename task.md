# Bug when checking checklist items too fast

**Status:** Refining
**Agent PID:** 29931

## Original Todo

If you check the items on the checklist too quickly, then there's some kind of erase that occurs, which in the UI, two of the same checklist items show up at once. This shouldn't be possible. I think to fix it, we'd need to do something with the state machine so that the states change eagerly and you don't wait for the animation to happen to change the state. In addition to this, we should make it so that after you check a box, you can't uncheck it even while the animation is happening. The check is just once and final, and that way we can apply the state transition immediately. We'll never have this issue. Same at the moment that we check. We need to acquire some kind of lock around the item that we're going to pull in so that we don't accidentally pull in the same one twice when two animations are happening in parallel.

## Description

[what we're building]

## Implementation Plan

[how we are building it]

- [ ] Code change with location(s) if applicable (src/file.ts:45-93)
- [ ] Automated test: ...
- [ ] User test: ...

## Notes

[Implementation notes]