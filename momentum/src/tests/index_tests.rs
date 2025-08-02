#[cfg(test)]
mod tests {
    use crate::index::IndexManager;
    use std::collections::HashMap;
    use tempfile::TempDir;
    use uuid::Uuid;

    fn setup_test_vault() -> (TempDir, IndexManager) {
        let temp_dir = TempDir::new().unwrap();
        let vault_root = temp_dir.path().to_path_buf();
        let index_manager = IndexManager::new(vault_root);
        (temp_dir, index_manager)
    }

    #[test]
    fn test_read_index_empty_when_no_file_exists() {
        let (_temp_dir, index_manager) = setup_test_vault();

        let index = index_manager.read_index().unwrap();
        assert!(index.is_empty());
    }

    #[test]
    fn test_write_and_read_index() {
        let (_temp_dir, index_manager) = setup_test_vault();

        let uuid1 = Uuid::new_v4();
        let uuid2 = Uuid::new_v4();

        let mut expected_index = HashMap::new();
        expected_index.insert("active_session".to_string(), uuid1.to_string());
        expected_index.insert("checklist".to_string(), uuid2.to_string());

        index_manager.write_index(&expected_index).unwrap();

        let actual_index = index_manager.read_index().unwrap();
        assert_eq!(actual_index, expected_index);
    }

    #[test]
    fn test_update_entry() {
        let (_temp_dir, index_manager) = setup_test_vault();

        let uuid1 = Uuid::new_v4();
        let uuid2 = Uuid::new_v4();

        // Add first entry
        index_manager
            .update_entry("active_session", &uuid1)
            .unwrap();
        let index = index_manager.read_index().unwrap();
        assert_eq!(index.get("active_session"), Some(&uuid1.to_string()));

        // Add second entry
        index_manager.update_entry("checklist", &uuid2).unwrap();
        let index = index_manager.read_index().unwrap();
        assert_eq!(index.get("active_session"), Some(&uuid1.to_string()));
        assert_eq!(index.get("checklist"), Some(&uuid2.to_string()));

        // Update existing entry
        let uuid3 = Uuid::new_v4();
        index_manager
            .update_entry("active_session", &uuid3)
            .unwrap();
        let index = index_manager.read_index().unwrap();
        assert_eq!(index.get("active_session"), Some(&uuid3.to_string()));
        assert_eq!(index.get("checklist"), Some(&uuid2.to_string()));
    }

    #[test]
    fn test_remove_entry() {
        let (_temp_dir, index_manager) = setup_test_vault();

        let uuid1 = Uuid::new_v4();
        let uuid2 = Uuid::new_v4();

        // Add entries
        index_manager
            .update_entry("active_session", &uuid1)
            .unwrap();
        index_manager.update_entry("checklist", &uuid2).unwrap();

        // Remove one entry
        index_manager.remove_entry("active_session").unwrap();
        let index = index_manager.read_index().unwrap();
        assert!(index.get("active_session").is_none());
        assert_eq!(index.get("checklist"), Some(&uuid2.to_string()));

        // Remove non-existent entry (should not error)
        index_manager.remove_entry("non_existent").unwrap();
    }

    #[test]
    fn test_get_entry() {
        let (_temp_dir, index_manager) = setup_test_vault();

        let uuid = Uuid::new_v4();

        // Get non-existent entry
        let result = index_manager.get_entry("active_session").unwrap();
        assert!(result.is_none());

        // Add entry and get it
        index_manager.update_entry("active_session", &uuid).unwrap();
        let result = index_manager.get_entry("active_session").unwrap();
        assert_eq!(result, Some(uuid));
    }

    #[test]
    fn test_migrate_from_vault_with_documents() {
        let temp_dir = TempDir::new().unwrap();
        let vault_root = temp_dir.path();
        let docs_dir = vault_root.join("docs");
        std::fs::create_dir_all(&docs_dir).unwrap();

        let session_uuid = Uuid::new_v4();
        let checklist_uuid = Uuid::new_v4();
        let reflection_uuid = Uuid::new_v4();

        // Create mock session document
        let session_content = format!(
            "---\nuuid: {}\ntype: momentum.session\ngoal: Test session\n---\n# Session",
            session_uuid
        );
        std::fs::write(
            docs_dir.join(format!("{}.md", session_uuid)),
            session_content,
        )
        .unwrap();

        // Create mock checklist document
        let checklist_content = format!(
            "---\nuuid: {}\ntype: momentum.checklist\n---\n# Checklist",
            checklist_uuid
        );
        std::fs::write(
            docs_dir.join(format!("{}.md", checklist_uuid)),
            checklist_content,
        )
        .unwrap();

        // Create mock reflection document (should not be indexed)
        let reflection_content = format!(
            "---\nuuid: {}\ntype: momentum.reflection\n---\n# Reflection",
            reflection_uuid
        );
        std::fs::write(
            docs_dir.join(format!("{}.md", reflection_uuid)),
            reflection_content,
        )
        .unwrap();

        // Create archived session (should not be indexed)
        let archived_uuid = Uuid::new_v4();
        let archived_content = format!(
            "---\nuuid: {}\ntype: momentum.session\narchived: true\n---\n# Archived Session",
            archived_uuid
        );
        std::fs::write(
            docs_dir.join(format!("{}.md", archived_uuid)),
            archived_content,
        )
        .unwrap();

        let index_manager = IndexManager::new(vault_root.to_path_buf());
        index_manager.migrate_from_vault(vault_root).unwrap();

        let index = index_manager.read_index().unwrap();
        assert_eq!(index.get("active_session"), Some(&session_uuid.to_string()));
        assert_eq!(index.get("checklist"), Some(&checklist_uuid.to_string()));
        assert!(index.get("reflection").is_none()); // Reflections not indexed
        assert_eq!(index.len(), 2); // Only session and checklist
    }

    #[test]
    fn test_migrate_from_empty_vault() {
        let temp_dir = TempDir::new().unwrap();
        let vault_root = temp_dir.path();

        let index_manager = IndexManager::new(vault_root.to_path_buf());
        index_manager.migrate_from_vault(vault_root).unwrap();

        let index = index_manager.read_index().unwrap();
        assert!(index.is_empty());
    }

    #[test]
    fn test_index_file_corruption_recovery() {
        let (_temp_dir, index_manager) = setup_test_vault();

        // Write corrupted JSON to index file
        let index_path = index_manager.get_index_path();
        std::fs::create_dir_all(index_path.parent().unwrap()).unwrap();
        std::fs::write(&index_path, "invalid json {").unwrap();

        // Should return empty index on corruption
        let index = index_manager.read_index().unwrap();
        assert!(index.is_empty());

        // Should be able to write normally after corruption
        let uuid = Uuid::new_v4();
        index_manager.update_entry("test", &uuid).unwrap();

        let index = index_manager.read_index().unwrap();
        assert_eq!(index.get("test"), Some(&uuid.to_string()));
    }
}
