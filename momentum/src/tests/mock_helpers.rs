use crate::{environment::*, models::*};
use async_trait::async_trait;
use std::collections::HashMap;
use std::sync::Mutex;

// Mock implementations for testing
pub struct MockFileSystem {
    files: Mutex<HashMap<String, String>>,
}

impl MockFileSystem {
    pub fn new() -> Self {
        Self {
            files: Mutex::new(HashMap::new()),
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
