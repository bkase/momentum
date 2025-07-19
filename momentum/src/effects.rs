use crate::environment::Environment;
use crate::models::{ChecklistItem, ChecklistState, ChecklistTemplate, Session};
use anyhow::Result;
use chrono::Local;
use std::path::PathBuf;

/// Initialize a fresh checklist from the template
fn create_checklist_from_template() -> Result<ChecklistState> {
    let template_json = Environment::get_checklist_template();
    let templates: Vec<ChecklistTemplate> = serde_json::from_str(template_json)?;

    let items: Vec<ChecklistItem> = templates
        .into_iter()
        .map(|t| ChecklistItem {
            id: t.id,
            text: t.text,
            on: false,
        })
        .collect();

    Ok(ChecklistState { items })
}

/// Sanitize a goal string for use in a filename
#[cfg(test)]
pub fn sanitize_goal_for_filename(goal: &str) -> String {
    goal.to_lowercase()
        .chars()
        .map(|c| if c == ' ' { '-' } else { c })
        .collect()
}

#[cfg(not(test))]
fn sanitize_goal_for_filename(goal: &str) -> String {
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
}

/// Execute side effects
pub async fn execute(effect: Effect, env: &Environment) -> Result<()> {
    match effect {
        Effect::CreateReflection { mut session } => {
            // Create timestamp for filename
            let now = Local::now();
            let sanitized_goal = sanitize_goal_for_filename(&session.goal);
            let filename = format!("{}-{}.md", now.format("%Y-%m-%d-%H%M"), sanitized_goal);

            let mut reflection_path = env.get_reflections_dir()?;
            reflection_path.push(&filename);

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

            // Write reflection file
            env.file_system.write(&reflection_path, &content)?;

            // Update session with reflection file path
            session.reflection_file_path = Some(reflection_path.to_string_lossy().to_string());

            // Save updated session
            let session_path = env.get_session_path()?;
            let session_content = serde_json::to_string_pretty(&session)?;
            env.file_system.write(&session_path, &session_content)?;

            // Print the reflection file path to stdout
            println!("{}", reflection_path.display());
            Ok(())
        }

        Effect::AnalyzeReflection { path } => {
            // Read the reflection file
            let content = env.file_system.read(&path)?;

            // Call Claude API for analysis
            let result = env.api_client.analyze(&content).await?;

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
            // Save state to file system
            let state_path = env.get_session_path()?;
            match state {
                crate::state::State::SessionActive { session } => {
                    let content = serde_json::to_string_pretty(&session)?;
                    env.file_system.write(&state_path, &content)?;
                }
                crate::state::State::Idle => {
                    // Should not save idle state
                    return Err(anyhow::anyhow!("Cannot save idle state"));
                }
            }
            Ok(())
        }

        Effect::ClearState => {
            // Delete session file
            let state_path = env.get_session_path()?;
            env.file_system.delete(&state_path)?;
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
            let checklist_path = env.get_checklist_path()?;

            // Load or create checklist
            let checklist = match env.file_system.read(&checklist_path) {
                Ok(content) => serde_json::from_str(&content)?,
                Err(_) => {
                    // Initialize from template
                    let checklist = create_checklist_from_template()?;

                    // Save initial state
                    let json = serde_json::to_string_pretty(&checklist)?;
                    env.file_system.write(&checklist_path, &json)?;

                    checklist
                }
            };

            // Print as JSON to stdout
            let json = serde_json::to_string(&checklist)?;
            println!("{json}");

            Ok(())
        }

        Effect::ToggleChecklistItem { id } => {
            let checklist_path = env.get_checklist_path()?;

            // Load checklist
            let mut checklist: ChecklistState = match env.file_system.read(&checklist_path) {
                Ok(content) => serde_json::from_str(&content)?,
                Err(_) => {
                    // Initialize from template if not exists
                    create_checklist_from_template()?
                }
            };

            // Toggle the item
            let found = checklist.items.iter_mut().find(|item| item.id == id);

            match found {
                Some(item) => {
                    item.on = !item.on;

                    // Save updated state
                    let json = serde_json::to_string_pretty(&checklist)?;
                    env.file_system.write(&checklist_path, &json)?;

                    // Print updated list as JSON
                    let json = serde_json::to_string(&checklist)?;
                    println!("{json}");
                }
                None => {
                    eprintln!("Error: Checklist item with id '{id}' not found");
                    // Still print current state
                    let json = serde_json::to_string(&checklist)?;
                    println!("{json}");
                }
            }

            Ok(())
        }

        Effect::ValidateChecklistAndStart { goal, time } => {
            let checklist_path = env.get_checklist_path()?;

            // Load checklist
            let checklist: ChecklistState = match env.file_system.read(&checklist_path) {
                Ok(content) => serde_json::from_str(&content)?,
                Err(_) => {
                    // No checklist exists, can't start
                    return Err(anyhow::anyhow!(
                        "Checklist not initialized. Run 'momentum check list' first."
                    ));
                }
            };

            // Check if all items are completed
            if !checklist.all_completed() {
                let mut error_msg = "All checklist items must be completed before starting a session.\nUncompleted items:".to_string();
                for item in checklist.items.iter().filter(|i| !i.on) {
                    error_msg.push_str(&format!("\n  - {}", item.text));
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

            // Create session
            let session_path = env.get_session_path()?;
            let json = serde_json::to_string_pretty(&session)?;
            env.file_system.write(&session_path, &json)?;

            println!("{}", session_path.to_string_lossy());

            // Reset checklist for next session
            let new_checklist = create_checklist_from_template()?;
            let json = serde_json::to_string_pretty(&new_checklist)?;
            env.file_system.write(&checklist_path, &json)?;

            Ok(())
        }
    }
}
