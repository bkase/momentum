use crate::models::AnalysisResult;
use anyhow::Result;
use async_trait::async_trait;
use std::path::{Path, PathBuf};

/// Environment holds all dependencies with side effects
pub struct Environment {
    pub file_system: Box<dyn FileSystem>,
    pub api_client: Box<dyn ApiClient>,
    pub clock: Box<dyn Clock>,
}

impl Environment {
    /// Create a new environment with real implementations
    pub fn new() -> Result<Self> {
        Ok(Environment {
            file_system: Box::new(RealFileSystem),
            api_client: Box::new(RealApiClient::new()),
            clock: Box::new(RealClock),
        })
    }

    /// Get the path to session.json
    pub fn get_session_path(&self) -> Result<PathBuf> {
        let mut path =
            dirs::data_dir().ok_or_else(|| anyhow::anyhow!("Could not find data directory"))?;
        path.push("Momentum");

        // Ensure directory exists
        std::fs::create_dir_all(&path)?;

        path.push("session.json");
        Ok(path)
    }

    /// Get the directory for reflection files
    pub fn get_reflections_dir(&self) -> Result<PathBuf> {
        let mut path =
            dirs::data_dir().ok_or_else(|| anyhow::anyhow!("Could not find data directory"))?;
        path.push("Momentum");
        path.push("reflections");

        // Ensure directory exists
        std::fs::create_dir_all(&path)?;

        Ok(path)
    }
}

/// File system operations trait
pub trait FileSystem: Send + Sync {
    fn read(&self, path: &Path) -> Result<String>;
    fn write(&self, path: &Path, content: &str) -> Result<()>;
    fn delete(&self, path: &Path) -> Result<()>;
}

/// API client trait for Claude API
#[async_trait]
pub trait ApiClient: Send + Sync {
    async fn analyze(&self, content: &str) -> Result<AnalysisResult>;
}

/// Clock trait for getting current time
pub trait Clock: Send + Sync {
    fn now(&self) -> u64;
}

// Real implementations

struct RealFileSystem;

impl FileSystem for RealFileSystem {
    fn read(&self, path: &Path) -> Result<String> {
        Ok(std::fs::read_to_string(path)?)
    }

    fn write(&self, path: &Path, content: &str) -> Result<()> {
        Ok(std::fs::write(path, content)?)
    }

    fn delete(&self, path: &Path) -> Result<()> {
        Ok(std::fs::remove_file(path)?)
    }
}

struct RealApiClient;

impl RealApiClient {
    fn new() -> Self {
        Self
    }
}

#[async_trait]
impl ApiClient for RealApiClient {
    async fn analyze(&self, content: &str) -> Result<AnalysisResult> {
        let prompt = format!(
            r#"You are an AI productivity coach analyzing a focus session reflection. 
                
Please analyze the following reflection and provide:
1. A brief summary of what happened during the session
2. A specific, actionable suggestion for improvement
3. Your reasoning for this suggestion

Reflection:
{content}

Respond in JSON format with these exact fields:
{{
    "summary": "brief summary of the session",
    "suggestion": "specific actionable suggestion",
    "reasoning": "why this suggestion would help"
}}"#
        );

        // Load shell environment to access mise-managed claude
        // Now that sandboxing is disabled, we can use the simpler approach
        // Escape single quotes by replacing them with '\''
        let escaped_prompt = prompt.replace("'", "'\\''");
        // Use mise hook-env instead of activate to get just the env vars
        let command = format!(
            "source ~/.zshrc && eval \"$(mise hook-env -s zsh)\" && claude -p '{escaped_prompt}'"
        );

        // Set a timeout of 90 seconds for the claude CLI
        let output = tokio::time::timeout(
            std::time::Duration::from_secs(90),
            tokio::process::Command::new("/bin/zsh")
                .arg("-c")
                .arg(&command)
                .output(),
        )
        .await
        .map_err(|_| anyhow::anyhow!("claude CLI timed out after 90 seconds"))?
        .map_err(|e| anyhow::anyhow!("Failed to execute zsh: {}", e))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            if stderr.contains("command not found") {
                return Err(anyhow::anyhow!(
                    "claude CLI tool not found. Please ensure it is installed via mise and available in your shell environment."
                ));
            }
            return Err(anyhow::anyhow!("claude command failed: {}", stderr));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);

        // The claude CLI output might contain extra text before/after the JSON
        // Try to extract JSON object from the output
        let json_start = stdout.find('{');
        let json_end = stdout.rfind('}');

        match (json_start, json_end) {
            (Some(start), Some(end)) if start <= end => {
                let json_str = &stdout[start..=end];
                let analysis: AnalysisResult = serde_json::from_str(json_str)
                    .map_err(|e| anyhow::anyhow!("Failed to parse claude output as JSON: {}", e))?;
                Ok(analysis)
            }
            _ => Err(anyhow::anyhow!(
                "Could not find valid JSON in claude output. Output was: {}",
                stdout
            )),
        }
    }
}

struct RealClock;

impl Clock for RealClock {
    fn now(&self) -> u64 {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("System time is set before the UNIX epoch, which is not supported.")
            .as_secs()
    }
}
