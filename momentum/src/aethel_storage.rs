use aethel_core::{apply_patch, read_doc, Patch, PatchMode};
use anyhow::{anyhow, Result};
use async_trait::async_trait;
use chrono::{DateTime, Utc};
use serde_json::{json, Value};
use std::path::{Path, PathBuf};
use uuid::Uuid;

use crate::index::IndexManager;
use crate::models::{ChecklistData, Session};

/// Trait for interacting with aethel document storage
#[async_trait]
pub trait AethelStorage: Send + Sync {
    /// Get the vault root path
    fn vault_root(&self) -> &Path;

    /// Find the active session document UUID
    async fn find_active_session(&self) -> Result<Option<Uuid>>;

    /// Create or update a session document
    async fn save_session(&self, session: &Session) -> Result<Uuid>;

    /// Read a session document
    async fn read_session(&self, uuid: &Uuid) -> Result<Session>;

    /// Delete a session document
    async fn delete_session(&self, uuid: &Uuid) -> Result<()>;

    /// Create a reflection document
    async fn create_reflection(&self, session: &Session, body: String) -> Result<Uuid>;

    /// Update reflection with analysis
    async fn update_reflection_analysis(&self, uuid: &Uuid, analysis: Value) -> Result<()>;

    /// Get or create checklist document
    async fn get_or_create_checklist(&self) -> Result<(Uuid, ChecklistData)>;

    /// Update checklist document
    async fn update_checklist(&self, uuid: &Uuid, checklist: &ChecklistData) -> Result<()>;
}

pub struct RealAethelStorage {
    vault_root: PathBuf,
    index_manager: IndexManager,
}

