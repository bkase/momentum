# Codebase Analysis for Pack-Namespaced Indexing

## Current Aethel Storage Implementation Analysis

### File Locations and Structure

**Key Files:**
- `/Users/bkase/Documents/momentum/todos/worktrees/2025-08-02-19-40-42-make-finding-needed-momentum-files-not-linear-search-through-all-docs/momentum/src/aethel_storage.rs` - Main storage implementation
- `/Users/bkase/Documents/momentum/todos/worktrees/2025-08-02-19-40-42-make-finding-needed-momentum-files-not-linear-search-through-all-docs/momentum/src/environment.rs` - Dependency injection
- `/Users/bkase/Documents/momentum/todos/worktrees/2025-08-02-19-40-42-make-finding-needed-momentum-files-not-linear-search-through-all-docs/momentum/src/state.rs` - State management using aethel storage

### Current Linear Search Implementation

The **performance bottleneck** is in the `find_document_by_type` function at **lines 74-106** in `aethel_storage.rs`:

```rust
async fn find_document_by_type(
    &self,
    doc_type: &str,
    exclude_archived: bool,
) -> Result<Option<Uuid>> {
    let docs_dir = self.vault_root.join("docs");
    if !docs_dir.exists() {
        return Ok(None);
    }

    // THIS IS THE LINEAR SEARCH PROBLEM
    for entry in std::fs::read_dir(&docs_dir)?.flatten() {
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("md") {
            continue;
        }

        // READS EVERY MARKDOWN FILE IN THE VAULT
        if let Ok(content) = std::fs::read_to_string(&path) {
            if let Some((frontmatter, is_archived)) = Self::parse_frontmatter(&content) {
                if frontmatter.contains(&format!("type: {doc_type}")) {
                    if exclude_archived && is_archived {
                        continue;
                    }
                    if let Some(uuid) = Self::extract_uuid_from_frontmatter(frontmatter) {
                        return Ok(Some(uuid));
                    }
                }
            }
        }
    }

    Ok(None)
}
```

### Where the Linear Search is Used

This linear search is called by:

1. **`find_active_session()`** (line 194) - Called every time the app needs to check for an active session
2. **`save_session()`** (line 198) - Called when creating/updating sessions  
3. **`get_or_create_checklist()`** (line 269) - Called when loading checklist data

### Current Vault Structure

The Aethel vault is organized as:
```
vault_root/
├── docs/           # All documents stored as UUID.md files
│   ├── <uuid1>.md  # momentum.session documents
│   ├── <uuid2>.md  # momentum.reflection documents  
│   ├── <uuid3>.md  # momentum.checklist documents
│   └── ...         # Could contain hundreds/thousands of docs
└── packs/          # Document type definitions
    └── momentum@<version>/
        └── templates/
            └── checklist.md
```

### Document Types Used by Momentum

1. **`momentum.session`** - Active focus sessions (usually 0-1 at a time)
2. **`momentum.reflection`** - Completed session reflections (grows over time)
3. **`momentum.checklist`** - Pre-session checklist (usually 1 document)

### Performance Problem

**Every time** the app needs to find a momentum document (session, checklist, etc.), it:
1. Reads **every `.md` file** in the `docs/` directory 
2. Parses the YAML frontmatter from each file
3. Checks if the `type:` field matches what it's looking for
4. This scales **O(n)** with the total number of documents in the vault

For a vault with thousands of documents, this becomes extremely slow for simple operations like checking if there's an active session.

### Current Indexing Mechanisms

**None found** - There is currently no indexing system. The aethel-core library provides:
- `read_doc(uuid)` - Direct UUID-based lookup (fast)
- `apply_patch()` - Document creation/updates  
- No built-in type-based indexing

### Proposed Solution Areas

The linear search could be optimized by:

1. **Document organization by type** - Store documents in subdirectories by type
2. **In-memory caching** - Cache document metadata and UUID mappings
3. **Type-based indexing** - Maintain index files mapping document types to UUIDs
4. **Filesystem-based optimization** - Use naming conventions or symlinks

The implementation needs to be **backward-compatible** with existing aethel vaults and the aethel-core library interface.

## Momentum-Aethel Integration Architecture

### 1. **External Aethel Directory and Submodule References**
- **Location**: `/external/aethel/` - This is a git submodule containing the aethel-core library
- **Dependency**: Defined in `momentum/Cargo.toml` as `aethel-core = { path = "../external/aethel/crates/aethel-core" }`
- **Current Status**: The external/aethel directory exists but appears to be empty in this worktree

### 2. **Vault Path Configuration and Usage**
The vault path is configured through a hierarchical approach:

