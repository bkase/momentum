#!/usr/bin/env swift

import Foundation

// Replicate the exact async process execution from ProcessHelpers.swift
func executeCommand(_ command: String, arguments: [String]) async throws -> (output: String?, error: String?, exitCode: Int32) {
    try await withCheckedThrowingContinuation { continuation in
        Task.detached {
            let task = Process()
            
            let devPath = "/Users/bkase/Documents/momentum/momentum/target/release/momentum"
            task.executableURL = URL(fileURLWithPath: devPath)
            
            task.arguments = [command] + arguments
            
            var environment = ProcessInfo.processInfo.environment
            environment["ANTHROPIC_API_KEY"] = "dummy-key-for-development"
            task.environment = environment
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            task.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8)
                let error = String(data: errorData, encoding: .utf8)
                
                print("Raw output data length: \(outputData.count)")
                print("Raw output: \(output ?? "nil")")
                print("Raw error: \(error ?? "nil")")
                
                continuation.resume(returning: (output, error, process.terminationStatus))
            }
            
            do {
                try task.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// Test
Task {
    do {
        print("Testing async process execution...")
        let result = try await executeCommand("start", arguments: ["--goal", "Test Goal Async", "--time", "25"])
        print("Exit code: \(result.exitCode)")
        print("Output: '\(result.output ?? "nil")'")
        print("Output is nil: \(result.output == nil)")
        print("Output is empty: \(result.output?.isEmpty ?? false)")
        print("Error: '\(result.error ?? "nil")'")
        
        if let output = result.output {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Trimmed output: '\(trimmed)'")
            print("Trimmed is empty: \(trimmed.isEmpty)")
        }
    } catch {
        print("Error: \(error)")
    }
    exit(0)
}

RunLoop.main.run()