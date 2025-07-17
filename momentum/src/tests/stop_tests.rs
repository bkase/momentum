use crate::{action::Action, environment::*, models::Session, state::State, update::update};
use super::mock_helpers::*;

#[test]
fn test_stop_active_session() {
    let env = Environment {
        file_system: Box::new(MockFileSystem::new()),
        api_client: Box::new(MockApiClient),
        clock: Box::new(MockClock { time: 1500 }),
    };

    let state = State::SessionActive {
        session: Session {
            goal: "Test goal".to_string(),
            start_time: 1000,
            time_expected: 30,
            reflection_file_path: None,
        },
    };

    let action = Action::Stop;

    let (new_state, effect) = update(state, action, &env);

    // Should transition to Idle
    assert_eq!(new_state, State::Idle);

    // Should create composite effect with CreateReflection and ClearState
    match effect {
        Some(crate::effects::Effect::Composite(effects)) => {
            assert_eq!(effects.len(), 2);
            assert!(matches!(
                effects[0],
                crate::effects::Effect::CreateReflection { .. }
            ));
            assert!(matches!(effects[1], crate::effects::Effect::ClearState));
        }
        _ => panic!("Expected Composite effect with CreateReflection and ClearState"),
    }
}

#[test]
fn test_cannot_stop_when_idle() {
    let env = Environment {
        file_system: Box::new(MockFileSystem::new()),
        api_client: Box::new(MockApiClient),
        clock: Box::new(MockClock { time: 1000 }),
    };

    let state = State::Idle;
    let action = Action::Stop;

    let (new_state, effect) = update(state, action, &env);

    // State should remain idle
    assert_eq!(new_state, State::Idle);

    // Should produce an error effect
    assert!(matches!(
        effect,
        Some(crate::effects::Effect::PrintError { .. })
    ));
}