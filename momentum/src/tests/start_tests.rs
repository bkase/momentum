use super::mock_helpers::*;
use crate::{action::Action, environment::*, state::State, update::update};

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

    // State should remain Idle until checklist validation passes
    assert!(matches!(new_state, State::Idle));

    // Should produce ValidateChecklistAndStart effect
    assert!(matches!(
        effect,
        Some(crate::effects::Effect::ValidateChecklistAndStart { goal, time })
            if goal == "Test goal" && time == 30
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
