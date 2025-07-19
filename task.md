# Auto-formatting

**Status:** Refining
**Agent PID:** 86816

## Original Todo

We need to introduce targets for auto-formatting in the Makefile. Then we need to use the Swift format for Swift and cargo format for Rust. Our Makefile targets should follow the same pattern as the other ones. Our CI job should enforce that this is working in the lint job. We can refactor the existing lint job into like a Clippy. The lint should be both a format check and in the Clippy. Let's update the todos/project-description.md and also the CLAUDE.md so that we know about this make format. We can be smart about doing it every time we do a task.

## Description

[what we're building]

## Implementation Plan

[how we are building it]

- [ ] Code change with location(s) if applicable (src/file.ts:45-93)
- [ ] Automated test: ...
- [ ] User test: ...

## Notes

[Implementation notes]