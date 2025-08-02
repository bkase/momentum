use super::mock_helpers::*;
use crate::{action::Action, models::Session, state::State, update::update};

#[test]
fn test_analyze_action() {
    let mut env = create_test_environment();
    // Override the clock time for this specific test
    env.clock = Box::new(MockClock { time: 1000 });

    let state = State::Idle;
    let path = std::path::PathBuf::from("/test/reflection.md");
    let action = Action::Analyze { path: path.clone() };

    let (new_state, effect) = update(state, action, &env);

    // State should remain idle
    assert_eq!(new_state, State::Idle);

    // Should produce analyze effect
    match effect {
        Some(crate::effects::Effect::AnalyzeReflection { path: effect_path }) => {
            assert_eq!(effect_path, path);
        }
        _ => panic!("Expected AnalyzeReflection effect"),
    }
}

#[tokio::test]
async fn test_state_load_no_session() {
    let mut env = create_test_environment();
    // Override the clock time for this specific test
    env.clock = Box::new(MockClock { time: 1000 });

    // When no session exists in aethel, should return Idle
    let state = State::load(&env).await.unwrap();
    assert!(matches!(state, State::Idle));
}

#[tokio::test]
async fn test_state_load_with_session() {
    let mut env = create_test_environment();
    // Override the clock time for this specific test
    env.clock = Box::new(MockClock { time: 1000 });

    let session = Session {
        goal: "test goal".to_string(),
        start_time: 1000,
        time_expected: 30,
        reflection_file_path: None,
    };

    // Save session to aethel mock storage
    env.aethel_storage.save_session(&session).await.unwrap();

    // Load should return SessionActive
    let state = State::load(&env).await.unwrap();
    match state {
        State::SessionActive {
            session: loaded, ..
        } => {
            assert_eq!(loaded.goal, session.goal);
            assert_eq!(loaded.start_time, session.start_time);
        }
        _ => panic!("Expected SessionActive state"),
    }
}

// Test for effect execution
#[tokio::test]
async fn test_effect_clear_state() {
    let mut env = create_test_environment();
    // Override the clock time for this specific test
    env.clock = Box::new(MockClock { time: 1000 });

    let session = Session {
        goal: "test goal".to_string(),
        start_time: 1000,
        time_expected: 30,
        reflection_file_path: None,
    };

    // First, save a session
    let _uuid = env.aethel_storage.save_session(&session).await.unwrap();

    // Execute clear effect
    let effect = crate::effects::Effect::ClearState;
    crate::effects::execute(effect, &env).await.unwrap();

    // Verify session was cleared
    let active_session = env.aethel_storage.find_active_session().await.unwrap();
    assert!(active_session.is_none());
}

#[tokio::test]
async fn test_effect_composite() {
    let env = create_test_environment();

    let effect = crate::effects::Effect::Composite(vec![
        crate::effects::Effect::PrintError {
            message: "Error 1".to_string(),
        },
        crate::effects::Effect::PrintError {
            message: "Error 2".to_string(),
        },
    ]);

    // Should execute without errors
    crate::effects::execute(effect, &env).await.unwrap();
}
