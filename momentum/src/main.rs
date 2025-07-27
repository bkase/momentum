mod action;
mod aethel_storage;
mod effects;
mod environment;
mod models;
mod state;
mod tests;
mod update;

use anyhow::Result;
use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "momentum")]
#[command(about = "Focus session tracking tool")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Start a new focus session
    Start {
        /// Goal for the focus session
        #[arg(long)]
        goal: String,

        /// Expected time in minutes
        #[arg(long)]
        time: u64,
    },

    /// Stop the current focus session
    Stop,

    /// Analyze a reflection file
    Analyze {
        /// Path to the markdown reflection file
        #[arg(long)]
        file: PathBuf,
    },

    /// Manage checklist items
    Check {
        #[command(subcommand)]
        subcommand: CheckCommands,
    },

    /// Get current session (for Swift app)
    GetSession,
}

#[derive(Subcommand)]
enum CheckCommands {
    /// List all checklist items with their current state
    List,

    /// Toggle a checklist item by ID
    Toggle {
        /// ID of the checklist item to toggle
        id: String,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // Initialize environment with real dependencies
    let env = environment::Environment::new()?;
    
    // Initialize vault if needed
    initialize_vault(&env).await?;

    // Get current state
    let state = state::State::load(&env).await?;

    // Convert CLI command to action
    let action = match cli.command {
        Commands::Start { goal, time } => action::Action::Start { goal, time },
        Commands::Stop => action::Action::Stop,
        Commands::Analyze { file } => action::Action::Analyze { path: file },
        Commands::Check { subcommand } => match subcommand {
            CheckCommands::List => action::Action::CheckList,
            CheckCommands::Toggle { id } => action::Action::CheckToggle { id },
        },
        Commands::GetSession => action::Action::GetSession,
    };

    // Run update function
    let (_new_state, effect) = update::update(state, action, &env);

    // Execute side effects
    if let Some(effect) = effect {
        effects::execute(effect, &env).await?;
    }

    Ok(())
}

async fn initialize_vault(env: &environment::Environment) -> Result<()> {
    let vault_root = env.aethel_storage.vault_root();
    
    // Create vault directories if they don't exist
    let docs_dir = vault_root.join("docs");
    let packs_dir = vault_root.join("packs");
    
    std::fs::create_dir_all(&docs_dir)?;
    std::fs::create_dir_all(&packs_dir)?;
    
    // Check if Momentum pack is installed and up to date
    let pack_name_with_version = format!("momentum@{}", MOMENTUM_PACK_VERSION);
    let momentum_pack_dir = packs_dir.join(&pack_name_with_version);
    
    if !momentum_pack_dir.exists() {
        // Remove old versions if they exist
        remove_old_pack_versions(&packs_dir, "momentum")?;
        
        // Install the current version
        install_momentum_pack(&packs_dir)?;
    }
    
    Ok(())
}

const MOMENTUM_PACK_VERSION: &str = "0.2.0"; // Bump version when pack changes

fn remove_old_pack_versions(packs_dir: &std::path::Path, pack_name: &str) -> Result<()> {
    // Look for any directories matching momentum@*
    for entry in std::fs::read_dir(packs_dir)? {
        let entry = entry?;
        let file_name = entry.file_name();
        let name_str = file_name.to_string_lossy();
        
        if name_str.starts_with(&format!("{}@", pack_name)) {
            let path = entry.path();
            if path.is_dir() {
                println!("Removing old pack version: {}", name_str);
                std::fs::remove_dir_all(path)?;
            }
        }
    }
    Ok(())
}

fn install_momentum_pack(packs_dir: &std::path::Path) -> Result<()> {
    let pack_name_with_version = format!("momentum@{}", MOMENTUM_PACK_VERSION);
    let momentum_pack_dir = packs_dir.join(&pack_name_with_version);
    std::fs::create_dir_all(&momentum_pack_dir)?;
    
    // Copy pack files from embedded resources to vault
    let pack_source = std::path::Path::new("momentum/packs/momentum");
    
    // Copy pack.json
    let pack_json_content = include_str!("../packs/momentum/pack.json");
    std::fs::write(momentum_pack_dir.join("pack.json"), pack_json_content)?;
    
    // Create types directory and copy type schemas
    let types_dir = momentum_pack_dir.join("types");
    std::fs::create_dir_all(&types_dir)?;
    
    let session_schema = include_str!("../packs/momentum/types/session.json");
    std::fs::write(types_dir.join("session.json"), session_schema)?;
    
    let reflection_schema = include_str!("../packs/momentum/types/reflection.json");
    std::fs::write(types_dir.join("reflection.json"), reflection_schema)?;
    
    let checklist_schema = include_str!("../packs/momentum/types/checklist.json");
    std::fs::write(types_dir.join("checklist.json"), checklist_schema)?;
    
    // Create templates directory and copy templates
    let templates_dir = momentum_pack_dir.join("templates");
    std::fs::create_dir_all(&templates_dir)?;
    
    let checklist_template = include_str!("../packs/momentum/templates/checklist.md");
    std::fs::write(templates_dir.join("checklist.md"), checklist_template)?;
    
    println!("Momentum pack v{} installed successfully in vault at: {}", 
             MOMENTUM_PACK_VERSION, 
             momentum_pack_dir.display());
    
    Ok(())
}
