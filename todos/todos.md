# Todos

## 1. Loading spinner for AI analysis

The loading spinner isn't sufficient for such a long-running process -- we need to make the ux affordance better somehow.

## 2. AI Analysis Storage

A file should be created next to the reflection file with the results of the analysis that appear in the UI after the analysis step.

## 3. Make finding needed momentum files not linear search through all docs

Right now, it's a linear search over all of the Vault docs in order to find the needed active session files for Momentum. We need a mechanism for interacting with the Vault where it doesn't require this linear search.

Namespacing the index file by the pack name is the perfect way to formalize this convention within the Aethel ecosystem.

You've hit on a key principle: a pack should be a self-contained unit of functionality, and that should include its private indexes. Your suggestion prevents index key collisions between different packs and keeps the `.aethel` directory clean and organized as a vault grows.

Let's formalize this improved convention.

### The Pack-Namespaced Index Convention

The new convention will be:

- **Directory:** All lightweight, key-value indexes will be stored in a dedicated subdirectory: `<vault>/.aethel/indexes/`
- **Filename:** The index file for a specific pack will be named after the pack itself, with a `.index.json` suffix.

For the `momentum` pack, the path would be:

`<vault>/.aethel/indexes/momentum.index.json`

**Content of `momentum.index.json`:**

```json
{
  "active_session": "f81d4fae-7dec-11d0-a765-00a0c91e6bf6",
  "checklist": "7b2e3f8a-8e4c-4a3a-9c7a-1b1e1a1e1a1e"
}
```

#### Advantages of This Convention

- **No Collisions:** A `journal` pack could have its own `journal.index.json` with keys like `"daily_note_template"` without ever conflicting with Momentum's keys.
- **Modularity:** It reinforces that the index is a private implementation detail of the pack. The logic for managing and interpreting this index belongs entirely to the `momentum` pack.
- **Maintainability:** When a pack is removed, its corresponding index file can be safely deleted, cleaning up the vault without affecting other packs.
- **Clarity:** The file path itself is now self-documenting.

### Updated Refactoring Plan for Momentum

The workflow remains the same, but the implementation will now be cleaner and more robust.

1. **Create a Namespaced Index Helper:**
    - In `momentum/src/aethel_storage.rs`, the helper functions for the index should be designed to work specifically for the `momentum` pack.
    - Define a constant for the pack name: `const PACK_NAME: &str = "momentum";`
    - The `get_index_path()` function will now construct the path like this:

      ```rust
      fn get_index_path(vault_root: &Path) -> PathBuf {
          vault_root
              .join(".aethel")
              .join("indexes")
              .join(format!("{}.index.json", PACK_NAME))
      }
      ```

    - When writing the index, ensure the `.aethel/indexes/` directory is created first using `std::fs::create_dir_all()`.

2. **Refactor `find_active_session`:**
    - The logic is identical, but it now reads from the new, namespaced path: `<vault>/.aethel/indexes/momentum.index.json`.

3. **Refactor `save_session`:**
    - After `apply_patch` returns the new session `Doc`'s UUID, the code will read, update, and write to `momentum.index.json`.

4. **Refactor `delete_session`:**
    - When stopping a session, the code will read, update (by removing the `active_session` key), and write back to `momentum.index.json`.

This is the perfect example of how an application should build upon Aethel. You're using the core L0 primitives for atomic document storage and the optional L2 conventions (`.aethel/` directory) for application-specific performance optimizations. This is a robust, scalable, and idiomatic solution. I will proceed with this improved design.

