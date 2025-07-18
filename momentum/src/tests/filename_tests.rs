use crate::effects::sanitize_goal_for_filename;

#[test]
fn test_sanitize_goal_basic() {
    assert_eq!(sanitize_goal_for_filename("Test Goal"), "test-goal");
}

#[test]
fn test_sanitize_goal_multiple_spaces() {
    assert_eq!(
        sanitize_goal_for_filename("Implement New Feature"),
        "implement-new-feature"
    );
}

#[test]
fn test_sanitize_goal_already_lowercase() {
    assert_eq!(
        sanitize_goal_for_filename("already lowercase"),
        "already-lowercase"
    );
}

#[test]
fn test_sanitize_goal_no_spaces() {
    assert_eq!(sanitize_goal_for_filename("NoSpaces"), "nospaces");
}

#[test]
fn test_sanitize_goal_empty() {
    assert_eq!(sanitize_goal_for_filename(""), "");
}

#[test]
fn test_sanitize_goal_only_spaces() {
    assert_eq!(sanitize_goal_for_filename("   "), "---");
}

#[test]
fn test_sanitize_goal_with_numbers() {
    assert_eq!(sanitize_goal_for_filename("Fix Bug 123"), "fix-bug-123");
}

#[test]
fn test_sanitize_goal_preserves_valid_chars() {
    // The sanitization should preserve valid filename characters
    assert_eq!(sanitize_goal_for_filename("test_goal-123"), "test_goal-123");
}
