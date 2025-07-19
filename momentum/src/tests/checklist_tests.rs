use super::mock_helpers::create_test_environment;
use crate::action::Action;
use crate::effects::{execute, Effect};
use crate::models::{ChecklistItem, ChecklistState};
use crate::state::State;
use crate::update::update;

#[test]
fn test_checklist_list_action() {
    let state = State::Idle;
    let action = Action::CheckList;
    let env = create_test_environment();

    let (new_state, effect) = update(state, action, &env);

    // State should remain unchanged
    assert_eq!(new_state, State::Idle);

    // Should produce LoadAndPrintChecklist effect
    assert!(matches!(effect, Some(Effect::LoadAndPrintChecklist)));
}

#[test]
fn test_checklist_toggle_action() {
    let state = State::Idle;
    let action = Action::CheckToggle {
        id: "0".to_string(),
    };
    let env = create_test_environment();

    let (new_state, effect) = update(state, action, &env);

    // State should remain unchanged
    assert_eq!(new_state, State::Idle);

    // Should produce ToggleChecklistItem effect
    assert!(matches!(effect, Some(Effect::ToggleChecklistItem { id }) if id == "0"));
}

#[tokio::test]
async fn test_load_checklist_creates_default() {
    let env = create_test_environment();

    // The test environment starts with no files

    let effect = Effect::LoadAndPrintChecklist;
    let result = execute(effect, &env).await;

    assert!(result.is_ok());

    // Check that checklist was created
    let checklist_path = env.get_checklist_path().unwrap();
    assert!(env.file_system.read(&checklist_path).is_ok());

    // Verify default content
    let content = env.file_system.read(&checklist_path).unwrap();
    let checklist: ChecklistState = serde_json::from_str(&content).unwrap();

    assert_eq!(checklist.items.len(), 9);
    assert!(checklist.items.iter().all(|item| !item.on));
    assert_eq!(
        checklist.items[0].text,
        "Rested, if not take 10min to lie down"
    );
    assert_eq!(
        checklist.items[1].text,
        "Not hungry, if so, get a snack first"
    );
}

#[tokio::test]
async fn test_load_checklist_reads_existing() {
    let env = create_test_environment();

    // Create existing checklist with some items checked
    let existing_checklist = ChecklistState {
        items: vec![
            ChecklistItem {
                id: "0".to_string(),
                text: "Test Item 1".to_string(),
                on: true,
            },
            ChecklistItem {
                id: "1".to_string(),
                text: "Test Item 2".to_string(),
                on: false,
            },
        ],
    };

    let checklist_path = env.get_checklist_path().unwrap();
    let content = serde_json::to_string(&existing_checklist).unwrap();
    env.file_system.write(&checklist_path, &content).unwrap();

    let effect = Effect::LoadAndPrintChecklist;
    let result = execute(effect, &env).await;

    assert!(result.is_ok());

    // Verify it reads the existing content
    let saved_content = env.file_system.read(&checklist_path).unwrap();
    let saved_checklist: ChecklistState = serde_json::from_str(&saved_content).unwrap();

    assert_eq!(saved_checklist.items.len(), 2);
    assert_eq!(saved_checklist.items[0].text, "Test Item 1");
    assert!(saved_checklist.items[0].on);
    assert!(!saved_checklist.items[1].on);
}

#[tokio::test]
async fn test_toggle_checklist_item() {
    let env = create_test_environment();

    // Create checklist with all items unchecked
    let checklist = ChecklistState {
        items: vec![
            ChecklistItem {
                id: "0".to_string(),
                text: "Item 0".to_string(),
                on: false,
            },
            ChecklistItem {
                id: "1".to_string(),
                text: "Item 1".to_string(),
                on: false,
            },
            ChecklistItem {
                id: "2".to_string(),
                text: "Item 2".to_string(),
                on: false,
            },
        ],
    };

    let checklist_path = env.get_checklist_path().unwrap();
    let content = serde_json::to_string(&checklist).unwrap();
    env.file_system.write(&checklist_path, &content).unwrap();

    // Toggle item 1
    let effect = Effect::ToggleChecklistItem {
        id: "1".to_string(),
    };
    let result = execute(effect, &env).await;

    assert!(result.is_ok());

    // Verify item was toggled
    let saved_content = env.file_system.read(&checklist_path).unwrap();
    let saved_checklist: ChecklistState = serde_json::from_str(&saved_content).unwrap();

    assert!(!saved_checklist.items[0].on);
    assert!(saved_checklist.items[1].on); // This one should be toggled
    assert!(!saved_checklist.items[2].on);
}

