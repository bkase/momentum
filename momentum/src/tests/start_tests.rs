use crate::{action::Action, environment::*, state::State, update::update};
use super::mock_helpers::*;

#[test]
fn test_start_session_when_idle() {
    let env = Environment {
        file_system: Box::new(MockFileSystem::new()),
        api_client: Box::new(MockApiClient),
        clock: Box::new(MockClock { time: 1000 }),
    };

    let state = State::Idle;
    let action = Action::Start {
        goal: "Test goal".to_string(),
        time: 30,
    };

    let (new_state, effect) = update(state, action, &env);

    match new_state {
        State::SessionActive { session } => {
            assert_eq!(session.goal, "Test goal");
            assert_eq!(session.start_time, 1000);
            assert_eq!(session.time_expected, 30);
            assert_eq!(session.reflection_file_path, None);
        }
        _ => panic!("Expected SessionActive state"),
    }

    assert!(matches!(
        effect,
        Some(crate::effects::Effect::CreateSession { .. })
    ));
}

#[test]
fn test_cannot_start_session_when_active() {
    let env = Environment {
        file_system: Box::new(MockFileSystem::new()),
        api_client: Box::new(MockApiClient),
        clock: Box::new(MockClock { time: 1000 }),
    };

    let state = State::SessionActive {
        session: crate::models::Session {
            goal: "Existing goal".to_string(),
            start_time: 900,
            time_expected: 25,
            reflection_file_path: None,
        },
    };

    let action = Action::Start {
        goal: "New goal".to_string(),
        time: 30,
    };

    let (new_state, effect) = update(state.clone(), action, &env);

    // State should remain unchanged
    assert_eq!(new_state, state);

    // Should produce an error effect
    assert!(matches!(
        effect,
        Some(crate::effects::Effect::PrintError { .. })
    ));
}