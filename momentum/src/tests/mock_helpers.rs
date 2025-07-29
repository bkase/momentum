use crate::{aethel_storage::*, environment::*, models::*};
use anyhow::Result;
use async_trait::async_trait;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use uuid::Uuid;

// Mock implementations for testing
pub struct MockFileSystem {
    pub files: Arc<Mutex<HashMap<String, String>>>,
}

impl MockFileSystem {
    pub fn new() -> Self {
        Self {
            files: Arc::new(Mutex::new(HashMap::new())),
        }
    }
}

impl FileSystem for MockFileSystem {
    fn read(&self, path: &std::path::Path) -> anyhow::Result<String> {
        let files = self.files.lock().unwrap();
        files
            .get(&path.to_string_lossy().to_string())
            .cloned()
            .ok_or_else(|| anyhow::anyhow!("File not found"))
    }

    fn write(&self, path: &std::path::Path, content: &str) -> anyhow::Result<()> {
        let mut files = self.files.lock().unwrap();
        files.insert(path.to_string_lossy().to_string(), content.to_string());
        Ok(())
    }

    fn delete(&self, path: &std::path::Path) -> anyhow::Result<()> {
        let mut files = self.files.lock().unwrap();
        files.remove(&path.to_string_lossy().to_string());
        Ok(())
    }
}

pub struct MockClock {
    pub time: u64,
}

impl Clock for MockClock {
    fn now(&self) -> u64 {
        self.time
    }
}

pub struct MockApiClient;

#[async_trait]
impl ApiClient for MockApiClient {
    async fn analyze(&self, _content: &str) -> anyhow::Result<AnalysisResult> {
        Ok(AnalysisResult {
            summary: "Test summary".to_string(),
            suggestion: "Test suggestion".to_string(),
            reasoning: "Test reasoning".to_string(),
        })
    }
}

/// Mock aethel storage for testing
pub struct MockAethelStorage {
    pub sessions: Arc<Mutex<HashMap<Uuid, Session>>>,
    pub reflections: Arc<Mutex<HashMap<Uuid, (String, Option<Value>)>>>,
    pub checklist: Arc<Mutex<Option<(Uuid, ChecklistData)>>>,
    pub active_session_uuid: Arc<Mutex<Option<Uuid>>>,
    pub vault_root: PathBuf,
}

impl MockAethelStorage {
    pub fn new() -> Self {
        Self {
            sessions: Arc::new(Mutex::new(HashMap::new())),
            reflections: Arc::new(Mutex::new(HashMap::new())),
            checklist: Arc::new(Mutex::new(None)),
            active_session_uuid: Arc::new(Mutex::new(None)),
            vault_root: PathBuf::from("/tmp/test-vault"),
        }
    }
}

#[async_trait]
impl AethelStorage for MockAethelStorage {
    fn vault_root(&self) -> &Path {
        &self.vault_root
    }

    async fn find_active_session(&self) -> Result<Option<Uuid>> {
        Ok(self.active_session_uuid.lock().unwrap().clone())
    }

    async fn save_session(&self, session: &Session) -> Result<Uuid> {
        let uuid = if let Some(existing_uuid) = *self.active_session_uuid.lock().unwrap() {
            // Update existing session
            self.sessions.lock().unwrap().insert(existing_uuid, session.clone());
            existing_uuid
        } else {
            // Create new session
            let uuid = Uuid::new_v4();
            self.sessions.lock().unwrap().insert(uuid, session.clone());
            *self.active_session_uuid.lock().unwrap() = Some(uuid);
            uuid
        };
        Ok(uuid)
    }

    async fn read_session(&self, uuid: &Uuid) -> Result<Session> {
        self.sessions
            .lock()
            .unwrap()
            .get(uuid)
            .cloned()
            .ok_or_else(|| anyhow::anyhow!("Session not found"))
    }

    async fn delete_session(&self, uuid: &Uuid) -> Result<()> {
        self.sessions.lock().unwrap().remove(uuid);
        if self.active_session_uuid.lock().unwrap().as_ref() == Some(uuid) {
            *self.active_session_uuid.lock().unwrap() = None;
        }
        Ok(())
    }

    async fn create_reflection(
        &self,
        _session: &Session,
        body: String,
    ) -> Result<Uuid> {
        let uuid = Uuid::new_v4();
        self.reflections.lock().unwrap().insert(uuid, (body, None));
        Ok(uuid)
    }

    async fn update_reflection_analysis(
        &self,
        uuid: &Uuid,
        analysis: Value,
    ) -> Result<()> {
        let mut reflections = self.reflections.lock().unwrap();
        if let Some((body, _)) = reflections.get(uuid).cloned() {
            reflections.insert(*uuid, (body, Some(analysis)));
            Ok(())
        } else {
            Err(anyhow::anyhow!("Reflection not found"))
        }
    }

    async fn get_or_create_checklist(&self) -> Result<(Uuid, ChecklistData)> {
        let mut checklist = self.checklist.lock().unwrap();
        if let Some((uuid, data)) = checklist.as_ref() {
            Ok((*uuid, data.clone()))
        } else {
            let uuid = Uuid::new_v4();
            let data = ChecklistData {
                items: vec![
                    ("Test item 1".to_string(), false),
                    ("Test item 2".to_string(), false),
                ],
            };
            *checklist = Some((uuid, data.clone()));
            Ok((uuid, data))
        }
    }

    async fn update_checklist(&self, uuid: &Uuid, checklist_data: &ChecklistData) -> Result<()> {
        let mut checklist = self.checklist.lock().unwrap();
        if let Some((stored_uuid, _)) = checklist.as_ref() {
            if stored_uuid == uuid {
                *checklist = Some((*uuid, checklist_data.clone()));
                Ok(())
            } else {
                Err(anyhow::anyhow!("Checklist UUID mismatch"))
            }
        } else {
            Err(anyhow::anyhow!("No checklist exists"))
        }
    }
}

/// Create a test environment with mock implementations
pub fn create_test_environment() -> Environment {
    Environment {
        file_system: Box::new(MockFileSystem::new()),
        api_client: Box::new(MockApiClient),
        clock: Box::new(MockClock { time: 1700000000 }),
        aethel_storage: Box::new(MockAethelStorage::new()),
    }
}
