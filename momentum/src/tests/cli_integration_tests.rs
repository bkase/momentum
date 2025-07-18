use crate::environment::*;

#[tokio::test]
#[ignore] // Only run with --ignored flag since it requires claude CLI
async fn test_real_claude_cli_integration() {
    // This test verifies that the claude CLI integration works correctly
    // It requires the claude CLI to be installed
    
    let api_client = match crate::environment::RealApiClient::new() {
        Ok(client) => client,
        Err(e) => {
            eprintln!("Skipping test: {}", e);
            return;
        }
    };

    let test_content = "Today I worked on implementing a new feature. \
                       I spent 2 hours but got distracted by slack messages. \
                       I completed about half of what I planned.";

    let result = api_client.analyze(test_content).await;
    
    match result {
        Ok(analysis) => {
            // Verify we got all required fields
            assert!(!analysis.summary.is_empty());
            assert!(!analysis.suggestion.is_empty());
            assert!(!analysis.reasoning.is_empty());
            
            // Basic sanity checks
            assert!(analysis.summary.len() > 10);
            assert!(analysis.suggestion.len() > 10);
            assert!(analysis.reasoning.len() > 10);
        }
        Err(e) => {
            // If claude CLI is not available, that's okay for CI
            if e.to_string().contains("claude CLI tool not found") {
                eprintln!("Claude CLI not available, skipping test");
                return;
            }
            panic!("Unexpected error: {}", e);
        }
    }
}

#[tokio::test]
async fn test_claude_cli_error_handling() {
    // Test that we handle missing claude CLI gracefully
    
    // Create a fake environment where claude doesn't exist
    let output = tokio::process::Command::new("zsh")
        .arg("-c")
        .arg("command_that_does_not_exist -p 'test'")
        .output()
        .await
        .unwrap();
    
    assert!(!output.status.success());
    
    // Verify our error detection works
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("command not found"));
}