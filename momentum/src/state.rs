use crate::environment::Environment;
use crate::models::Session;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// The application state
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum State {
    Idle,
    SessionActive {
        session: Session,
        #[serde(skip_serializing_if = "Option::is_none")]
        session_uuid: Option<Uuid>,
    },
}

impl State {
    /// Load state from aethel documents
    pub async fn load(env: &Environment) -> Result<Self> {
        // Look for active session document in aethel vault
        match env.aethel_storage.find_active_session().await? {
            Some(uuid) => {
                let session = env.aethel_storage.read_session(&uuid).await?;
                Ok(State::SessionActive {
                    session,
                    session_uuid: Some(uuid),
                })
            }
            None => Ok(State::Idle),
        }
    }

    /// Save state to aethel documents
    pub async fn save(&self, env: &Environment) -> Result<Option<Uuid>> {
        match self {
            State::Idle => {
                // If we have a session UUID, mark it as archived
                if let Ok(Some(uuid)) = env.aethel_storage.find_active_session().await {
                    env.aethel_storage.delete_session(&uuid).await?;
                }
                Ok(None)
            }
            State::SessionActive {
                session,
                session_uuid,
            } => {
                // Save or update session document
                let uuid = if let Some(existing_uuid) = session_uuid {
                    // Update existing
                    env.aethel_storage.save_session(session).await?;
                    *existing_uuid
                } else {
                    // Create new
                    env.aethel_storage.save_session(session).await?
                };
                Ok(Some(uuid))
            }
        }
    }
}
