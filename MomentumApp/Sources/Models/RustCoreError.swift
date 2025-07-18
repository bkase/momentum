import Foundation

enum RustCoreError: LocalizedError, Equatable {
    case binaryNotFound
    case commandFailed(command: String, exitCode: Int32, stderr: String?)
    case invalidOutput(String)
    case sessionLoadFailed(path: String, error: Error)
    case decodingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Momentum CLI binary not found"
        case .commandFailed(let command, let exitCode, let stderr):
            return "Command '\(command)' failed with exit code \(exitCode): \(stderr ?? "Unknown error")"
        case .invalidOutput(let message):
            return "Invalid output: \(message)"
        case .sessionLoadFailed(let path, let error):
            return "Failed to load session from \(path): \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
    
    static func == (lhs: RustCoreError, rhs: RustCoreError) -> Bool {
        switch (lhs, rhs) {
        case (.binaryNotFound, .binaryNotFound):
            return true
        case let (.commandFailed(cmd1, code1, stderr1), .commandFailed(cmd2, code2, stderr2)):
            return cmd1 == cmd2 && code1 == code2 && stderr1 == stderr2
        case let (.invalidOutput(msg1), .invalidOutput(msg2)):
            return msg1 == msg2
        case let (.sessionLoadFailed(path1, _), .sessionLoadFailed(path2, _)):
            return path1 == path2
        case (.decodingFailed, .decodingFailed):
            return true
        default:
            return false
        }
    }
}