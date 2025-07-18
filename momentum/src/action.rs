use std::path::PathBuf;

/// Actions that can be performed in the application
#[derive(Debug, Clone, PartialEq)]
pub enum Action {
    Start { goal: String, time: u64 },
    Stop,
    Analyze { path: PathBuf },
}
