import Foundation

// MARK: - Process Result

struct ProcessResult: Equatable {
    let output: String?
    let error: String?
    let exitCode: Int32
}

// MARK: - Process Execution Helpers

func executeCommand(_ command: String, arguments: [String]) async throws -> ProcessResult {
    throw RustCoreError.binaryNotFound
}

func loadSession(from path: String) throws -> SessionData {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(SessionData.self, from: data)
}
