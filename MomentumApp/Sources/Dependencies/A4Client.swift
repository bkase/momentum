import A4CoreSwift
import ComposableArchitecture
import Foundation

@DependencyClient
struct A4Client {
    var start: @Sendable (String, Int) async throws -> SessionData
    var stop: @Sendable () async throws -> String
    var analyze: @Sendable (String) async throws -> AnalysisResult
    var checkList: @Sendable () async throws -> ChecklistState
    var checkToggle: @Sendable (String) async throws -> ChecklistState
    var getSession: @Sendable () async throws -> SessionData?
}

extension A4Client: DependencyKey {
    static let liveValue = Self(
        start: { goal, minutes in
            // Create session
            let now = Date()
            let session = SessionData(
                goal: goal,
                startTime: UInt64(now.timeIntervalSince1970),
                timeExpected: UInt64(minutes),
                reflectionFilePath: nil
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
            let filenameDateFormatter = DateFormatter()
            filenameDateFormatter.dateFormat = "yyyy-MM-dd"
            let filenameDateString = filenameDateFormatter.string(from: now)

            // Use title slug format for filename
            let filename =
                "focus-\(session.goal.lowercased().replacingOccurrences(of: " ", with: "-"))-\(filenameDateString).md"

            // Create calendar hierarchy in collections/focus
            let focusYear = filenameDateFormatter.string(from: now).prefix(4)
            let focusMonth = filenameDateFormatter.string(from: now).dropFirst(5).prefix(2)

            let focusDir = vault.root.appendingPathComponent("collections/focus/\(focusYear)/\(focusMonth)")
            try FileManager.default.createDirectory(
                at: focusDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let reflectionPath = focusDir.appendingPathComponent(filename)

            // Load reflection template
            guard let templatePath = Bundle.main.path(forResource: "reflection-template", ofType: "md"),
                let template = try? String(contentsOfFile: templatePath)
            else {
                throw RustCoreError.invalidOutput("Reflection template not found")
            }

            // Calculate session details
            let startTime = Date(timeIntervalSince1970: TimeInterval(session.startTime))
            let duration = Int(now.timeIntervalSince(startTime) / 60)

            // Create reflection content with session details and template
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: now)

            let reflectionContent = """
                ---
                goal: \(session.goal)
                start_time: \(startTime.ISO8601Format())
                end_time: \(now.ISO8601Format())
                duration_minutes: \(duration)
                expected_minutes: \(session.timeExpected)
                ---

                # Focus: \(session.goal) \(dateString)

                **Duration:** \(duration) minutes (expected: \(session.timeExpected) minutes)

                \(template
                .replacingOccurrences(of: "{{goal}}", with: session.goal)
                .replacingOccurrences(of: "{{duration}}", with: "\(duration) minutes")
                .replacingOccurrences(of: "{{date}}", with: now.formatted(date: .complete, time: .shortened)))
                """

            try reflectionContent.write(to: reflectionPath, atomically: true, encoding: .utf8)

            // Add single summary entry to daily note
            let utcDay = Dates.utcDay(from: now)
            let (year, yearMonth, dailyFilename) = Dates.dailyPathComponents(for: utcDay)
            let dailyPath = "capture/\(year)/\(yearMonth)/\(dailyFilename)"
            let dailyURL = try vault.resolveRelative(dailyPath)

            // Ensure the capture directory structure exists
            let captureDir = vault.root.appendingPathComponent("capture/\(year)/\(yearMonth)")
            try FileManager.default.createDirectory(
                at: captureDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Create daily note if it doesn't exist
            if !FileManager.default.fileExists(atPath: dailyURL.path) {
                // Try to use template first
                let templatePath = vault.root.appendingPathComponent("routines/templates/daily.md")
                var initialContent: String

                if FileManager.default.fileExists(atPath: templatePath.path),
                    let template = try? String(contentsOf: templatePath, encoding: .utf8)
                {
                    // Fill in template variables
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.timeZone = TimeZone(identifier: "UTC")
                    isoFormatter.formatOptions = [.withInternetDateTime]
                    let nowUTC = isoFormatter.string(from: now)

                    let yyyyMMdd = String(
                        format: "%04d-%02d-%02d",
                        utcDay.year,
                        utcDay.month,
                        utcDay.day
                    )

                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "HHmm"
                    timeFormatter.timeZone = TimeZone.current
                    let hhmm = timeFormatter.string(from: now)

                    initialContent =
                        template
                        .replacingOccurrences(of: "{{now_utc}}", with: nowUTC)
                        .replacingOccurrences(of: "{{YYYY-MM-DD}}", with: yyyyMMdd)
                        .replacingOccurrences(of: "{{hhmm}}", with: hhmm)

                    // Add Focus heading if not present
                    if !initialContent.contains("## Focus") {
                        initialContent.append("\n## Focus\n")
                    }
                } else {
                    // Fallback if template not found
                    initialContent = """
                        ---
                        kind: capture.day
                        created: \(now.ISO8601Format())
                        tags: [daily]
                        ---
                        # Daily Note \(now.formatted(date: .complete, time: .omitted))

                        ## Focus
                        """
                }

                try initialContent.write(to: dailyURL, atomically: true, encoding: .utf8)
            }

            let hhmm = Dates.localHHMM(from: now)
            let anchor = try AnchorToken(parse: "focus-\(hhmm)")

            // Create session summary for daily note
            // Build the title slug for the link
            let linkDateFormatter = DateFormatter()
            linkDateFormatter.dateFormat = "yyyy-MM-dd"
            let linkDateString = linkDateFormatter.string(from: now)

            // Create slug from "Focus: <task> YYYY-MM-DD"
            let titleSlug =
                "focus-\(session.goal.lowercased().replacingOccurrences(of: " ", with: "-"))-\(linkDateString)"

            let sessionSummary = """
                **\(session.goal)** (\(duration) min)
                [[\(titleSlug)|Focus: \(session.goal)]]
                """

            try Append.appendBlock(
                vault: vault,
                targetFile: dailyURL,
                opts: AppendOptions(
                    heading: "Focus",
                    anchor: anchor,
                    content: sessionSummary.data(using: .utf8)!
                )
            )

            // Delete session file
            try FileManager.default.removeItem(at: sessionPath)

            // Reset checklist state
            let checklistStatePath = FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Momentum/checklist-state.json")

            if FileManager.default.fileExists(atPath: checklistStatePath.path) {
                try FileManager.default.removeItem(at: checklistStatePath)
            }

            return reflectionPath.path
        },
        analyze: { filePath in
            let reflectionURL = URL(fileURLWithPath: filePath)
            let reflectionContent = try String(contentsOf: reflectionURL, encoding: .utf8)

            let prompt = """
                You are an AI productivity coach analyzing a focus session reflection.

                Please analyze the following reflection and provide:
                1. A brief summary of what happened during the session
                2. Specific actionable suggestions for improvement + reasoning
                3. More reflection questions to go deeper
                Reflection:
                \(reflectionContent)

                Respond in JSON format with these exact fields:
                {
                    "summary": "brief summary of the session",
                    "suggestions": "specific actionable suggestions",
                    "questions": "deeper reflection questions"
                }
                """

            let escapedPrompt = escapeForSingleQuotes(prompt)
            let command = "source ~/.zshrc && eval \"$(mise hook-env -s zsh)\" && claude -p '\(escapedPrompt)'"

            let result = try await runZshCommand(command)

            guard result.exitCode == 0 else {
                throw RustCoreError.commandFailed(
                    command: "claude",
                    exitCode: result.exitCode,
                    stderr: result.error
                )
            }

            guard let analysisJson = result.output?.trimmingCharacters(in: .whitespacesAndNewlines),
                !analysisJson.isEmpty,
                let data = analysisJson.data(using: .utf8)
            else {
                throw RustCoreError.invalidOutput("Claude returned no JSON content")
            }

            let decoder = JSONDecoder()
            let analysisResult: AnalysisResult
            do {
                analysisResult = try decoder.decode(AnalysisResult.self, from: data)
            } catch {
                guard
                    let extracted = extractJSONObject(from: analysisJson),
                    let extractedData = extracted.data(using: .utf8),
                    let fallback = try? decoder.decode(AnalysisResult.self, from: extractedData)
                else {
                    throw RustCoreError.decodingFailed(error)
                }
                analysisResult = fallback
            }

            var updatedReflection = reflectionContent
            if !updatedReflection.hasSuffix("\n") {
                updatedReflection.append("\n")
            }

            let analysisSection =
            """
            ## AI Analysis

            \(analysisResult.summary)

            ### Actionable Suggestions

            \(analysisResult.suggestions)

            ### Deeper Questions

            \(analysisResult.questions)
            """

            updatedReflection.append(analysisSection)
            try updatedReflection.write(to: reflectionURL, atomically: true, encoding: .utf8)

            return analysisResult
        },
        checkList: {
            // Load checklist from bundle
            guard let checklistPath = Bundle.main.path(forResource: "checklist", ofType: "json"),
                let data = try? Data(contentsOf: URL(fileURLWithPath: checklistPath))
            else {
                throw RustCoreError.invalidOutput("Checklist not found")
            }

            struct ChecklistItemJSON: Decodable {
                let id: String
                let text: String
            }

            let decoder = JSONDecoder()
            let items = try decoder.decode([ChecklistItemJSON].self, from: data)

            // Load saved state if exists
            let statePath = FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Momentum/checklist-state.json")

            var checkedItems: Set<String> = []
            if FileManager.default.fileExists(atPath: statePath.path),
                let stateData = try? Data(contentsOf: statePath),
                let state = try? JSONDecoder().decode([String].self, from: stateData)
            {
                checkedItems = Set(state)
            }

            let checklistItems = items.map { item in
                ChecklistItem(
                    id: item.id,
                    text: item.text,
                    on: checkedItems.contains(item.id)
                )
            }

            return ChecklistState(items: checklistItems)
        },
        checkToggle: { id in
            // Load checklist
            guard let checklistPath = Bundle.main.path(forResource: "checklist", ofType: "json"),
                let data = try? Data(contentsOf: URL(fileURLWithPath: checklistPath))
            else {
                throw RustCoreError.invalidOutput("Checklist not found")
            }

            struct ChecklistItemJSON: Decodable {
                let id: String
                let text: String
            }

            let decoder = JSONDecoder()
            let items = try decoder.decode([ChecklistItemJSON].self, from: data)

            // Load and update state
            let statePath = FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Momentum/checklist-state.json")

            var checkedItems: Set<String> = []
            if FileManager.default.fileExists(atPath: statePath.path),
                let stateData = try? Data(contentsOf: statePath),
                let state = try? JSONDecoder().decode([String].self, from: stateData)
            {
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
            let checklistItems = items.map { item in
                ChecklistItem(
                    id: item.id,
                    text: item.text,
                    on: checkedItems.contains(item.id)
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
                timeExpected: UInt64(minutes),  // Rust expects minutes, not seconds
                reflectionFilePath: nil
            )
        },
        stop: {
            "/tmp/test-reflection.md"
        },
        analyze: { _ in
            AnalysisResult(
                summary: "Test analysis summary",
                suggestions: "Test suggestions",
                questions: "Test questions"
            )
        },
        checkList: {
            // Return minimal checklist for tests
            ChecklistState(items: [
                ChecklistItem(id: "test-1", text: "Test item 1", on: false),
                ChecklistItem(id: "test-2", text: "Test item 2", on: false),
            ])
        },
        checkToggle: { id in
            // Return checklist with toggled item
            ChecklistState(items: [
                ChecklistItem(id: "test-1", text: "Test item 1", on: id == "test-1"),
                ChecklistItem(id: "test-2", text: "Test item 2", on: id == "test-2"),
            ])
        },
        getSession: {
            // Return nil by default for tests - tests can override if needed
            return nil
        }
    )
}

extension DependencyValues {
    var a4Client: A4Client {
        get { self[A4Client.self] }
        set { self[A4Client.self] = newValue }
    }
}

// MARK: - Private Helpers

private func escapeForSingleQuotes(_ input: String) -> String {
    input.replacingOccurrences(of: "'", with: "'\"'\"'")
}

private func runZshCommand(_ command: String) async throws -> ProcessResult {
    try await withCheckedThrowingContinuation { continuation in
        Task.detached {
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", command]

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                try process.run()
                process.waitUntilExit()

                let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let outputString = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let errorString = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

                let result = ProcessResult(
                    output: outputString,
                    error: errorString,
                    exitCode: process.terminationStatus
                )

                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private func extractJSONObject(from text: String) -> String? {
    guard
        let start = text.firstIndex(of: "{"),
        let end = text.lastIndex(of: "}")
    else {
        return nil
    }
    return String(text[start...end])
}
