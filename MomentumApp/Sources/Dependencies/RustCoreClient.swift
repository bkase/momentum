import ComposableArchitecture
import Foundation

@DependencyClient
struct RustCoreClient {
    var start: @Sendable (String, Int) async throws -> SessionData
    var stop: @Sendable () async throws -> String
    var analyze: @Sendable (String) async throws -> AnalysisResult
    var checkList: @Sendable () async throws -> ChecklistState
    var checkToggle: @Sendable (String) async throws -> ChecklistState
}

extension RustCoreClient: DependencyKey {
    static let liveValue = Self(
        start: { goal, minutes in
            let result = try await executeCommand("start", arguments: ["--goal", goal, "--time", String(minutes)])

            guard let sessionPath = result.output?.trimmingCharacters(in: .whitespacesAndNewlines),
                !sessionPath.isEmpty
            else {
                throw RustCoreError.invalidOutput("start command returned no session path")
            }

            do {
                return try loadSession(from: sessionPath)
            } catch {
                throw RustCoreError.sessionLoadFailed(path: sessionPath, error: error)
            }
        },
        stop: {
            let result = try await executeCommand("stop", arguments: [])

            guard let reflectionPath = result.output?.trimmingCharacters(in: .whitespacesAndNewlines),
                !reflectionPath.isEmpty
            else {
                throw RustCoreError.invalidOutput("stop command returned no reflection path")
            }

            return reflectionPath
        },
        analyze: { filePath in
            let result = try await executeCommand("analyze", arguments: ["--file", filePath])

            guard let analysisJson = result.output,
                !analysisJson.isEmpty,
                let data = analysisJson.data(using: .utf8)
            else {
                throw RustCoreError.invalidOutput("analyze command returned no JSON")
            }

            do {
                return try JSONDecoder().decode(AnalysisResult.self, from: data)
            } catch {
                throw RustCoreError.decodingFailed(error)
            }
        },
        checkList: {
            let result = try await executeCommand("check", arguments: ["list"])

            guard let checklistJson = result.output,
                !checklistJson.isEmpty,
                let data = checklistJson.data(using: .utf8)
            else {
                throw RustCoreError.invalidOutput("check list command returned no JSON")
            }

            do {
                return try JSONDecoder().decode(ChecklistState.self, from: data)
            } catch {
                throw RustCoreError.decodingFailed(error)
            }
        },
        checkToggle: { id in
            let result = try await executeCommand("check", arguments: ["toggle", id])

            guard let checklistJson = result.output,
                !checklistJson.isEmpty,
                let data = checklistJson.data(using: .utf8)
            else {
                throw RustCoreError.invalidOutput("check toggle command returned no JSON")
            }

            do {
                return try JSONDecoder().decode(ChecklistState.self, from: data)
            } catch {
                throw RustCoreError.decodingFailed(error)
            }
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
                suggestion: "Test suggestion",
                reasoning: "Test reasoning"
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
        }
    )
}

extension DependencyValues {
    var rustCoreClient: RustCoreClient {
        get { self[RustCoreClient.self] }
        set { self[RustCoreClient.self] = newValue }
    }
}
