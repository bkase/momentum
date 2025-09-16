import AppKit
import ComposableArchitecture
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }
    private var notificationObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize status bar controller
        statusBarController = StatusBarController(store: store)

        // Hide dock icon (menu bar app)
        NSApp.setActivationPolicy(.accessory)

        registerMenuBarObservers()

        #if DEBUG
            // Start test server
            store.send(.startTestServer)

            // Register state provider for test server
            TestStateCapture.shared.setStateProvider { [weak store] in
                guard let store = store else { return "{}" }
                let state = store.withState { $0 }
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted

                // Create a simplified state representation
                let debugState: [String: Any] = [
                    "hasSession": state.sessionData != nil,
                    "sessionGoal": state.sessionData?.goal ?? "",
                    "reflectionPath": state.reflectionPath ?? "",
                    "analysisCount": state.analysisHistory.count,
                    "isLoading": state.isLoading,
                    "destination": destinationString(state.destination),
                ]

                if let data = try? JSONSerialization.data(withJSONObject: debugState),
                    let json = String(data: data, encoding: .utf8)
                {
                    return json
                }
                return "{}"
            }

            // Listen for test server notifications
            let center = NotificationCenter.default
            notificationObservers.append(
                center.addObserver(
                    forName: .testServerShowMenu,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        self?.statusBarController?.showMenu()
                    }
                }
            )

            notificationObservers.append(
                center.addObserver(
                    forName: .testServerRefreshState,
                    object: nil,
                    queue: .main
                ) { [weak store] _ in
                    Task { @MainActor in
                        store?.send(.testServerRefreshState)
                    }
                }
            )
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        let center = NotificationCenter.default
        notificationObservers.forEach { center.removeObserver($0) }
        notificationObservers.removeAll()
    }

    private func registerMenuBarObservers() {
        guard let statusBarController else { return }
        let center = NotificationCenter.default

        notificationObservers.append(
            center.addObserver(
                forName: .menuBarSetNormalIcon,
                object: nil,
                queue: .main
            ) { [weak statusBarController] _ in
                Task { @MainActor in
                    statusBarController?.setNormalIcon()
                }
            }
        )

        notificationObservers.append(
            center.addObserver(
                forName: .menuBarSetApproachIcon,
                object: nil,
                queue: .main
            ) { [weak statusBarController] _ in
                Task { @MainActor in
                    statusBarController?.setApproachIcon()
                }
            }
        )

        notificationObservers.append(
            center.addObserver(
                forName: .menuBarSetTimeoutIcon,
                object: nil,
                queue: .main
            ) { [weak statusBarController] _ in
                Task { @MainActor in
                    statusBarController?.setTimeoutIcon()
                }
            }
        )

        notificationObservers.append(
            center.addObserver(
                forName: .showApproachMicroPopover,
                object: nil,
                queue: .main
            ) { [weak statusBarController] _ in
                Task { @MainActor in
                    statusBarController?.showMini(text: "5 minutes remaining")
                }
            }
        )

        notificationObservers.append(
            center.addObserver(
                forName: .showTimeoutMicroPopover,
                object: nil,
                queue: .main
            ) { [weak statusBarController] _ in
                Task { @MainActor in
                    statusBarController?.showMini(text: "Time is up")
                }
            }
        )
    }
}

#if DEBUG
    private func destinationString(_ destination: AppFeature.Destination.State?) -> String {
        guard let destination = destination else { return "none" }
        switch destination {
        case .preparation: return "preparation"
        case .activeSession: return "activeSession"
        case .reflection: return "reflection"
        case .analysis: return "analysis"
        }
    }
#endif
