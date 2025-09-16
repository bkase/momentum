import ComposableArchitecture
import Foundation
import A4CoreSwift

@DependencyClient
struct AethelClient {
    var start: @Sendable (String, Int) async throws -> SessionData
    var stop: @Sendable () async throws -> String
    var analyze: @Sendable (String) async throws -> AnalysisResult
    var checkList: @Sendable () async throws -> ChecklistState
    var checkToggle: @Sendable (String) async throws -> ChecklistState
    var getSession: @Sendable () async throws -> SessionData?
}

extension AethelClient: DependencyKey {
    static let liveValue = Self(
        start: { goal, minutes in
            // Find or create the vault
            let (vault, _) = try Vault.resolve(
                cliPath: nil,
                env: ProcessInfo.processInfo.environment,
                cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            )

            // Create session in vault
            let now = Date()
            let session = SessionData(
                goal: goal,
                startTime: UInt64(now.timeIntervalSince1970),
                timeExpected: UInt64(minutes),
                reflectionFilePath: nil
            )

            // Save session to daily note
            let utcDay = Dates.utcDay(from: now)
            let (year, yearMonth, filename) = Dates.dailyPathComponents(for: utcDay)
            let dailyPath = "capture/\(year)/\(yearMonth)/\(filename)"
            let dailyURL = try vault.resolveRelative(dailyPath)

            // Create anchor for session start
            let hhmm = Dates.localHHMM(from: now)
            let anchor = try AnchorToken(parse: "session-start-\(hhmm)")

            // Format session content
            let content = """
            **Goal:** \(goal)
            **Duration:** \(minutes) minutes
            **Started:** \(now.formatted())
            """

            // Ensure the capture directory structure exists
            let captureDir = vault.root.appendingPathComponent("capture/\(year)/\(yearMonth)")
            try FileManager.default.createDirectory(
                at: captureDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Create daily note if it doesn't exist
            if !FileManager.default.fileExists(atPath: dailyURL.path) {
                let initialContent = """
                ---
                date: \(now.ISO8601Format())
                ---

                # Daily Note - \(now.formatted(date: .complete, time: .omitted))

                ## Sessions
                """
                try initialContent.write(to: dailyURL, atomically: true, encoding: .utf8)
            }

            // Append session to daily note
            try Append.appendBlock(
                vault: vault,
                targetFile: dailyURL,
                opts: AppendOptions(
                    heading: "Sessions",
                    anchor: anchor,
                    content: content.data(using: .utf8)!
                )
            )

            // Save session state locally for retrieval
            let sessionPath = FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Momentum/session.json")

            // Create directory if needed
            let supportDir = sessionPath.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: supportDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(session)
            try data.write(to: sessionPath)

            return session
        },
        stop: {
            // Read current session
            let sessionPath = FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Momentum/session.json")

            guard FileManager.default.fileExists(atPath: sessionPath.path) else {
                throw RustCoreError.invalidOutput("No active session found")
            }

            let sessionData = try Data(contentsOf: sessionPath)
            let session = try JSONDecoder().decode(SessionData.self, from: sessionData)

            // Find vault
            let (vault, _) = try Vault.resolve(
                cliPath: nil,
                env: ProcessInfo.processInfo.environment,
                cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            )

            // Create reflection file
            let now = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmm"
            let filename = "\(formatter.string(from: now))-\(session.goal.lowercased().replacingOccurrences(of: " ", with: "-")).md"

            let reflectionsDir = vault.root.appendingPathComponent("reflections")
            try FileManager.default.createDirectory(
                at: reflectionsDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let reflectionPath = reflectionsDir.appendingPathComponent(filename)

            // Load reflection template
            guard let templatePath = Bundle.main.path(forResource: "reflection-template", ofType: "md"),
                  let template = try? String(contentsOfFile: templatePath) else {
                throw RustCoreError.invalidOutput("Reflection template not found")
            }

            // Create reflection content
            let startTime = Date(timeIntervalSince1970: TimeInterval(session.startTime))
            let duration = Int(now.timeIntervalSince(startTime) / 60)

            let reflection = template
                .replacingOccurrences(of: "{{goal}}", with: session.goal)
                .replacingOccurrences(of: "{{duration}}", with: "\(duration) minutes")
                .replacingOccurrences(of: "{{date}}", with: now.formatted(date: .complete, time: .shortened))

            try reflection.write(to: reflectionPath, atomically: true, encoding: .utf8)

            // Update daily note with session end
            let utcDay = Dates.utcDay(from: now)
            let (year, yearMonth, dailyFilename) = Dates.dailyPathComponents(for: utcDay)
            let dailyPath = "capture/\(year)/\(yearMonth)/\(dailyFilename)"
            let dailyURL = try vault.resolveRelative(dailyPath)

            let hhmm = Dates.localHHMM(from: now)
            let anchor = try AnchorToken(parse: "session-end-\(hhmm)")

            let endContent = """
            **Session Completed:** \(session.goal)
            **Duration:** \(duration) minutes
            **Reflection:** [View](\(reflectionPath.path))
            """

            try Append.appendBlock(
                vault: vault,
                targetFile: dailyURL,
                opts: AppendOptions(
                    heading: "Sessions",
                    anchor: anchor,
                    content: endContent.data(using: .utf8)!
                )
            )

            // Delete session file
            try FileManager.default.removeItem(at: sessionPath)

            return reflectionPath.path
        },
        analyze: { filePath in
            // For now, return a placeholder since Claude integration would need separate handling
            // The actual Claude analysis would need to be done via the Claude CLI still
            AnalysisResult(
                summary: "Analysis requires Claude CLI integration",
                suggestion: "Please use the Claude CLI directly for AI analysis",
                reasoning: "AI analysis is not yet integrated with the Swift library"
            )
        },
        checkList: {
            // Load checklist from bundle
            guard let checklistPath = Bundle.main.path(forResource: "checklist", ofType: "json"),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: checklistPath)) else {
                throw RustCoreError.invalidOutput("Checklist not found")
            }

            let decoder = JSONDecoder()
            let items = try decoder.decode([String].self, from: data)

            // Load saved state if exists
            let statePath = FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Momentum/checklist-state.json")

            var checkedItems: Set<String> = []
            if FileManager.default.fileExists(atPath: statePath.path),
               let stateData = try? Data(contentsOf: statePath),
               let state = try? JSONDecoder().decode([String].self, from: stateData) {
                checkedItems = Set(state)
            }

            let checklistItems = items.enumerated().map { index, text in
                ChecklistItem(
                    id: "item-\(index)",
                    text: text,
                    on: checkedItems.contains("item-\(index)")
                )
            }

            return ChecklistState(items: checklistItems)
        },
        checkToggle: { id in
            // Load checklist
            guard let checklistPath = Bundle.main.path(forResource: "checklist", ofType: "json"),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: checklistPath)) else {
                throw RustCoreError.invalidOutput("Checklist not found")
            }

