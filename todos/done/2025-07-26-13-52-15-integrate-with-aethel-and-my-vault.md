# Integrate with aethel and my vault

**Status:** Done
**Agent PID:** 17142

## Original Todo

The momentum rust application should rely on aethel for its document management. So the whatever JSON state should be serialized in the Markdown YAML front matter. And if there's other Markdown files and all of the outputs of the focus sessions should be managed, created, stored in the aethel vault instead. You can learn about the aethel protocol in ../../aethel/docs/protocol.md , please use the ../../aethel/crates/aethel-cli to manage the aethel integration. We can depend on the crate from our local filesystem for now since aethel is still in active development.

## Description

We'll integrate the Momentum Rust application with aethel for document management. This involves:
- Replacing JSON file storage (session.json, checklist.json) with aethel documents that use YAML frontmatter
- Storing reflection markdown files as aethel documents in the vault
- Creating a Momentum pack with proper document type schemas
- Using aethel-core as a local dependency to manage all document operations

## Implementation Plan

- [x] Create a Momentum pack with document type schemas for session, reflection, and checklist types (momentum/packs/momentum/)
- [x] Add aethel-core as a local dependency in Cargo.toml (momentum/Cargo.toml)
- [x] Create an AethelStorage trait and implementation to replace FileSystem trait for document operations (momentum/src/aethel_storage.rs)
- [x] Update environment.rs to configure vault location and return aethel-compatible paths (momentum/src/environment.rs)
- [x] Modify session state operations in state.rs to use aethel documents instead of session.json (momentum/src/state.rs)
- [x] Update reflection creation in effects.rs to store reflections as aethel documents (momentum/src/effects.rs)
- [x] Convert checklist operations to use aethel document storage (momentum/src/effects.rs)
- [x] Add vault initialization logic to ensure docs/ and packs/ directories exist (momentum/src/main.rs)
- [x] Install the Momentum pack in the vault during first run (momentum/src/main.rs)
- [x] Update tests to work with aethel storage (momentum/src/tests/)
- [x] Add configuration option for vault location (environment variable or CLI flag) (momentum/src/cli.rs)
- [x] Update Swift app to pass vault location to Rust CLI via environment variable (MomentumApp/Sources/Dependencies/ProcessRunner.swift)
- [x] Ensure Swift app can read session state from aethel documents (MomentumApp/Sources/Dependencies/RustCoreClient.swift)

## Notes

- Using aethel-core from local filesystem at /Users/bkase/Documents/aethel/crates/aethel-core
- Need to maintain backward compatibility or provide migration path from existing JSON storage
- Vault location will default to ~/Documents/Vault or be configurable via MOMENTUM_VAULT_PATH env var