use crate::environment;
use anyhow::Result;

const MOMENTUM_PACK_VERSION: &str = "0.2.0"; // Bump version when pack changes

/// Initialize the vault directory structure and install the Momentum pack
pub async fn initialize_vault(env: &environment::Environment) -> Result<()> {
    let vault_root = env.aethel_storage.vault_root();

    // Create vault directories if they don't exist
    let docs_dir = vault_root.join("docs");
    let packs_dir = vault_root.join("packs");

    std::fs::create_dir_all(&docs_dir)?;
    std::fs::create_dir_all(&packs_dir)?;

    // Check if Momentum pack is installed and up to date
    let pack_name_with_version = format!("momentum@{MOMENTUM_PACK_VERSION}");
    let momentum_pack_dir = packs_dir.join(&pack_name_with_version);

    if !momentum_pack_dir.exists() {
        // Remove old versions if they exist
        remove_old_pack_versions(&packs_dir, "momentum")?;

        // Install the current version
        install_momentum_pack(&packs_dir)?;
    }

    Ok(())
}

fn remove_old_pack_versions(packs_dir: &std::path::Path, pack_name: &str) -> Result<()> {
    // Look for any directories matching momentum@*
    for entry in std::fs::read_dir(packs_dir)? {
        let entry = entry?;
        let file_name = entry.file_name();
        let name_str = file_name.to_string_lossy();

        if name_str.starts_with(&format!("{pack_name}@")) {
            let path = entry.path();
            if path.is_dir() {
                println!("Removing old pack version: {name_str}");
                std::fs::remove_dir_all(path)?;
            }
        }
    }
    Ok(())
}

fn install_momentum_pack(packs_dir: &std::path::Path) -> Result<()> {
    let pack_name_with_version = format!("momentum@{MOMENTUM_PACK_VERSION}");
    let momentum_pack_dir = packs_dir.join(&pack_name_with_version);
    std::fs::create_dir_all(&momentum_pack_dir)?;

    // Copy pack files from embedded resources to vault
    let _pack_source = std::path::Path::new("momentum/packs/momentum");

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

    println!(
        "Momentum pack v{} installed successfully in vault at: {}",
        MOMENTUM_PACK_VERSION,
        momentum_pack_dir.display()
    );

    Ok(())
}
