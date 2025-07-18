mod action;
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
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // Initialize environment with real dependencies
    let env = environment::Environment::new()?;

    // Get current state
    let state = state::State::load(&env)?;

    // Convert CLI command to action
    let action = match cli.command {
        Commands::Start { goal, time } => action::Action::Start { goal, time },
        Commands::Stop => action::Action::Stop,
        Commands::Analyze { file } => action::Action::Analyze { path: file },
    };

    // Run update function
    let (_new_state, effect) = update::update(state, action, &env);

    // Execute side effects
    if let Some(effect) = effect {
        effects::execute(effect, &env).await?;
    }

    Ok(())
}
