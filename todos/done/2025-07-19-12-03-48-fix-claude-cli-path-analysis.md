## Summary of Claude CLI Invocation in Momentum

### 1. **Where claude is invoked:**
- **File:** `/Users/bkase/Documents/momentum/todos/worktrees/2025-07-19-12-03-48-fix-claude-cli-path/momentum/src/environment.rs`
- **Line:** 122-124
- **Method:** The Rust CLI (`momentum`) invokes the `claude` command using:
  ```rust
  tokio::process::Command::new("zsh")
      .arg("-c")
      .arg(format!("claude -p '{escaped_prompt}'"))
  ```

### 2. **How it's called:**
- The SwiftUI app calls `momentum analyze --file <path>` (in `RustCoreClient.swift` line 38)
- The momentum Rust CLI then internally calls the `claude` CLI tool via `zsh -c`
- Currently using plain `zsh -c` without loading the user's shell configuration

### 3. **Current PATH setup:**
- **Issue:** The command runs `zsh -c "claude -p '...'"` but doesn't load the user's shell configuration
- **No PATH manipulation:** The code doesn't source `.zshrc` or activate `mise` before running claude
- **Environment:** The Process environment is passed from SwiftUI app (line 47 in `ProcessHelpers.swift`)

### 4. **Error handling:**
- Line 139-143 in `environment.rs`: Checks for "command not found: claude" in stderr
- Returns error: "claude CLI tool not found. Please ensure it is installed and available in your PATH."

### 5. **The root cause:**
According to the task description, the `claude` CLI requires:
1. Sourcing `~/.zshrc`
2. Running `eval $(mise activate)`
3. Then `claude` will be available in PATH

But the current implementation just runs `zsh -c "claude ..."` without loading these configurations.

The fix would need to modify line 124 in `environment.rs` to something like:
```rust
.arg(format!("source ~/.zshrc && eval $(mise activate) && claude -p '{escaped_prompt}'"))
```

## Summary

I've successfully fixed the issue where the `claude` CLI tool couldn't be found when running in the GUI environment. Here's what I did:

### Changes Made:

1. **Modified `momentum/src/environment.rs`** (lines 116-138):
   - Replaced the previous approach of using `zsh -c` to execute `claude` through shell environment loading
   - Hardcoded the path to the claude binary: `~/.local/share/mise/shims/claude`
   - The path is constructed dynamically using the `HOME` environment variable (with fallback to `/Users/bkase`)
   - Updated error messages to be more specific about the mise installation requirement

### Technical Details:

- The claude CLI is installed via mise as an npm package: `@anthropic-ai/claude-code` version 1.0.55
- The shim at `~/.local/share/mise/shims/claude` is a symlink that points to mise, which then executes the actual Node.js script
- This approach bypasses the need for shell environment setup, making it work reliably in GUI applications

### Testing:

1. ✅ Built the Rust CLI successfully
2. ✅ All Rust tests pass (17 tests)
3. ✅ Built the Swift app successfully
4. ✅ All Swift tests pass (30 tests)
5. ✅ Verified the claude CLI works via the hardcoded path

The fix ensures that the Momentum app can find and execute the claude CLI regardless of the environment's PATH configuration, solving the issue where GUI applications don't have access to the same shell environment as terminal sessions.