impl RealAethelStorage {
    pub fn new(vault_root: PathBuf) -> Self {
        let index_manager = IndexManager::new(vault_root.clone());
        Self {
            vault_root,
            index_manager,
        }
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

    /// Find document by type, optionally filtering out archived documents
    async fn find_document_by_type(
        &self,
        doc_type: &str,
        exclude_archived: bool,
    ) -> Result<Option<Uuid>> {
        let docs_dir = self.vault_root.join("docs");
        if !docs_dir.exists() {
            return Ok(None);
        }

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

    /// Create a patch with common settings
    fn create_patch(
        uuid: Option<Uuid>,
        doc_type: Option<&str>,
        frontmatter: Value,
        body: Option<String>,
    ) -> Patch {
        Patch {
            uuid,
            doc_type: doc_type.map(|s| s.to_string()),
            frontmatter: Some(frontmatter),
            body,
            mode: if uuid.is_none() {
                PatchMode::Create
            } else {
                PatchMode::MergeFrontmatter
            },
        }
    }

    /// Convert checklist items to JSON format
    fn checklist_to_json(items: &[(String, bool)]) -> Vec<Value> {
        items
            .iter()
            .map(|(item, completed)| json!({ "item": item, "completed": completed }))
            .collect()
    }

    /// Extract field from frontmatter with better error messages
    fn extract_field<T>(
        frontmatter: &Value,
        field: &str,
        parser: impl Fn(&Value) -> Option<T>,
    ) -> Result<T> {
        parser(&frontmatter[field])
            .ok_or_else(|| anyhow!("Invalid or missing field '{field}' in document"))
    }

    /// Load checklist template from pack
    fn load_checklist_template(&self) -> Result<Vec<(String, bool)>> {
        let packs_dir = self.vault_root.join("packs");
        let pack_path = std::fs::read_dir(&packs_dir)?
            .flatten()
            .find(|entry| {
                entry.file_name().to_string_lossy().starts_with("momentum@")
                    && entry.path().is_dir()
            })
            .map(|entry| entry.path().join("templates/checklist.md"))
            .ok_or_else(|| {
                anyhow!("Momentum pack not found. Please run momentum to install it first.")
            })?;

        if !pack_path.exists() {
            return Err(anyhow!(
                "Checklist template not found at: {}",
                pack_path.display()
            ));
        }

        let template_content = std::fs::read_to_string(&pack_path)?;
        let items: Vec<_> = template_content
            .lines()
            .filter_map(|line| {
                line.trim_start()
                    .strip_prefix("- ")
                    .or_else(|| line.trim_start().strip_prefix("* "))
                    .or_else(|| line.trim_start().strip_prefix("+ "))
                    .map(|text| (text.to_string(), false))
            })
            .collect();

        if items.is_empty() {
            Err(anyhow!("Checklist template contains no items"))
        } else {
            Ok(items)
        }
    }
}

#[async_trait]
impl AethelStorage for RealAethelStorage {
    fn vault_root(&self) -> &Path {
        &self.vault_root
    }

    async fn find_active_session(&self) -> Result<Option<Uuid>> {
        // Try index lookup first
        if let Ok(Some(uuid)) = self.index_manager.get_entry("active_session") {
            // Verify the document still exists and is not archived
            if let Ok(doc) = read_doc(&self.vault_root, &uuid) {
                let is_archived = doc
                    .frontmatter_extra
                    .get("archived")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false);
                if !is_archived {
                    return Ok(Some(uuid));
                }
            }
            // Document is archived or missing, remove from index
            let _ = self.index_manager.remove_entry("active_session");
        }

        // Fallback to linear search and update index
        if let Some(uuid) = self.find_document_by_type("momentum.session", true).await? {
            let _ = self.index_manager.update_entry("active_session", &uuid);
            Ok(Some(uuid))
        } else {
            Ok(None)
        }
    }

    async fn save_session(&self, session: &Session) -> Result<Uuid> {
        let existing_uuid = self.find_document_by_type("momentum.session", true).await?;

        let frontmatter = json!({
            "goal": session.goal,
            "start_time": session.start_time,
            "time_expected": session.time_expected,
            "reflection_uuid": session.reflection_file_path,
        });

        let body = format!(
            "# Active Session: {}\n\nStarted at: {}",
            session.goal,
            DateTime::<Utc>::from_timestamp(session.start_time as i64, 0)
                .unwrap_or_default()
                .format("%Y-%m-%d %H:%M:%S UTC")
        );

        let patch = Self::create_patch(
            existing_uuid,
            if existing_uuid.is_none() {
                Some("momentum.session")
            } else {
                None
            },
            frontmatter,
            Some(body),
        );

        let result = apply_patch(&self.vault_root, patch)?;

        // Update index
        let _ = self
            .index_manager
            .update_entry("active_session", &result.uuid);

        Ok(result.uuid)
    }

    async fn read_session(&self, uuid: &Uuid) -> Result<Session> {
        let doc = read_doc(&self.vault_root, uuid)?;
        let fm = &doc.frontmatter_extra;

        Ok(Session {
            goal: Self::extract_field(fm, "goal", |v| v.as_str().map(|s| s.to_string()))?,
            start_time: Self::extract_field(fm, "start_time", |v| v.as_u64())?,
            time_expected: Self::extract_field(fm, "time_expected", |v| v.as_u64())?,
            reflection_file_path: fm["reflection_uuid"].as_str().map(|s| s.to_string()),
        })
    }

    async fn delete_session(&self, uuid: &Uuid) -> Result<()> {
        let patch = Self::create_patch(Some(*uuid), None, json!({"archived": true}), None);
        apply_patch(&self.vault_root, patch)?;

        // Remove from index since archived sessions are excluded from active session lookups
        let _ = self.index_manager.remove_entry("active_session");

        Ok(())
    }

    async fn create_reflection(&self, session: &Session, body: String) -> Result<Uuid> {
        let end_time = Utc::now().timestamp() as u64;
        let frontmatter = json!({
            "goal": session.goal,
            "start_time": session.start_time,
            "end_time": end_time,
            "time_expected": session.time_expected,
            "time_actual": (end_time - session.start_time) / 60,
        });

        let patch = Self::create_patch(None, Some("momentum.reflection"), frontmatter, Some(body));
        Ok(apply_patch(&self.vault_root, patch)?.uuid)
    }

    async fn update_reflection_analysis(&self, uuid: &Uuid, analysis: Value) -> Result<()> {
        let patch = Self::create_patch(Some(*uuid), None, json!({"analysis": analysis}), None);
        apply_patch(&self.vault_root, patch)?;
        Ok(())
    }

    async fn get_or_create_checklist(&self) -> Result<(Uuid, ChecklistData)> {
        // Try index lookup first
        if let Ok(Some(uuid)) = self.index_manager.get_entry("checklist") {
            if let Ok(doc) = read_doc(&self.vault_root, &uuid) {
                if let Ok(items) = Self::extract_field(&doc.frontmatter_extra, "items", |v| {
                    v.as_array().map(|arr| {
                        arr.iter()
                            .filter_map(|item| {
                                Some((
                                    item["item"].as_str()?.to_string(),
                                    item["completed"].as_bool()?,
                                ))
                            })
                            .collect()
                    })
                }) {
                    return Ok((uuid, ChecklistData { items }));
                }
            }
            // Document is missing or corrupted, remove from index
            let _ = self.index_manager.remove_entry("checklist");
        }

        // Fallback to linear search or create new checklist
        if let Some(uuid) = self
            .find_document_by_type("momentum.checklist", false)
            .await?
        {
            let doc = read_doc(&self.vault_root, &uuid)?;
            let items = Self::extract_field(&doc.frontmatter_extra, "items", |v| {
                v.as_array().map(|arr| {
                    arr.iter()
                        .filter_map(|item| {
                            Some((
                                item["item"].as_str()?.to_string(),
                                item["completed"].as_bool()?,
                            ))
                        })
                        .collect()
                })
            })?;

            // Update index
            let _ = self.index_manager.update_entry("checklist", &uuid);
            Ok((uuid, ChecklistData { items }))
        } else {
            // Create new checklist
            let items = self.load_checklist_template()?;
            let checklist = ChecklistData { items };

            let frontmatter = json!({ "items": Self::checklist_to_json(&checklist.items) });
            let body = "# Pre-Session Checklist\n\nComplete these items before starting your focus session.".to_string();

            let patch =
                Self::create_patch(None, Some("momentum.checklist"), frontmatter, Some(body));
            let result = apply_patch(&self.vault_root, patch)?;

            // Update index
            let _ = self.index_manager.update_entry("checklist", &result.uuid);
            Ok((result.uuid, checklist))
        }
    }

    async fn update_checklist(&self, uuid: &Uuid, checklist: &ChecklistData) -> Result<()> {
        let frontmatter = json!({ "items": Self::checklist_to_json(&checklist.items) });
        let patch = Self::create_patch(Some(*uuid), None, frontmatter, None);
        apply_patch(&self.vault_root, patch)?;
        Ok(())
    }
}