#[tokio::test]
async fn test_toggle_nonexistent_item() {
    let env = create_test_environment();

    // Create checklist
    let checklist = ChecklistState {
        items: vec![ChecklistItem {
            id: "0".to_string(),
            text: "Item 0".to_string(),
            on: false,
        }],
    };

    let checklist_path = env.get_checklist_path().unwrap();
    let content = serde_json::to_string(&checklist).unwrap();
    env.file_system.write(&checklist_path, &content).unwrap();

    // Try to toggle non-existent item
    let effect = Effect::ToggleChecklistItem {
        id: "999".to_string(),
    };
    let result = execute(effect, &env).await;

    // Should not error, but item shouldn't change
    assert!(result.is_ok());

    let saved_content = env.file_system.read(&checklist_path).unwrap();
    let saved_checklist: ChecklistState = serde_json::from_str(&saved_content).unwrap();

    // All items should remain unchanged
    assert!(!saved_checklist.items[0].on);
}

#[tokio::test]
async fn test_toggle_already_checked_item() {
    let env = create_test_environment();

    // Create checklist with one item already checked
    let checklist = ChecklistState {
        items: vec![ChecklistItem {
            id: "0".to_string(),
            text: "Item 0".to_string(),
            on: true,
        }],
    };

    let checklist_path = env.get_checklist_path().unwrap();
    let content = serde_json::to_string(&checklist).unwrap();
    env.file_system.write(&checklist_path, &content).unwrap();

    // Toggle the already checked item
    let effect = Effect::ToggleChecklistItem {
        id: "0".to_string(),
    };
    let result = execute(effect, &env).await;

    assert!(result.is_ok());

    // Verify item was unchecked
    let saved_content = env.file_system.read(&checklist_path).unwrap();
    let saved_checklist: ChecklistState = serde_json::from_str(&saved_content).unwrap();

    assert!(!saved_checklist.items[0].on); // Should be unchecked now
}

#[tokio::test]
async fn test_start_with_incomplete_checklist() {
    let env = create_test_environment();

    // Create checklist with some items unchecked
    let checklist = ChecklistState {
        items: vec![
            ChecklistItem {
                id: "0".to_string(),
                text: "Item 0".to_string(),
                on: true,
            },
            ChecklistItem {
                id: "1".to_string(),
                text: "Item 1".to_string(),
                on: false,
            }, // Not checked
            ChecklistItem {
                id: "2".to_string(),
                text: "Item 2".to_string(),
                on: true,
            },
        ],
    };

    let checklist_path = env.get_checklist_path().unwrap();
    let content = serde_json::to_string(&checklist).unwrap();
    env.file_system.write(&checklist_path, &content).unwrap();

    // Try to start session
    let effect = Effect::ValidateChecklistAndStart {
        goal: "Test Goal".to_string(),
        time: 30,
    };
    let result = execute(effect, &env).await;

    // Should fail with error about incomplete checklist
    assert!(result.is_err());
    let error_msg = result.unwrap_err().to_string();
    assert!(error_msg.contains("All checklist items must be completed"));

    // Session should not be created
    let session_path = env.get_session_path().unwrap();
    assert!(env.file_system.read(&session_path).is_err());
}

#[tokio::test]
async fn test_start_with_complete_checklist() {
    let env = create_test_environment();

    // Create checklist with all items checked (9 items matching the template)
    let checklist = ChecklistState {
        items: (0..9)
            .map(|i| ChecklistItem {
                id: i.to_string(),
                text: format!("Item {}", i),
                on: true,
            })
            .collect(),
    };

    let checklist_path = env.get_checklist_path().unwrap();
    let content = serde_json::to_string(&checklist).unwrap();
    env.file_system.write(&checklist_path, &content).unwrap();

    // Try to start session
    let effect = Effect::ValidateChecklistAndStart {
        goal: "Test Goal".to_string(),
        time: 30,
    };
    let result = execute(effect, &env).await;

    assert!(result.is_ok());

    // Session should be created
    let session_path = env.get_session_path().unwrap();
    assert!(env.file_system.read(&session_path).is_ok());
}
