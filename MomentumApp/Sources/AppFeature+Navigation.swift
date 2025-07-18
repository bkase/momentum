import ComposableArchitecture
import Foundation

extension AppFeature {
    @Reducer(state: .equatable, action: .equatable)
    enum Destination {
        case preparation(PreparationFeature)
        case activeSession(ActiveSessionFeature)
        case reflection(ReflectionFeature)
        case analysis(AnalysisFeature)
    }
}

// MARK: - Alert Helpers

extension AlertState where Action == AppFeature.State.Alert {
    static func sessionAlreadyActive() -> Self {
        AlertState {
            TextState("Session Already Active")
        } actions: {
            ButtonState(action: .dismiss) {
                TextState("OK")
            }
        } message: {
            TextState("Please stop the current session before starting a new one.")
        }
    }
    
    static func noActiveSession() -> Self {
        AlertState {
            TextState("No Active Session")
        } actions: {
            ButtonState(action: .dismiss) {
                TextState("OK")
            }
        } message: {
            TextState("There is no active session to stop.")
        }
    }
    
    static func invalidTime() -> Self {
        AlertState {
            TextState("Invalid Time")
        } actions: {
            ButtonState(action: .dismiss) {
                TextState("OK")
            }
        } message: {
            TextState("Time must be a positive number.")
        }
    }
    
    static func error(_ error: Error) -> Self {
        if let rustError = error as? RustCoreError {
            return rustCoreError(rustError)
        } else if let appError = error as? AppError {
            return Self.appError(appError)
        } else {
            return genericError(error)
        }
    }
    
    static func rustCoreError(_ error: RustCoreError) -> Self {
        let appError = AppError.rustCore(error)
        return AlertState<AppFeature.State.Alert> {
            TextState(appError.errorDescription ?? "Error")
        } actions: {
            // Check if error is related to API key
            if case let .commandFailed(_, _, stderr) = error,
               let stderr = stderr,
               stderr.contains("ANTHROPIC_API_KEY") {
                ButtonState(action: .openSettings) {
                    TextState("Open Settings")
                }
            }
            ButtonState(role: .cancel, action: .dismiss) {
                TextState("OK")
            }
        } message: {
            if let recovery = appError.recoverySuggestion {
                TextState(recovery)
            } else {
                TextState("An error occurred while communicating with the Rust core.")
            }
        }
    }
    
    static func appError(_ error: AppError) -> Self {
        AlertState {
            TextState(error.errorDescription ?? "Error")
        } actions: {
            ButtonState(action: .dismiss) {
                TextState("OK")
            }
        } message: {
            if let recovery = error.recoverySuggestion {
                TextState(recovery)
            } else {
                TextState("An unexpected error occurred.")
            }
        }
    }
    
    static func genericError(_ error: Error) -> Self {
        AlertState {
            TextState("Error")
        } actions: {
            ButtonState(action: .dismiss) {
                TextState("OK")
            }
        } message: {
            TextState(error.localizedDescription)
        }
    }
}

// MARK: - Confirmation Dialog Helpers

extension ConfirmationDialogState where Action == AppFeature.State.ConfirmationDialog {
    static func stopSession() -> Self {
        ConfirmationDialogState {
            TextState("Stop Session?")
        } actions: {
            ButtonState(role: .destructive, action: .confirmStopSession) {
                TextState("Stop Session")
            }
            ButtonState(role: .cancel, action: .cancel) {
                TextState("Continue Working")
            }
        } message: {
            TextState("Are you sure you want to stop the current session? You'll be prompted to write a reflection.")
        }
    }
    
    static func resetToIdle() -> Self {
        ConfirmationDialogState {
            TextState("Reset App?")
        } actions: {
            ButtonState(role: .destructive, action: .confirmReset) {
                TextState("Reset")
            }
            ButtonState(role: .cancel, action: .cancel) {
                TextState("Cancel")
            }
        } message: {
            TextState("This will clear all session data and return to the preparation screen.")
        }
    }
}