            let decoder = JSONDecoder()
            let items = try decoder.decode([String].self, from: data)

            // Load and update state
            let statePath = FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Momentum/checklist-state.json")

            var checkedItems: Set<String> = []
            if FileManager.default.fileExists(atPath: statePath.path),
               let stateData = try? Data(contentsOf: statePath),
               let state = try? JSONDecoder().decode([String].self, from: stateData) {
                checkedItems = Set(state)
            }

            // Toggle the item
            if checkedItems.contains(id) {
                checkedItems.remove(id)
            } else {
                checkedItems.insert(id)
            }

            // Save state
            let supportDir = statePath.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: supportDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let stateData = try encoder.encode(Array(checkedItems))
            try stateData.write(to: statePath)

            // Return updated checklist
            let checklistItems = items.enumerated().map { index, text in
                ChecklistItem(
                    id: "item-\(index)",
                    text: text,
                    on: checkedItems.contains("item-\(index)")
                )
            }

            return ChecklistState(items: checklistItems)
        },
        getSession: {
            let sessionPath = FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Momentum/session.json")

            guard FileManager.default.fileExists(atPath: sessionPath.path) else {
                return nil
            }

            let data = try Data(contentsOf: sessionPath)
            return try JSONDecoder().decode(SessionData.self, from: data)
        }
    )

    static let testValue = Self(
        start: { goal, minutes in
            SessionData(
                goal: goal,
                startTime: 1_700_000_000,
                timeExpected: UInt64(minutes),
                reflectionFilePath: nil
            )
        },
        stop: {
            "/tmp/test-reflection.md"
        },
        analyze: { _ in
            AnalysisResult(
                summary: "Test analysis summary",
                suggestion: "Test suggestion",
                reasoning: "Test reasoning"
            )
        },
        checkList: {
            ChecklistState(items: [
                ChecklistItem(id: "test-1", text: "Test item 1", on: false),
                ChecklistItem(id: "test-2", text: "Test item 2", on: false),
            ])
        },
        checkToggle: { id in
            ChecklistState(items: [
                ChecklistItem(id: "test-1", text: "Test item 1", on: id == "test-1"),
                ChecklistItem(id: "test-2", text: "Test item 2", on: id == "test-2"),
            ])
        },
        getSession: {
            nil
        }
    )
}

extension DependencyValues {
    var aethelClient: AethelClient {
        get { self[AethelClient.self] }
        set { self[AethelClient.self] = newValue }
    }
}