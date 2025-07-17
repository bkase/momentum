use crate::{action::Action, environment::*, models::Session, state::State, update::update};
use super::mock_helpers::*;

#[test]
fn test_analyze_action() {
    let env = Environment {
        file_system: Box::new(MockFileSystem::new()),
        api_client: Box::new(MockApiClient),
        clock: Box::new(MockClock { time: 1000 }),
    };

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

#[test]
fn test_state_load_no_session() {
    let env = Environment {
        file_system: Box::new(MockFileSystem::new()),
        api_client: Box::new(MockApiClient),
        clock: Box::new(MockClock { time: 1000 }),
    };

    // When no session file exists, should return Idle
    let state = State::load(&env).unwrap();
    assert!(matches!(state, State::Idle));
}

#[test]
fn test_state_load_with_session() {
    let env = Environment {
        file_system: Box::new(MockFileSystem::new()),
        api_client: Box::new(MockApiClient),
        clock: Box::new(MockClock { time: 1000 }),
    };

    let session = Session {
        goal: "test goal".to_string(),
        start_time: 1000,
        time_expected: 30,
        reflection_file_path: None,
    };

    // Write session to mock file system
    let session_path = env.get_session_path().unwrap();
    let content = serde_json::to_string(&session).unwrap();
    env.file_system.write(&session_path, &content).unwrap();

    // Load should return SessionActive
    let state = State::load(&env).unwrap();
    match state {
        State::SessionActive { session: loaded } => {
            assert_eq!(loaded.goal, session.goal);
            assert_eq!(loaded.start_time, session.start_time);
        }
        _ => panic!("Expected SessionActive state"),
    }
}

// Test for effect execution
#[tokio::test]
async fn test_effect_clear_state() {
    let env = Environment {
        file_system: Box::new(MockFileSystem::new()),
        api_client: Box::new(MockApiClient),
        clock: Box::new(MockClock { time: 1000 }),
    };

    let session = Session {
        goal: "test goal".to_string(),
        start_time: 1000,
        time_expected: 30,
        reflection_file_path: None,
    };

    // First, save a session
    let session_path = env.get_session_path().unwrap();
    let content = serde_json::to_string(&session).unwrap();
    env.file_system.write(&session_path, &content).unwrap();

    // Execute clear effect
    let effect = crate::effects::Effect::ClearState;
    crate::effects::execute(effect, &env).await.unwrap();

    // Verify file was deleted
    let result = env.file_system.read(&session_path);
    assert!(result.is_err());
}

#[tokio::test]
async fn test_effect_composite() {
    let env = Environment {
        file_system: Box::new(MockFileSystem::new()),
        api_client: Box::new(MockApiClient),
        clock: Box::new(MockClock { time: 1000 }),
    };

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