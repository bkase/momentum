# Better handling of application state

**Status:** Refining
**Agent PID:** 36627

## Original Todo

Checklist state should be handled by the Rust CLI because the whole application should be completely controllable headlessly. So, I think what we want to do is change the Swift code to not store any state about the checked items; it should be a hundred percent reliant on the Rust CLI. There should be new CLI commands:

- `momentum checklist-view`
- `momentum check <id>`

Additionally:

- You shouldn't be allowed to get to the next state in a session if you haven't checked all of the items on the checklist.
- There should be a command to list the checklist items, and that checklist item list command should return both the unchecked and checked checklist items to standard out.
  We can then parse that on the Swift layer. I'm thinking that JSON makes sense still for that because then it's easy to parse. I think it should be a list with a consistent order, and within the list, there's a JSON object that has the checked state (just call it `on` and `on` can be `true` or `false`). It's confusing, but a small word that means checked is fewer characters if possible. Then there's the actual copy and an `id`. So yeah, so there's a command to list it and then there's also a command to check a specific item; you give it the id and then it gives you back the full list again with that item updated.

## Description

[what we're building]

## Implementation Plan

[how we are building it]

- [ ] Code change with location(s) if applicable (src/file.ts:45-93)
- [ ] Automated test: ...
- [ ] User test: ...

## Notes

[Implementation notes]