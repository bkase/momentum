use anyhow::{anyhow, Result};
use aethel_core::{apply_patch, read_doc, Doc, Patch, PatchMode, WriteResult};
use async_trait::async_trait;
use chrono::{DateTime, Utc};
use serde_json::{json, Value};
use std::path::{Path, PathBuf};
use uuid::Uuid;

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
    async fn create_reflection(
        &self,
        session: &Session,
        body: String,
    ) -> Result<Uuid>;

    /// Update reflection with analysis
    async fn update_reflection_analysis(
        &self,
        uuid: &Uuid,
        analysis: Value,
    ) -> Result<()>;

    /// Get or create checklist document
    async fn get_or_create_checklist(&self) -> Result<(Uuid, ChecklistData)>;

    /// Update checklist document
    async fn update_checklist(&self, uuid: &Uuid, checklist: &ChecklistData) -> Result<()>;
}

pub struct RealAethelStorage {
    vault_root: PathBuf,
}

impl RealAethelStorage {
    pub fn new(vault_root: PathBuf) -> Self {
        Self { vault_root }
    }

    /// Find active session by looking for momentum.session documents
    async fn find_session_uuid(&self) -> Result<Option<Uuid>> {
        let docs_dir = self.vault_root.join("docs");
        if !docs_dir.exists() {
            return Ok(None);
        }

        // Read all files in docs directory
        let entries = std::fs::read_dir(&docs_dir)?;
        
        for entry in entries {
            let entry = entry?;
            let path = entry.path();
            
            if path.extension().and_then(|s| s.to_str()) == Some("md") {
                // Try to read as aethel document
                if let Ok(content) = std::fs::read_to_string(&path) {
                    // Parse YAML frontmatter to check type
                    if let Some(frontmatter_end) = content.find("---\n").and_then(|start| {
                        content[start + 4..].find("---\n").map(|end| start + 4 + end)
                    }) {
                        let frontmatter = &content[4..frontmatter_end];
                        if frontmatter.contains("type: momentum.session") {
                            // Extract UUID from frontmatter
                            for line in frontmatter.lines() {
                                if let Some(uuid_str) = line.strip_prefix("uuid: ") {
                                    if let Ok(uuid) = Uuid::parse_str(uuid_str) {
                                        return Ok(Some(uuid));
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        Ok(None)
    }

    /// Find checklist document UUID
    async fn find_checklist_uuid(&self) -> Result<Option<Uuid>> {
        let docs_dir = self.vault_root.join("docs");
        if !docs_dir.exists() {
            return Ok(None);
        }

        let entries = std::fs::read_dir(&docs_dir)?;
        
        for entry in entries {
            let entry = entry?;
            let path = entry.path();
            
            if path.extension().and_then(|s| s.to_str()) == Some("md") {
                if let Ok(content) = std::fs::read_to_string(&path) {
                    if let Some(frontmatter_end) = content.find("---\n").and_then(|start| {
                        content[start + 4..].find("---\n").map(|end| start + 4 + end)
                    }) {
                        let frontmatter = &content[4..frontmatter_end];
                        if frontmatter.contains("type: momentum.checklist") {
                            for line in frontmatter.lines() {
                                if let Some(uuid_str) = line.strip_prefix("uuid: ") {
                                    if let Ok(uuid) = Uuid::parse_str(uuid_str) {
                                        return Ok(Some(uuid));
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        Ok(None)
    }
}

#[async_trait]
impl AethelStorage for RealAethelStorage {
    fn vault_root(&self) -> &Path {
        &self.vault_root
    }

    async fn find_active_session(&self) -> Result<Option<Uuid>> {
        self.find_session_uuid().await
    }

    async fn save_session(&self, session: &Session) -> Result<Uuid> {
        // Check if we already have a session document
        let existing_uuid = self.find_session_uuid().await?;
        
        let patch = Patch {
            uuid: existing_uuid,
            doc_type: if existing_uuid.is_none() {
                Some("momentum.session".to_string())
            } else {
                None
            },
            frontmatter: Some(json!({
                "goal": session.goal,
                "start_time": session.start_time,
                "time_expected": session.time_expected,
                "reflection_uuid": session.reflection_file_path,
            })),
            body: Some(format!("# Active Session: {}\n\nStarted at: {}", 
                session.goal,
                DateTime::<Utc>::from_timestamp(session.start_time as i64, 0)
                    .unwrap_or_default()
                    .format("%Y-%m-%d %H:%M:%S UTC")
            )),
            mode: if existing_uuid.is_none() {
                PatchMode::Create
            } else {
                PatchMode::MergeFrontmatter
            },
        };

        let result = apply_patch(&self.vault_root, patch)?;
        Ok(result.uuid)
    }

    async fn read_session(&self, uuid: &Uuid) -> Result<Session> {
        let doc = read_doc(&self.vault_root, uuid)?;
        
        let goal = doc.frontmatter_extra["goal"]
            .as_str()
            .ok_or_else(|| anyhow!("Session missing goal"))?
            .to_string();
            
        let start_time = doc.frontmatter_extra["start_time"]
            .as_u64()
            .ok_or_else(|| anyhow!("Session missing start_time"))?;
            
        let time_expected = doc.frontmatter_extra["time_expected"]
            .as_u64()
            .ok_or_else(|| anyhow!("Session missing time_expected"))?;
            
        let reflection_file_path = doc.frontmatter_extra["reflection_uuid"]
            .as_str()
            .map(|s| s.to_string());

        Ok(Session {
            goal,
            start_time,
            time_expected,
            reflection_file_path,
        })
    }

    async fn delete_session(&self, uuid: &Uuid) -> Result<()> {
        // In aethel, we don't delete documents, we could mark them as archived
        // For now, we'll clear the session data
        let patch = Patch {
            uuid: Some(*uuid),
            doc_type: None,
            frontmatter: Some(json!({
                "archived": true,
            })),
            body: None,
            mode: PatchMode::MergeFrontmatter,
        };
        
        apply_patch(&self.vault_root, patch)?;
        Ok(())
    }

    async fn create_reflection(
        &self,
        session: &Session,
        body: String,
    ) -> Result<Uuid> {
        let end_time = Utc::now().timestamp() as u64;
        let time_actual = (end_time - session.start_time) / 60;
        
        let patch = Patch {
            uuid: None,
            doc_type: Some("momentum.reflection".to_string()),
            frontmatter: Some(json!({
                "goal": session.goal,
                "start_time": session.start_time,
                "end_time": end_time,
                "time_expected": session.time_expected,
                "time_actual": time_actual,
            })),
            body: Some(body),
            mode: PatchMode::Create,
        };

        let result = apply_patch(&self.vault_root, patch)?;
        Ok(result.uuid)
    }

    async fn update_reflection_analysis(
        &self,
        uuid: &Uuid,
        analysis: Value,
    ) -> Result<()> {
        let patch = Patch {
            uuid: Some(*uuid),
            doc_type: None,
            frontmatter: Some(json!({
                "analysis": analysis,
            })),
            body: None,
            mode: PatchMode::MergeFrontmatter,
        };
        
        apply_patch(&self.vault_root, patch)?;
        Ok(())
    }

    async fn get_or_create_checklist(&self) -> Result<(Uuid, ChecklistData)> {
        if let Some(uuid) = self.find_checklist_uuid().await? {
            let doc = read_doc(&self.vault_root, &uuid)?;
            let items = doc.frontmatter_extra["items"]
                .as_array()
                .ok_or_else(|| anyhow!("Checklist missing items"))?
                .iter()
                .map(|item| {
                    Ok((
                        item["item"].as_str()
                            .ok_or_else(|| anyhow!("Invalid checklist item"))?
                            .to_string(),
                        item["completed"].as_bool()
                            .ok_or_else(|| anyhow!("Invalid completed status"))?,
                    ))
                })
                .collect::<Result<Vec<_>>>()?;
            
            Ok((uuid, ChecklistData { items }))
        } else {
            // Create new checklist with default items
            let default_checklist = ChecklistData::default();
            
            let patch = Patch {
                uuid: None,
                doc_type: Some("momentum.checklist".to_string()),
                frontmatter: Some(json!({
                    "items": default_checklist.items.iter().map(|(item, completed)| {
                        json!({
                            "item": item,
                            "completed": completed,
                        })
                    }).collect::<Vec<_>>(),
                })),
                body: Some("# Pre-Session Checklist\n\nComplete these items before starting your focus session.".to_string()),
                mode: PatchMode::Create,
            };
            
            let result = apply_patch(&self.vault_root, patch)?;
            Ok((result.uuid, default_checklist))
        }
    }

    async fn update_checklist(&self, uuid: &Uuid, checklist: &ChecklistData) -> Result<()> {
        let patch = Patch {
            uuid: Some(*uuid),
            doc_type: None,
            frontmatter: Some(json!({
                "items": checklist.items.iter().map(|(item, completed)| {
                    json!({
                        "item": item,
                        "completed": completed,
                    })
                }).collect::<Vec<_>>(),
            })),
            body: None,
            mode: PatchMode::MergeFrontmatter,
        };
        
        apply_patch(&self.vault_root, patch)?;
        Ok(())
    }
}