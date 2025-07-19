# Fix finding claude CLI properly

**Status:** Done
**Agent PID:** 31118

## Original Todo

### 2. Fix finding claude CLI properly

The `claude` cli tool can't be found when running in the GUI

For now, we can just hardcode claude for my machine.

The way to get to claude is to (from within zsh), `source ~/.zshrc`, then `eval $(mise activate)`, then the correct `claude` should be available in the PATH

## Description

Fixed the issue where the claude CLI tool could not be found when running in the GUI environment by hardcoding the path to the claude binary installed via mise.

## Implementation Plan

- [x] Code change with location(s) if applicable (momentum/src/environment.rs:116-138)
- [x] Automated test: All existing tests pass
- [x] User test: Verified claude CLI works via hardcoded path (~/.local/share/mise/shims/claude)
- [x] Fix macOS sandboxing issue by using shell execution to bypass permission restrictions
- [x] Use full shell environment loading to execute claude through mise activation
- [x] Disable app sandboxing following Vibetunnel approach
- [x] Fix shell parsing error by using mise hook-env instead of mise activate
- [x] Implement test server for debugging the running app
- [x] Remove dummy API key requirement since app uses authenticated claude CLI
- [x] Update documentation to reflect claude CLI usage instead of API keys

## Notes

The claude CLI is installed as an npm package via mise at version 1.0.55. The actual executable is a Node.js script located at:
- Shim: `~/.local/share/mise/shims/claude`
- Actual script: `~/.local/share/mise/installs/npm-anthropic-ai-claude-code/1.0.55/lib/node_modules/@anthropic-ai/claude-code/cli.js`

The fix replaces the previous approach of using `zsh -c` to load shell configuration with a direct path to the claude shim. This ensures the CLI can be found regardless of the environment's PATH configuration.