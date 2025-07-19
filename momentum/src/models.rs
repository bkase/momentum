use serde::{Deserialize, Serialize};

/// Represents an active focus session
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Session {
    pub goal: String,
    pub start_time: u64,    // Unix timestamp
    pub time_expected: u64, // Minutes
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reflection_file_path: Option<String>,
}

/// Represents the analysis result from Claude API
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub summary: String,
    pub suggestion: String,
    pub reasoning: String,
}

/// Represents a single checklist item
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ChecklistItem {
    pub id: String,
    pub text: String,
    pub on: bool,
}

/// Represents the full checklist state
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ChecklistState {
    pub items: Vec<ChecklistItem>,
}

impl ChecklistState {
    /// Check if all items are completed
    pub fn all_completed(&self) -> bool {
        self.items.iter().all(|item| item.on)
    }
}

/// Template item from checklist.json
#[derive(Debug, Clone, Deserialize)]
pub struct ChecklistTemplate {
    pub id: String,
    pub text: String,
}
