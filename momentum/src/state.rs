use crate::environment::Environment;
use crate::models::Session;
use anyhow::Result;
use serde::{Deserialize, Serialize};

/// The application state
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum State {
    Idle,
    SessionActive { session: Session },
}

impl State {
    /// Load state from session.json if it exists
    pub fn load(env: &Environment) -> Result<Self> {
        let session_path = env.get_session_path()?;

        // Try to read the file, if it doesn't exist, return Idle
        match env.file_system.read(&session_path) {
            Ok(content) => {
                let session: Session = serde_json::from_str(&content)?;
                Ok(State::SessionActive { session })
            }
            Err(_) => Ok(State::Idle),
        }
    }

    /// Save state to session.json
    #[allow(dead_code)]
    pub fn save(&self, env: &Environment) -> Result<()> {
        match self {
            State::Idle => {
                // Delete session.json if it exists
                let session_path = env.get_session_path()?;
                // Try to delete, ignore error if file doesn't exist
                let _ = env.file_system.delete(&session_path);
            }
            State::SessionActive { session } => {
                let session_path = env.get_session_path()?;
                let content = serde_json::to_string_pretty(session)?;
                env.file_system.write(&session_path, &content)?;
            }
        }
        Ok(())
    }
}