**Path Resolution** (in `/Users/bkase/Documents/momentum/todos/worktrees/2025-08-02-19-40-42-make-finding-needed-momentum-files-not-linear-search-through-all-docs/momentum/src/environment.rs`):
```rust
pub fn get_vault_root() -> Result<PathBuf> {
    // 1. Check environment variable first
    if let Ok(vault_path) = std::env::var("MOMENTUM_VAULT_PATH") {
        return Ok(PathBuf::from(vault_path));
    }
    
    // 2. Default to ~/Documents/vault
    let mut path = dirs::home_dir()?.push("Documents").push("vault");
    Ok(path)
}
```

**Vault Structure**:
- `<vault>/docs/` - Where all documents are stored as markdown files
- `<vault>/packs/` - Where momentum pack is installed
- `<vault>/packs/momentum@0.2.0/` - Current momentum pack version

### 3. **Current Linear Search Problem**
The current implementation uses **linear search** through all documents in the vault:

**Critical Linear Search Code** (in `/Users/bkase/Documents/momentum/todos/worktrees/2025-08-02-19-40-42-make-finding-needed-momentum-files-not-linear-search-through-all-docs/momentum/src/aethel_storage.rs` lines 75-106):
```rust
async fn find_document_by_type(
    &self,
    doc_type: &str,
    exclude_archived: bool,
) -> Result<Option<Uuid>> {
    let docs_dir = self.vault_root.join("docs");
    
    // LINEAR SEARCH: Iterates through ALL documents
    for entry in std::fs::read_dir(&docs_dir)?.flatten() {
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("md") {
            continue;
        }

        if let Ok(content) = std::fs::read_to_string(&path) {
            if let Some((frontmatter, is_archived)) = Self::parse_frontmatter(&content) {
                if frontmatter.contains(&format!("type: {doc_type}")) {
                    if exclude_archived && is_archived {
                        continue;
                    }
                    if let Some(uuid) = Self::extract_uuid_from_frontmatter(frontmatter) {
                        return Ok(Some(uuid));
                    }
                }
            }
        }
    }
    Ok(None)
}
```

This function is called by:
- `find_active_session()` - to find `momentum.session` documents
- `get_or_create_checklist()` - to find `momentum.checklist` documents

### 4. **Document Creation, Reading, and Management Patterns**

**Document Types Managed**:
1. **Sessions** (`momentum.session`) - Active focus sessions
2. **Reflections** (`momentum.reflection`) - Post-session reflections
3. **Checklists** (`momentum.checklist`) - Pre-session preparation items

**Document Management Flow**:
- **Create**: Uses `aethel_core::apply_patch()` with `PatchMode::Create`
- **Read**: Uses `aethel_core::read_doc()` by UUID
- **Update**: Uses `aethel_core::apply_patch()` with `PatchMode::MergeFrontmatter`
- **Delete**: Archives document by setting `archived: true` in frontmatter

### 5. **UUID Generation and Document ID Handling**

**UUID Usage**:
- **Generation**: Automatic via `aethel_core::apply_patch()` when creating new documents
- **Storage**: UUIDs are stored in document frontmatter as `uuid: <uuid-string>`
- **Retrieval**: Documents are accessed by UUID using `aethel_core::read_doc()`

**Document Schema Examples**:
```json
// Session document frontmatter
{
  "goal": "string",
  "start_time": 1234567890,
  "time_expected": 60,
  "reflection_uuid": "optional-uuid"
}

// Reflection document frontmatter  
{
  "goal": "string", 
  "start_time": 1234567890,
  "end_time": 1234567950,
  "time_expected": 60,
  "time_actual": 58,
  "analysis": { "summary": "...", "suggestion": "...", "reasoning": "..." }
}
```

### 6. **No Current Index Files or Index Management**

**Current State**: There is **NO** existing `.aethel` directory or index management system. The task description in `/Users/bkase/Documents/momentum/todos/worktrees/2025-08-02-19-40-42-make-finding-needed-momentum-files-not-linear-search-through-all-docs/task.md` outlines the proposed solution:

**Proposed Index Convention**:
- **Directory**: `<vault>/.aethel/indexes/`
- **File**: `<vault>/.aethel/indexes/momentum.index.json`
- **Content**:
```json
{
  "active_session": "f81d4fae-7dec-11d0-a765-00a0c91e6bf6",
  "checklist": "7b2e3f8a-8e4c-4a3a-9c7a-1b1e1a1e1a1e"
}
```

### 7. **Pack System Integration**

**Momentum Pack Structure**:
- **Version**: 0.2.0 (defined in `MOMENTUM_PACK_VERSION`)
- **Pack Installation**: Automatic via `vault_init::initialize_vault()`
- **Pack Contents**:
  - `pack.json` - Pack metadata
  - `types/*.json` - JSON schemas for document types
  - `templates/checklist.md` - Default checklist template

The pack system is well-integrated but currently relies on linear search to find documents of specific types, which is the core performance issue this task aims to solve.

**Key Takeaway**: The current architecture is solid but suffers from O(n) document lookup performance. The proposed pack-namespaced index system would provide O(1) lookups for frequently accessed documents like active sessions and checklists.