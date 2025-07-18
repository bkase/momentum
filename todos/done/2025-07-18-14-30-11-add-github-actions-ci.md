# Add Github actions CI
**Status:** Done
**Agent PID:** 76321

## Original Todo
We should build and run the tests. Let's make sure it's a consistent environment to ours. So we may need to specify our tuist and rust versions locally as well as any other system deps. We should prefer `mise` for this (I think we're using stable rust, but just verify with whatever is in our path), and if there are other shell deps we need then we can also use a nix flake devshell and wrap the action in that (in that case let's install mise through the nix flake too)

## Description
Set up GitHub Actions CI/CD workflow to automatically build and test the Momentum application on every push and pull request. The workflow will use mise for consistent tool version management, ensuring the CI environment matches local development. It will build both the Rust CLI and Swift macOS app, run all tests, and validate the entire build process.

## Implementation Plan
- [x] Create `.mise.toml` in project root to pin tool versions (rust 1.88.0, tuist 4.55.6)
- [x] Create `.github/workflows/ci.yml` with build and test jobs for both Rust and Swift
- [x] Configure mise installation and tool setup in CI workflow
- [x] Set up Rust job: install toolchain via mise, run cargo test, cargo fmt check, cargo clippy
- [x] Set up Swift job: install Tuist via mise, generate project, build with -skipMacroValidation, run tests
- [x] Add test for successful Rust binary build and copy to Resources
- [x] Configure workflow triggers for push to main/master and pull requests
- [x] Add ANTHROPIC_API_KEY as dummy value for CI environment
- [x] Add build status badge to README.md
- [ ] User test: Create a test PR to verify CI runs successfully

## Notes
[Implementation notes]