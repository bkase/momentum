import Foundation

enum AppError: LocalizedError, Equatable {
    case sessionAlreadyActive
    case noActiveSession
    case noReflectionToAnalyze
    case rustCore(RustCoreError)
    case invalidInput(reason: String)
    case other(String)
    case unexpected(String)

    var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            "A session is already active"
        case .noActiveSession:
            "No active session to stop"
        case .noReflectionToAnalyze:
            "No reflection file to analyze"
        case let .rustCore(error):
            error.errorDescription
        case let .invalidInput(reason):
            reason
        case let .other(message):
            message
        case let .unexpected(message):
            "Unexpected error: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .sessionAlreadyActive:
            "Please stop the current session before starting a new one"
        case .noActiveSession:
            "Start a new session first"
        case .noReflectionToAnalyze:
            "Complete a session to create a reflection file"
        case .rustCore:
            "Check your API key and network connection"
        case .invalidInput:
            "Please check your input and try again"
        case .other:
            "Please try again"
        case .unexpected:
            "Please try again or restart the app"
        }
    }
}
