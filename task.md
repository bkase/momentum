# Don't use the API calls but use the cli tools
**Status:** InProgress
**Agent PID:** 3112

## Original Todo
Don't use the API calls but use the cli tools `claude -p` and `gemini -p` instead

These are installed in different ways per user, but `zsg -c "gemini -p '<query>'"` should do the trick because it will load from the user's `.zshrc`

## Description
Replace direct HTTP API calls to Claude with subprocess calls to the `claude` CLI tool. The Rust CLI currently makes direct API calls using the reqwest library, but we need to use the user's installed CLI tools instead. This change will be made in the Rust CLI's ApiClient implementation while keeping the interface unchanged, ensuring minimal impact on the rest of the codebase.

## Implementation Plan
- [ ] Replace RealApiClient implementation in environment.rs to use subprocess calls (momentum/src/environment.rs:86-167)
- [ ] Add subprocess execution capability to Rust using std::process::Command
- [ ] Implement zsh shell invocation to load user's .zshrc configuration
- [ ] Parse claude CLI output and convert to AnalysisResult struct
- [ ] Update error handling to cover subprocess failures and missing claude CLI
- [ ] Automated test: Update mock_helpers.rs to simulate CLI output (momentum/src/tests/mock_helpers.rs)
- [ ] Automated test: Add integration tests for CLI subprocess calls
- [ ] User test: Run `momentum analyze --file <reflection-file>` and verify it uses claude CLI tool
- [ ] User test: Test with missing claude CLI to ensure proper error message
- [ ] User test: Verify output format matches expected JSON structure

## Notes
[Implementation notes]