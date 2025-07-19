# Fix finding claude CLI properly

**Status:** Refining
**Agent PID:** 31118

## Original Todo

### 2. Fix finding claude CLI properly

The `claude` cli tool can't be found when running in the GUI

For now, we can just hardcode claude for my machine.

The way to get to claude is to (from within zsh), `source ~/.zshrc`, then `eval $(mise activate)`, then the correct `claude` should be available in the PATH

## Description

[what we're building]

## Implementation Plan

[how we are building it]

- [ ] Code change with location(s) if applicable (src/file.ts:45-93)
- [ ] Automated test: ...
- [ ] User test: ...

## Notes

[Implementation notes]