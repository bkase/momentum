use anyhow::Result;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use uuid::Uuid;

/// Manages pack-namespaced indexes for fast document lookup
pub struct IndexManager {
    vault_root: PathBuf,
}

impl IndexManager {
    /// Pack name for index namespacing
    const PACK_NAME: &'static str = "momentum";

    pub fn new(vault_root: PathBuf) -> Self {
        Self { vault_root }
    }

    /// Get the path to the pack-namespaced index file
    pub fn get_index_path(&self) -> PathBuf {
        self.vault_root
            .join(".aethel")
            .join("indexes")
            .join(format!("{}.index.json", Self::PACK_NAME))
    }

    /// Read the index file, returning empty map if not found or corrupted
    pub fn read_index(&self) -> Result<HashMap<String, String>> {
        let index_path = self.get_index_path();
        if !index_path.exists() {
            return Ok(HashMap::new());
        }

        match std::fs::read_to_string(&index_path) {
            Ok(content) => {
                match serde_json::from_str::<HashMap<String, String>>(&content) {
                    Ok(index) => Ok(index),
                    Err(_) => {
                        // Index is corrupted, log and return empty map
                        eprintln!("Warning: Index file corrupted, rebuilding index");
                        Ok(HashMap::new())
                    }
                }
            }
            Err(_) => {
                // File read error, return empty map
                Ok(HashMap::new())
            }
        }
    }

    /// Write the index file, creating directories as needed
    pub fn write_index(&self, index: &HashMap<String, String>) -> Result<()> {
        let index_path = self.get_index_path();

        // Create directories if they don't exist
        if let Some(parent) = index_path.parent() {
            std::fs::create_dir_all(parent)?;
        }

        // Write atomically by writing to temp file first
        let temp_path = index_path.with_extension("tmp");
        let content = serde_json::to_string_pretty(index)?;
        std::fs::write(&temp_path, content)?;
        std::fs::rename(temp_path, index_path)?;

        Ok(())
    }

    /// Update index with a new or updated document UUID
    pub fn update_entry(&self, key: &str, uuid: &Uuid) -> Result<()> {
        let mut index = self.read_index()?;
        index.insert(key.to_string(), uuid.to_string());
        self.write_index(&index)
    }

    /// Remove entry from index
    pub fn remove_entry(&self, key: &str) -> Result<()> {
        let mut index = self.read_index()?;
        index.remove(key);
        self.write_index(&index)
    }

    /// Get UUID from index by key
    pub fn get_entry(&self, key: &str) -> Result<Option<Uuid>> {
        let index = self.read_index()?;
        if let Some(uuid_str) = index.get(key) {
            Ok(Some(Uuid::parse_str(uuid_str)?))
        } else {
            Ok(None)
        }
    }

    /// Migrate existing documents to index by scanning vault
    /// This is called on first run when index doesn't exist
    pub fn migrate_from_vault(&self, vault_root: &Path) -> Result<()> {
        let docs_dir = vault_root.join("docs");
        if !docs_dir.exists() {
            return Ok(());
        }

        let mut index = HashMap::new();

        // Scan all documents to populate index
        for entry in std::fs::read_dir(&docs_dir)?.flatten() {
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) != Some("md") {
                continue;
            }

            if let Ok(content) = std::fs::read_to_string(&path) {
                if let Some((frontmatter, is_archived)) = Self::parse_frontmatter(&content) {
                    // Skip archived documents
                    if is_archived {
                        continue;
                    }

                    if let Some(uuid) = Self::extract_uuid_from_frontmatter(frontmatter) {
                        // Map document types to index keys
                        if frontmatter.contains("type: momentum.session") {
                            index.insert("active_session".to_string(), uuid.to_string());
                        } else if frontmatter.contains("type: momentum.checklist") {
                            index.insert("checklist".to_string(), uuid.to_string());
                        }
                        // Note: We don't index reflections as they're not looked up by type
                    }
                }
            }
        }

        self.write_index(&index)
    }

    /// Parse frontmatter from document content, returning (frontmatter_text, is_archived)
    fn parse_frontmatter(content: &str) -> Option<(&str, bool)> {
        let frontmatter_end = content.find("---\n").and_then(|start| {
            content[start + 4..]
                .find("---\n")
                .map(|end| start + 4 + end)
        })?;

        let frontmatter = &content[4..frontmatter_end];
        let is_archived = frontmatter
            .lines()
            .any(|line| line.trim() == "archived: true");
        Some((frontmatter, is_archived))
    }

    /// Extract UUID from frontmatter text
    fn extract_uuid_from_frontmatter(frontmatter: &str) -> Option<Uuid> {
        frontmatter
            .lines()
            .find_map(|line| line.strip_prefix("uuid: "))
            .and_then(|uuid_str| Uuid::parse_str(uuid_str).ok())
    }
}
