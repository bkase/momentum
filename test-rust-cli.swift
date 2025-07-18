#!/usr/bin/env swift

import Foundation

func executeCommand(_ command: String, arguments: [String]) -> (output: String?, error: String?, exitCode: Int32) {
    let task = Process()
    
    // Use the development binary
    let devPath = "/Users/bkase/Documents/momentum/momentum/target/release/momentum"
    task.executableURL = URL(fileURLWithPath: devPath)
    task.arguments = [command] + arguments
    
    // Set environment
    var environment = ProcessInfo.processInfo.environment
    environment["ANTHROPIC_API_KEY"] = "dummy-key-for-development"
    task.environment = environment
    
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    
    task.standardOutput = outputPipe
    task.standardError = errorPipe
    
    do {
        try task.run()
        task.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8)
        let error = String(data: errorData, encoding: .utf8)
        
        return (output, error, task.terminationStatus)
    } catch {
        print("Failed to run process: \(error)")
        return (nil, error.localizedDescription, -1)
    }
}

// Test the start command
print("Testing 'start' command...")
let result = executeCommand("start", arguments: ["--goal", "Test Goal", "--time", "30"])
print("Exit code: \(result.exitCode)")
print("Output: \(result.output ?? "nil")")
print("Error: \(result.error ?? "nil")")

if let output = result.output, !output.isEmpty {
    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    print("Trimmed output: '\(trimmed)'")
    print("Output length: \(trimmed.count)")
    
    // Try to load the session file
    if let data = try? Data(contentsOf: URL(fileURLWithPath: trimmed)) {
        print("Session file exists and is readable")
        if let json = try? JSONSerialization.jsonObject(with: data) {
            print("Session JSON: \(json)")
        }
    } else {
        print("Failed to read session file from path: \(trimmed)")
    }
}