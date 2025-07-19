import Foundation

// MARK: - Session Data

struct SessionData: Equatable, Codable {
    let goal: String
    let startTime: UInt64
    let timeExpected: UInt64
    let reflectionFilePath: String?

    enum CodingKeys: String, CodingKey {
        case goal
        case startTime = "start_time"
        case timeExpected = "time_expected"
        case reflectionFilePath = "reflection_file_path"
    }

    var startDate: Date {
        Date(timeIntervalSince1970: TimeInterval(startTime))
    }

    var expectedMinutes: UInt64 {
        timeExpected  // timeExpected is already in minutes from Rust
    }
}

// MARK: - Analysis Result

struct AnalysisResult: Equatable, Codable {
    let summary: String
    let suggestion: String
    let reasoning: String
}

// MARK: - Checklist Models

struct ChecklistItem: Equatable, Codable, Identifiable {
    let id: String
    let text: String
    let on: Bool
}

struct ChecklistState: Equatable, Codable {
    let items: [ChecklistItem]
}

// MARK: - Rust Core Errors

enum RustCoreError: LocalizedError, Equatable {
    case binaryNotFound
    case invalidOutput(String)
    case commandFailed(command: String, exitCode: Int32, stderr: String?)
    case decodingFailed(Error)
    case sessionLoadFailed(path: String, error: Error)

    static func == (lhs: RustCoreError, rhs: RustCoreError) -> Bool {
        switch (lhs, rhs) {
        case (.binaryNotFound, .binaryNotFound):
            true
        case let (.invalidOutput(l), .invalidOutput(r)):
            l == r
        case let (.commandFailed(lCommand, lCode, lStderr), .commandFailed(rCommand, rCode, rStderr)):
            lCommand == rCommand && lCode == rCode && lStderr == rStderr
        case let (.decodingFailed(lError), .decodingFailed(rError)):
            lError.localizedDescription == rError.localizedDescription
        case let (.sessionLoadFailed(lPath, lError), .sessionLoadFailed(rPath, rError)):
            lPath == rPath && lError.localizedDescription == rError.localizedDescription
        default:
            false
        }
    }

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            "Momentum CLI binary not found in app bundle"
        case let .invalidOutput(message):
            "Invalid output from command: \(message)"
        case let .commandFailed(command, exitCode, stderr):
            "Command '\(command)' failed with exit code \(exitCode): \(stderr ?? "Unknown error")"
        case let .decodingFailed(error):
            "Failed to decode response: \(error.localizedDescription)"
        case let .sessionLoadFailed(path, error):
            "Failed to load session from \(path): \(error.localizedDescription)"
        }
    }
}
