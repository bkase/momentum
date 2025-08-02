mod action;
mod aethel_storage;
mod effects;
mod environment;
mod index;
mod models;
mod state;
mod tests;
mod update;
mod vault_init;

use anyhow::Result;
use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "momentum")]
#[command(about = "Focus session tracking tool")]
struct Cli {
    /// Path to the aethel vault (overrides MOMENTUM_VAULT_PATH env var)
    #[arg(long, global = true)]
    vault: Option<PathBuf>,

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
    let env = if let Some(vault_path) = cli.vault {
        environment::Environment::with_vault_path(vault_path)?
    } else {
        environment::Environment::new()?
    };

    // Initialize vault if needed
    vault_init::initialize_vault(&env).await?;

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
