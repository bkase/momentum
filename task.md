# Add Github actions CI
**Status:** Refining
**Agent PID:** 76321

## Original Todo
We should build and run the tests. Let's make sure it's a consistent environment to ours. So we may need to specify our tuist and rust versions locally as well as any other system deps. We should prefer `mise` for this (I think we're using stable rust, but just verify with whatever is in our path), and if there are other shell deps we need then we can also use a nix flake devshell and wrap the action in that (in that case let's install mise through the nix flake too)

## Description
[what we're building]

## Implementation Plan
[how we are building it]
- [ ] Code change with location(s) if applicable (src/file.ts:45-93)
- [ ] Automated test: ...
- [ ] User test: ...

## Notes
[Implementation notes]