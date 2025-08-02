use crate::environment::Environment;
use crate::models::{ChecklistItem, ChecklistState, Session};
use anyhow::Result;
use std::path::PathBuf;

/// Sanitize a goal string for use in a filename
#[cfg(test)]
pub fn sanitize_goal_for_filename(goal: &str) -> String {
    goal.to_lowercase()
        .chars()
        .map(|c| if c == ' ' { '-' } else { c })
        .collect()
}

/// Side effects that can be executed
#[derive(Debug, Clone)]
pub enum Effect {
    CreateReflection {
        session: Session,
    },
    AnalyzeReflection {
        path: PathBuf,
    },
    PrintError {
        message: String,
    },
    #[allow(dead_code)]
    SaveState {
        state: crate::state::State,
    },
    ClearState,
    Composite(Vec<Effect>),
    LoadAndPrintChecklist,
    ToggleChecklistItem {
        id: String,
    },
    ValidateChecklistAndStart {
        goal: String,
        time: u64,
    },
    PrintSession {
        state: crate::state::State,
    },
}

/// Execute side effects
pub async fn execute(effect: Effect, env: &Environment) -> Result<()> {
    match effect {
        Effect::CreateReflection { mut session } => {
            // Load template
            let template_content = include_str!("../../reflection-template.md");

            // Calculate time taken
            let current_time = env.clock.now();
            let time_taken = (current_time - session.start_time) / 60; // Convert to minutes

            // Replace template variables
            let content = template_content
                .replace("{{goal}}", &session.goal)
                .replace("{{time_taken}}", &time_taken.to_string())
                .replace("{{time_expected}}", &session.time_expected.to_string());

            // Create reflection document in aethel
            let reflection_uuid = env
                .aethel_storage
                .create_reflection(&session, content)
                .await?;

            // Update session with reflection UUID
            session.reflection_file_path = Some(reflection_uuid.to_string());

            // Save updated session
            let state = crate::state::State::SessionActive {
                session,
                session_uuid: None, // We don't have the session UUID here
            };
            state.save(env).await?;

            // Print the full file path to stdout for the Swift app
            let reflection_path = env
                .aethel_storage
                .vault_root()
                .join("docs")
                .join(format!("{reflection_uuid}.md"));
            println!("{}", reflection_path.display());
            Ok(())
        }

        Effect::AnalyzeReflection { path } => {
            // Check if this is an aethel document by extracting UUID from path or raw UUID
            let uuid = if let Some(filename) = path.file_name() {
                // Try to extract UUID from filename (e.g., "uuid.md" -> "uuid")
                let filename_str = filename.to_str().unwrap_or("");
                if let Some(uuid_str) = filename_str.strip_suffix(".md") {
                    uuid::Uuid::parse_str(uuid_str).ok()
                } else {
                    // Try parsing the filename itself as a UUID (backward compatibility)
                    uuid::Uuid::parse_str(filename_str).ok()
                }
            } else {
                // Try to parse the entire path as UUID (backward compatibility)
                uuid::Uuid::parse_str(path.to_str().unwrap_or("")).ok()
            };

            let content = if let Some(uuid) = uuid {
                // Read from aethel
                let doc = aethel_core::read_doc(env.aethel_storage.vault_root(), &uuid)?;
                doc.body
            } else {
                // Fall back to file system for backward compatibility
                env.file_system.read(&path)?
            };

            // Call Claude API for analysis
            let result = env.api_client.analyze(&content).await?;

            // If this was an aethel document, update it with the analysis
            if let Some(uuid) = uuid {
                env.aethel_storage
                    .update_reflection_analysis(&uuid, serde_json::to_value(&result)?)
                    .await?;
            }

            // Print the raw JSON result to stdout
            let json = serde_json::to_string(&result)?;
            println!("{json}");
            Ok(())
        }

        Effect::PrintError { message } => {
            eprintln!("{message}");
            Ok(())
        }

        Effect::SaveState { state } => {
            // Save state to aethel storage
            state.save(env).await?;
            Ok(())
        }

        Effect::ClearState => {
            // Clear session from aethel storage
            crate::state::State::Idle.save(env).await?;
            Ok(())
        }

        Effect::Composite(effects) => {
            // Execute multiple effects in order
            for effect in effects {
                Box::pin(execute(effect, env)).await?;
            }
            Ok(())
        }

        Effect::LoadAndPrintChecklist => {
            // Load or create checklist from aethel
            let (_uuid, checklist_data) = env.aethel_storage.get_or_create_checklist().await?;

            // Convert to ChecklistState for backward compatibility
            let checklist = ChecklistState {
                items: checklist_data
                    .items
                    .into_iter()
                    .enumerate()
                    .map(|(i, (text, on))| ChecklistItem {
                        id: format!("item-{i}"),
                        text,
                        on,
                    })
                    .collect(),
            };

            // Print as JSON to stdout
            let json = serde_json::to_string(&checklist)?;
            println!("{json}");

            Ok(())
        }

        Effect::ToggleChecklistItem { id } => {
            // Load checklist from aethel
            let (uuid, mut checklist_data) = env.aethel_storage.get_or_create_checklist().await?;

            // Parse the ID to get the index
            let index = if let Some(num_str) = id.strip_prefix("item-") {
                num_str.parse::<usize>().ok()
            } else {
                None
            };

            // Toggle the item
            if let Some(idx) = index {
                if let Some((_, on)) = checklist_data.items.get_mut(idx) {
                    *on = !*on;

                    // Save updated state to aethel
                    env.aethel_storage
                        .update_checklist(&uuid, &checklist_data)
                        .await?;
                } else {
                    eprintln!("Error: Checklist item with id '{id}' not found");
                }
            } else {
                eprintln!("Error: Invalid checklist item id '{id}'");
            }

            // Convert to ChecklistState and print
            let checklist = ChecklistState {
                items: checklist_data
                    .items
                    .into_iter()
                    .enumerate()
                    .map(|(i, (text, on))| ChecklistItem {
                        id: format!("item-{i}"),
                        text,
                        on,
                    })
                    .collect(),
            };

            let json = serde_json::to_string(&checklist)?;
            println!("{json}");

            Ok(())
        }

        Effect::ValidateChecklistAndStart { goal, time } => {
            // Load checklist from aethel
            let (checklist_uuid, checklist_data) =
                env.aethel_storage.get_or_create_checklist().await?;

            // Check if all items are completed
            let all_completed = checklist_data.items.iter().all(|(_, on)| *on);

            if !all_completed {
                let mut error_msg = "All checklist items must be completed before starting a session.\nUncompleted items:".to_string();
                for (text, on) in &checklist_data.items {
                    if !on {
                        error_msg.push_str(&format!("\n  - {text}"));
                    }
                }
                return Err(anyhow::anyhow!(error_msg));
            }

            // All items checked, proceed with creating session
            let session = Session {
                goal,
                start_time: env.clock.now(),
                time_expected: time,
                reflection_file_path: None,
            };

            // Save session to aethel
            let state = crate::state::State::SessionActive {
                session: session.clone(),
                session_uuid: None,
            };
            let _uuid = state.save(env).await?;

            // Print the session data as JSON for the Swift app
            let json = serde_json::to_string(&session)?;
            println!("{json}");

            // Reset checklist for next session - reset all items to unchecked
            let mut reset_checklist_data = checklist_data;
            for (_, completed) in &mut reset_checklist_data.items {
                *completed = false;
            }
            env.aethel_storage
                .update_checklist(&checklist_uuid, &reset_checklist_data)
                .await?;

            Ok(())
        }

        Effect::PrintSession { state } => {
            match state {
                crate::state::State::SessionActive { session, .. } => {
                    // Print session as JSON for Swift app
                    let json = serde_json::to_string(&session)?;
                    println!("{json}");
                }
                crate::state::State::Idle => {
                    // Print empty JSON object to indicate no session
                    println!("{{}}");
                }
            }
            Ok(())
        }
    }
}
