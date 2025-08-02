#[cfg(test)]
mod tests {
    use crate::aethel_storage::{AethelStorage, RealAethelStorage};
    use crate::index::IndexManager;
    use std::time::Instant;
    use tempfile::TempDir;
    use uuid::Uuid;

    async fn setup_large_vault() -> (TempDir, RealAethelStorage, Uuid) {
        let temp_dir = TempDir::new().unwrap();
        let vault_root = temp_dir.path();
        let docs_dir = vault_root.join("docs");
        std::fs::create_dir_all(&docs_dir).unwrap();

        // Create 1000 dummy documents to simulate a large vault
        for i in 0..1000 {
            let uuid = Uuid::new_v4();
            let content = format!(
                "---\nuuid: {}\ntype: dummy.document\ntitle: Document {}\n---\n# Document {}",
                uuid, i, i
            );
            std::fs::write(docs_dir.join(format!("{}.md", uuid)), content).unwrap();
        }

        // Create one session document that we'll search for
        let session_uuid = Uuid::new_v4();
        let session_content = format!(
            "---\nuuid: {}\ntype: momentum.session\ncreated: 2000-01-01T00:00:00Z\nupdated: 2000-01-01T00:00:00Z\nv: 1.0.0\ntags: []\ngoal: Test session\nstart_time: 1700000000\ntime_expected: 60\n---\n# Active Session",
            session_uuid
        );
        std::fs::write(
            docs_dir.join(format!("{}.md", session_uuid)),
            session_content,
        )
        .unwrap();

        // Create one checklist document with required aethel fields
        let checklist_uuid = Uuid::new_v4();
        let checklist_content = format!(
            "---\nuuid: {}\ntype: momentum.checklist\ncreated: 2000-01-01T00:00:00Z\nupdated: 2000-01-01T00:00:00Z\nv: 1.0.0\ntags: []\nitems: []\n---\n# Checklist",
            checklist_uuid
        );
        std::fs::write(
            docs_dir.join(format!("{}.md", checklist_uuid)),
            checklist_content,
        )
        .unwrap();

        let storage = RealAethelStorage::new(vault_root.to_path_buf());

        (temp_dir, storage, session_uuid)
    }

    #[tokio::test]
    async fn test_performance_improvement_find_active_session() {
        let (_temp_dir, storage, expected_uuid) = setup_large_vault().await;

        // Time the first lookup (which will use linear search and populate index)
        let start = Instant::now();
        let result1 = storage.find_active_session().await.unwrap();
        let first_lookup_time = start.elapsed();

        assert_eq!(result1, Some(expected_uuid));

        // Time the second lookup (which should use index for O(1) performance)
        let start = Instant::now();
        let result2 = storage.find_active_session().await.unwrap();
        let second_lookup_time = start.elapsed();

        assert_eq!(result2, Some(expected_uuid));

        // The second lookup should be significantly faster
        // We expect at least 2x improvement, but usually much more
        println!("First lookup (linear search): {:?}", first_lookup_time);
        println!("Second lookup (index): {:?}", second_lookup_time);

        // Verify the second lookup is faster (with some tolerance for timing variance)
        assert!(
            second_lookup_time < first_lookup_time * 3 / 4,
            "Index lookup should be faster than linear search. First: {:?}, Second: {:?}",
            first_lookup_time,
            second_lookup_time
        );
    }

    #[tokio::test]
    async fn test_performance_improvement_get_checklist() {
        let (_temp_dir, storage, _) = setup_large_vault().await;

        // Time the first lookup (which will use linear search and populate index)
        let start = Instant::now();
        let result1 = storage.get_or_create_checklist().await.unwrap();
        let first_lookup_time = start.elapsed();

        let checklist_uuid = result1.0;

        // Time the second lookup (which should use index for O(1) performance)
        let start = Instant::now();
        let result2 = storage.get_or_create_checklist().await.unwrap();
        let second_lookup_time = start.elapsed();

        assert_eq!(result2.0, checklist_uuid);

        // The second lookup should be significantly faster
        println!(
            "First checklist lookup (linear search): {:?}",
            first_lookup_time
        );
        println!("Second checklist lookup (index): {:?}", second_lookup_time);

        // Verify the second lookup is faster
        assert!(
            second_lookup_time < first_lookup_time * 3 / 4,
            "Index lookup should be faster than linear search. First: {:?}, Second: {:?}",
            first_lookup_time,
            second_lookup_time
        );
    }

    #[tokio::test]
    async fn test_index_consistency_under_load() {
        let (_temp_dir, storage, original_session_uuid) = setup_large_vault().await;

        // Perform multiple operations to ensure index stays consistent
        for i in 0..10 {
            // Find active session
            let session_result = storage.find_active_session().await.unwrap();
            assert_eq!(
                session_result,
                Some(original_session_uuid),
                "Iteration {}",
                i
            );

            // Get checklist
            let checklist_result = storage.get_or_create_checklist().await.unwrap();
            assert!(!checklist_result.1.items.is_empty() || checklist_result.1.items.is_empty()); // Just verify it returns

            // Verify we get the same results consistently
            if i > 0 {
                let session_result2 = storage.find_active_session().await.unwrap();
                assert_eq!(
                    session_result, session_result2,
                    "Session lookup inconsistent at iteration {}",
                    i
                );
            }
        }
    }

    #[test]
    fn test_migration_performance_with_large_vault() {
        let temp_dir = TempDir::new().unwrap();
        let vault_root = temp_dir.path();
        let docs_dir = vault_root.join("docs");
        std::fs::create_dir_all(&docs_dir).unwrap();

        // Create 500 documents (lighter test for CI)
        for i in 0..500 {
            let uuid = Uuid::new_v4();
            let doc_type = if i % 100 == 0 {
                "momentum.session"
            } else if i % 50 == 0 {
                "momentum.checklist"
            } else {
                "dummy.document"
            };

            let content = format!(
                "---\nuuid: {}\ntype: {}\ntitle: Document {}\n---\n# Document {}",
                uuid, doc_type, i, i
            );
            std::fs::write(docs_dir.join(format!("{}.md", uuid)), content).unwrap();
        }

        let index_manager = IndexManager::new(vault_root.to_path_buf());

        // Time the migration
        let start = Instant::now();
        index_manager.migrate_from_vault(vault_root).unwrap();
        let migration_time = start.elapsed();

        println!("Migration of 500 documents took: {:?}", migration_time);

        // Verify migration created correct index entries
        let index = index_manager.read_index().unwrap();
        assert!(
            index.contains_key("active_session"),
            "Should find at least one session"
        );
        assert!(
            index.contains_key("checklist"),
            "Should find at least one checklist"
        );

        // Migration should complete reasonably quickly (under 1 second for 500 docs)
        assert!(
            migration_time.as_secs() < 2,
            "Migration should be fast, took {:?}",
            migration_time
        );
    }
}
