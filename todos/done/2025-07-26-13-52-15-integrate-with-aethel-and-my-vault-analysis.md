# Aethel Integration Analysis

## Aethel Protocol Overview

### What is Aethel?

Aethel is a **document management system** built around three core primitives:

1. **Doc** - A Markdown file with YAML front matter, identified by a UUID
2. **Pack** - A directory containing type definitions (schemas), templates, and migrations
3. **Patch** - A JSON object describing mutations to documents

The system stores documents as individual Markdown files with structured metadata in YAML front matter, following a precise protocol for consistency and interoperability.

### Document Structure
Each document (`Doc`) consists of:
```markdown
---
uuid: <UUID v4 or v7>
type: <packName.typeName>
created: <ISO 8601 UTC timestamp>
updated: <ISO 8601 UTC timestamp>
v: <SemVer version>
tags: [array of strings]
<additional type-specific fields>
---
<Markdown body content>
```

### Storage Layout
Documents are stored in a vault with this structure:
```
<vault>/
  docs/          # All document files (.md)
  packs/         # Installed type definitions
  .aethel/       # Internal state (optional)
```

## Current Momentum Storage

### Session State Storage (session.json)
- **Location**: `~/Library/Application Support/Momentum/session.json` (macOS data directory)
- **Managed by**: 
  - Rust: `environment.rs` - `get_session_path()` method
  - Swift: `SharedKeys.swift` - Uses `com.momentum.app` subdirectory
- **Contents**: JSON serialization of `Session` struct with fields:
  - `goal`: String
  - `start_time`: Unix timestamp (u64)
  - `time_expected`: Minutes (u64)
  - `reflection_file_path`: Optional String

### Reflection Files Creation and Storage
- **Location**: `~/Library/Application Support/Momentum/reflections/` directory
- **Naming Format**: `YYYY-MM-DD-HHMM-{sanitized-goal}.md`
  - Example: `2024-01-15-1430-implement-new-feature.md`
- **Created by**: `effects.rs` - `Effect::CreateReflection`
- **Template**: Loaded from `reflection-template.md` in app resources
- **Sanitization**: Goal text is lowercased, spaces replaced with hyphens

### Checklist State Storage
- **Location**: `~/Library/Application Support/Momentum/checklist.json`
- **Template**: Embedded from `MomentumApp/Resources/checklist.json`
- **Reset**: Automatically reset after successful session start

### Directory Structure
```
~/Library/Application Support/Momentum/
├── session.json          # Active session state
├── checklist.json        # Checklist state
└── reflections/          # Reflection markdown files
    ├── 2024-01-15-1430-implement-new-feature.md
    └── ...
```

### Rust Modules Handling File I/O
- **environment.rs**: 
  - Defines file paths (`get_session_path()`, `get_reflections_dir()`, `get_checklist_path()`)
  - Contains `FileSystem` trait and `RealFileSystem` implementation
  - Uses `dirs::data_dir()` for platform-specific paths
  
- **effects.rs**: 
  - Implements all side effects including file operations
  - `CreateReflection`: Creates reflection files
  - `SaveState`/`ClearState`: Manages session.json
  - `LoadAndPrintChecklist`/`ToggleChecklistItem`: Manages checklist.json
  
- **state.rs**: 
  - `State::load()`: Reads session.json
  - `State::save()`: Writes/deletes session.json

## Aethel-Core API

### Available API - aethel-core Library
The main integration point is the `aethel-core` library which provides a Rust API for document management:

**Key Functions:**
- `apply_patch(vault_root: &Path, patch: Patch) -> Result<WriteResult, AethelCoreError>` - Create or update documents
- `read_doc(vault_root: &Path, uuid: &Uuid) -> Result<Doc, AethelCoreError>` - Read documents by UUID
- `validate_doc(vault_root: &Path, doc: &Doc) -> Result<(), AethelCoreError>` - Validate documents against schemas
- `load_packs_from_vault(vault_root: &Path) -> Result<Vec<Pack>, AethelCoreError>` - Load available document types

### How to Add as Local Dependency
In your `momentum/Cargo.toml`, add:
```toml
[dependencies]
aethel-core = { path = "/Users/bkase/Documents/aethel/crates/aethel-core" }
```

### Key Data Structures

**Doc** - Represents a document:
```rust
pub struct Doc {
    pub uuid: Uuid,
    pub doc_type: String,  // e.g., "blog", "note"
    pub created: DateTime<Utc>,
    pub updated: DateTime<Utc>,
    pub v: Version,
    pub tags: Vec<String>,
    pub frontmatter_extra: Value,  // Additional fields
    pub body: String,  // Markdown content
}
```

**Patch** - For creating/updating documents:
```rust
pub struct Patch {
    pub uuid: Option<Uuid>,  // None for create
    pub doc_type: Option<String>,  // Required for create
    pub frontmatter: Option<Value>,
    pub body: Option<String>,
    pub mode: PatchMode,
}

pub enum PatchMode {
    Create,
    Append,
    MergeFrontmatter,
    ReplaceBody,
}
```

### Example Usage Patterns

**Creating a new document:**
```rust
use aethel_core::{apply_patch, Patch, PatchMode};
use serde_json::json;

let patch = Patch {
    uuid: None,
    doc_type: Some("reflection".to_string()),
    frontmatter: Some(json!({
        "title": "Deep Work Session Reflection"
    })),
    body: Some("# Reflection\n\nToday's session...".to_string()),
    mode: PatchMode::Create,
};

let result = apply_patch(&vault_root, patch)?;
println!("Created document: {}", result.uuid);
```

**Appending to existing document:**
```rust
let patch = Patch {
    uuid: Some(existing_uuid),
    doc_type: None,
    frontmatter: None,
    body: Some("\n\n## Additional thoughts...".to_string()),
    mode: PatchMode::Append,
};

let result = apply_patch(&vault_root, patch)?;
```

## Integration Path

To integrate Momentum with aethel, we need to:

1. **Create a Momentum Pack** with document types:
   - `momentum.session` - For active session state (replacing session.json)
   - `momentum.reflection` - For reflection documents
   - `momentum.checklist` - For checklist state

2. **Replace file-based storage** with aethel document operations:
   - Session state: Store as a `momentum.session` document with session data in frontmatter
   - Reflections: Store as `momentum.reflection` documents
   - Checklist: Store as a `momentum.checklist` document

3. **Update all file I/O operations** to use aethel-core API:
   - Replace direct file reads/writes with `apply_patch` and `read_doc`
   - Handle UUIDs for document references
   - Manage vault location configuration

4. **Handle migration** from existing file-based storage to aethel vault

5. **Configure vault location** - likely via environment variable or CLI flag