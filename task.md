# Aethel Integration

**Status:** Refining
**Agent PID:** 71202

## Original Todo

## Aethel Integration

#### 1. Update Environment Module

- [ ] Add hardcoded path to aethel binary: `/Users/bkase/Documents/aethel/target/release/aethel`
- [ ] Add method `get_aethel_vault_path()` to check for configured vault
- [ ] Add method `create_aethel_artifact()` to shell out to aethel CLI
- [ ] Add method `update_aethel_artifact()` to use `aethel grow`
- [ ] Keep existing file paths as fallback when aethel not available

#### 2. Update Start Command

- [ ] Check if aethel vault is configured (via `~/.config/aethel/config.json`)
- [ ] If vault exists:
  - Create session artifact: `aethel new --type momentum/session --field goal="..." --field time_expected=X --field status=active --field start_time=...`
  - Store returned UUID in `session.json` for reference
  - Continue creating local `session.json` for backward compatibility
- [ ] If no vault, use existing file-based approach

#### 3. Update Stop Command

- [ ] Read UUID from `session.json` if present
- [ ] If UUID exists (aethel integration active):
  - Read reflection template and create reflection content
  - Update artifact: `aethel grow --uuid {uuid} --content "{reflection content}"`
  - Update artifact fields: status=completed, end_time, time_actual
  - Store reflection in both aethel and local file system
- [ ] If no UUID, use existing file-based approach

#### 4. Update Analyze Command

- [ ] If UUID present in session state:
  - After getting analysis from Claude API
  - Update artifact with analysis object: `aethel grow --uuid {uuid} --content "Analysis: {json}"`
- [ ] Continue returning analysis to stdout as before

#### 5. Add Checklist State Tracking

- [ ] When checklist is completed, check for aethel vault
- [ ] Create checklist_state artifact linked to session UUID
- [ ] Store checklist completion data in aethel

#### 6. Configuration

- [ ] Add environment variable `MOMENTUM_USE_AETHEL` to enable/disable integration
- [ ] Document aethel setup requirements in README
- [ ] Add checks for aethel binary availability

#### 7. Testing

- [ ] Test with aethel vault present and absent
- [ ] Test UUID storage and retrieval
- [ ] Test fallback behavior when aethel unavailable
- [ ] Mock aethel CLI calls in unit tests
- [ ] Add integration tests that use real aethel

## Description

[what we're building]

## Implementation Plan

[how we are building it]

- [ ] Code change with location(s) if applicable (src/file.ts:45-93)
- [ ] Automated test: ...
- [ ] User test: ...

## Notes

[Implementation notes]