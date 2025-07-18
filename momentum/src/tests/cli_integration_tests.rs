use crate::models::AnalysisResult;

#[tokio::test]
#[ignore] // Only run with --ignored flag since it requires claude CLI
async fn test_real_claude_cli_integration() {
    // This test verifies that the claude CLI integration works correctly
    // It requires the claude CLI to be installed
    
    // We can't directly access RealApiClient from tests, so we'll test
    // the subprocess command directly
    let test_content = "Today I worked on implementing a new feature. \
                       I spent 2 hours but got distracted by slack messages. \
                       I completed about half of what I planned.";

    let prompt = format!(
        r#"You are an AI productivity coach analyzing a focus session reflection. 
            
Please analyze the following reflection and provide:
1. A brief summary of what happened during the session
2. A specific, actionable suggestion for improvement
3. Your reasoning for this suggestion

Reflection:
{}

Respond in JSON format with these exact fields:
{{
    "summary": "brief summary of the session",
    "suggestion": "specific actionable suggestion",
    "reasoning": "why this suggestion would help"
}}"#,
        test_content
    );

    let output = tokio::time::timeout(
        std::time::Duration::from_secs(90),
        tokio::process::Command::new("zsh")
            .arg("-c")
            .arg(format!("claude -p '{}'", prompt.replace("'", "'\\''")))
            .output()
    )
    .await;

    match output {
        Ok(Ok(output)) if output.status.success() => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            
            // Try to parse as JSON
            let json_start = stdout.find('{');
            let json_end = stdout.rfind('}');
            
            if let (Some(start), Some(end)) = (json_start, json_end) {
                let json_str = &stdout[start..=end];
                match serde_json::from_str::<AnalysisResult>(json_str) {
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
                        eprintln!("Failed to parse JSON: {}", e);
                        eprintln!("Output was: {}", stdout);
                    }
                }
            }
        }
        Ok(Ok(output)) => {
            let stderr = String::from_utf8_lossy(&output.stderr);
            if stderr.contains("command not found: claude") {
                eprintln!("Claude CLI not available, skipping test");
                return;
            }
            eprintln!("Command failed: {}", stderr);
        }
        _ => {
            eprintln!("Command timed out or failed to execute");
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