import Foundation

// MARK: - Process Result

struct ProcessResult: Equatable {
    let output: String?
    let error: String?
    let exitCode: Int32
}

// MARK: - Process Execution Helpers

func executeCommand(_ command: String, arguments: [String]) async throws -> ProcessResult {
    try await withCheckedThrowingContinuation { continuation in
        Task.detached {
            let task = Process()

            // Get the path to the momentum binary in the app bundle
            #if DEBUG
                // During development, try to use the binary from the build directory first
                let devPath = "\(FileManager.default.currentDirectoryPath)/momentum/target/release/momentum"
                if FileManager.default.fileExists(atPath: devPath) {
                    task.executableURL = URL(fileURLWithPath: devPath)
                } else if let binaryPath = Bundle.main.path(forResource: "momentum", ofType: nil) {
                    task.executableURL = URL(fileURLWithPath: binaryPath)
                } else {
                    continuation.resume(throwing: RustCoreError.binaryNotFound)
                    return
                }
            #else
                // In release builds, only look in the app bundle
                guard let binaryPath = Bundle.main.path(forResource: "momentum", ofType: nil) else {
                    continuation.resume(throwing: RustCoreError.binaryNotFound)
                    return
                }
                task.executableURL = URL(fileURLWithPath: binaryPath)
            #endif

            task.arguments = [command] + arguments

            // Pass through environment variables
            task.environment = ProcessInfo.processInfo.environment

            let outputPipe = Pipe()
            let errorPipe = Pipe()

            task.standardOutput = outputPipe
            task.standardError = errorPipe

            task.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8)
                let error = String(data: errorData, encoding: .utf8)

                if process.terminationStatus != 0 {
                    let stderr = error?.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(
                        throwing: RustCoreError.commandFailed(
                            command: command,
                            exitCode: process.terminationStatus,
                            stderr: stderr
                        ))
                } else {
                    continuation.resume(
                        returning: ProcessResult(
                            output: output,
                            error: error,
                            exitCode: process.terminationStatus
                        ))
                }
            }

            do {
                try task.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

func loadSession(from path: String) throws -> SessionData {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(SessionData.self, from: data)
}
