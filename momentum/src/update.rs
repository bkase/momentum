use crate::action::Action;
use crate::effects::Effect;
use crate::environment::Environment;
use crate::state::State;

/// Pure update function that takes state and action, returns new state and optional effect
pub fn update(state: State, action: Action, _env: &Environment) -> (State, Option<Effect>) {
    match (state, action) {
        // Start a new session when idle
        (State::Idle, Action::Start { goal, time }) => {
            // Validate checklist before starting
            let effect = Effect::ValidateChecklistAndStart { goal, time };
            (State::Idle, Some(effect))
        }

        // Cannot start a new session when one is active
        (state @ State::SessionActive { .. }, Action::Start { .. }) => {
            let effect = Effect::PrintError {
                message: "A session is already active. Stop it first before starting a new one."
                    .to_string(),
            };
            (state, Some(effect))
        }

        // Stop an active session
        (State::SessionActive { session }, Action::Stop) => {
            let effect = Effect::Composite(vec![
                Effect::CreateReflection { session },
                Effect::ClearState,
            ]);
            (State::Idle, Some(effect))
        }

        // Cannot stop when no session is active
        (state @ State::Idle, Action::Stop) => {
            let effect = Effect::PrintError {
                message: "No active session to stop.".to_string(),
            };
            (state, Some(effect))
        }

        // Analyze a reflection file (works in any state)
        (state, Action::Analyze { path }) => {
            let effect = Effect::AnalyzeReflection { path };
            (state, Some(effect))
        }

        // List checklist items (works in any state)
        (state, Action::CheckList) => {
            let effect = Effect::LoadAndPrintChecklist;
            (state, Some(effect))
        }

        // Toggle checklist item (works in any state)
        (state, Action::CheckToggle { id }) => {
            let effect = Effect::ToggleChecklistItem { id };
            (state, Some(effect))
        }
    }
}
