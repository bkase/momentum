use super::mock_helpers::create_test_environment;
use crate::action::Action;
use crate::effects::{execute, Effect};
use crate::models::ChecklistData;
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

    // The test environment starts with no checklist

    let effect = Effect::LoadAndPrintChecklist;
    let result = execute(effect, &env).await;

    assert!(result.is_ok());

    // Check that checklist was created in aethel
    let (_uuid, checklist_data) = env.aethel_storage.get_or_create_checklist().await.unwrap();

    // Verify default content from mock
    assert_eq!(checklist_data.items.len(), 2); // Mock returns 2 test items
    assert!(checklist_data.items.iter().all(|(_, on)| !on));
    assert_eq!(checklist_data.items[0].0, "Test item 1");
    assert_eq!(checklist_data.items[1].0, "Test item 2");
}

#[tokio::test]
async fn test_load_checklist_reads_existing() {
    let env = create_test_environment();

    // Create existing checklist with some items checked
    let checklist_data = ChecklistData {
        items: vec![
            ("Custom Item 1".to_string(), true),
            ("Custom Item 2".to_string(), false),
        ],
    };

    // Update the checklist in aethel mock storage
    let (uuid, _) = env.aethel_storage.get_or_create_checklist().await.unwrap();
    env.aethel_storage
        .update_checklist(&uuid, &checklist_data)
        .await
        .unwrap();

    let effect = Effect::LoadAndPrintChecklist;
    let result = execute(effect, &env).await;

    assert!(result.is_ok());

    // Verify it reads the updated content
    let (_, saved_checklist) = env.aethel_storage.get_or_create_checklist().await.unwrap();

    assert_eq!(saved_checklist.items.len(), 2);
    assert_eq!(saved_checklist.items[0].0, "Custom Item 1");
    assert!(saved_checklist.items[0].1);
    assert!(!saved_checklist.items[1].1);
}

#[tokio::test]
async fn test_toggle_checklist_item() {
    let env = create_test_environment();

    // Create checklist with all items unchecked
    let checklist_data = ChecklistData {
        items: vec![
            ("Item 0".to_string(), false),
            ("Item 1".to_string(), false),
            ("Item 2".to_string(), false),
        ],
    };

    // Set up checklist in aethel storage
    let (uuid, _) = env.aethel_storage.get_or_create_checklist().await.unwrap();
    env.aethel_storage
        .update_checklist(&uuid, &checklist_data)
        .await
        .unwrap();

    // Toggle item 1 (using item-1 format as per the effect implementation)
    let effect = Effect::ToggleChecklistItem {
        id: "item-1".to_string(),
    };
    let result = execute(effect, &env).await;

    assert!(result.is_ok());

    // Verify item was toggled
    let (_, saved_checklist) = env.aethel_storage.get_or_create_checklist().await.unwrap();

    assert!(!saved_checklist.items[0].1);
    assert!(saved_checklist.items[1].1); // This one should be toggled
    assert!(!saved_checklist.items[2].1);
}

#[tokio::test]
async fn test_toggle_nonexistent_item() {
    let env = create_test_environment();

    // Create checklist
    let checklist_data = ChecklistData {
        items: vec![("Item 0".to_string(), false)],
    };

    // Set up checklist in aethel storage
    let (uuid, _) = env.aethel_storage.get_or_create_checklist().await.unwrap();
    env.aethel_storage
        .update_checklist(&uuid, &checklist_data)
        .await
        .unwrap();

    // Try to toggle non-existent item
    let effect = Effect::ToggleChecklistItem {
        id: "item-999".to_string(),
    };
    let result = execute(effect, &env).await;

    // Should not error, but item shouldn't change
    assert!(result.is_ok());

    let (_, saved_checklist) = env.aethel_storage.get_or_create_checklist().await.unwrap();

    // All items should remain unchanged
    assert!(!saved_checklist.items[0].1);
}

#[tokio::test]
async fn test_toggle_already_checked_item() {
    let env = create_test_environment();

    // Create checklist with one item already checked
    let checklist_data = ChecklistData {
        items: vec![("Item 0".to_string(), true)],
    };

    // Set up checklist in aethel storage
    let (uuid, _) = env.aethel_storage.get_or_create_checklist().await.unwrap();
    env.aethel_storage
        .update_checklist(&uuid, &checklist_data)
        .await
        .unwrap();

    // Toggle the already checked item
    let effect = Effect::ToggleChecklistItem {
        id: "item-0".to_string(),
    };
    let result = execute(effect, &env).await;

    assert!(result.is_ok());

    // Verify item was unchecked
    let (_, saved_checklist) = env.aethel_storage.get_or_create_checklist().await.unwrap();

    assert!(!saved_checklist.items[0].1); // Should be unchecked now
}

#[tokio::test]
async fn test_start_with_incomplete_checklist() {
    let env = create_test_environment();

    // Create checklist with some items unchecked
    let checklist_data = ChecklistData {
        items: vec![
            ("Item 0".to_string(), true),
            ("Item 1".to_string(), false), // Not checked
            ("Item 2".to_string(), true),
        ],
    };

    // Set up checklist in aethel storage
    let (uuid, _) = env.aethel_storage.get_or_create_checklist().await.unwrap();
    env.aethel_storage
        .update_checklist(&uuid, &checklist_data)
        .await
        .unwrap();

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

    // Session should not be created in aethel
    let active_session = env.aethel_storage.find_active_session().await.unwrap();
    assert!(active_session.is_none());
}

#[tokio::test]
async fn test_start_with_complete_checklist() {
    let env = create_test_environment();

    // Create checklist with all items checked
    let checklist_data = ChecklistData {
        items: (0..3).map(|i| (format!("Item {i}"), true)).collect(),
    };

    // Set up checklist in aethel storage
    let (uuid, _) = env.aethel_storage.get_or_create_checklist().await.unwrap();
    env.aethel_storage
        .update_checklist(&uuid, &checklist_data)
        .await
        .unwrap();

    // Try to start session
    let effect = Effect::ValidateChecklistAndStart {
        goal: "Test Goal".to_string(),
        time: 30,
    };
    let result = execute(effect, &env).await;

    assert!(result.is_ok());

    // Session should be created in aethel
    let active_session = env.aethel_storage.find_active_session().await.unwrap();
    assert!(active_session.is_some());
}
