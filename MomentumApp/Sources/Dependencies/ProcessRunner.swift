import ComposableArchitecture
import Foundation

struct ProcessRunner: DependencyKey {
    var run: @Sendable (String, [String]) async throws -> ProcessResult

    static let liveValue = Self { command, arguments in
        try await executeCommand(command, arguments: arguments)
    }

    static let testValue = Self { command, arguments in
        // Return mock responses based on command
        switch command {
        case "start":
            // Create a temporary session file for testing
            let sessionPath = "/tmp/test-session.json"
            return ProcessResult(
                output: sessionPath,
                error: nil,
                exitCode: 0
            )
        case "stop":
            return ProcessResult(
                output: "/tmp/test-reflection.md",
                error: nil,
                exitCode: 0
            )
        case "analyze":
            let analysisJson = """
                {
                    "summary": "Test analysis summary",
                    "suggestion": "Test suggestion",
                    "reasoning": "Test reasoning"
                }
                """
            return ProcessResult(
                output: analysisJson,
                error: nil,
                exitCode: 0
            )
        default:
            return ProcessResult(
                output: "",
                error: nil,
                exitCode: 0
            )
        }
    }
}

extension DependencyValues {
    var processRunner: ProcessRunner {
        get { self[ProcessRunner.self] }
        set { self[ProcessRunner.self] = newValue }
    }
}
