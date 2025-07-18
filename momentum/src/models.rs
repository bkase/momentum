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
