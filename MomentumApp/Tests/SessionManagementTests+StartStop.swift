import ComposableArchitecture
import Foundation
import Testing

@testable import MomentumApp

extension SessionManagementTests {
    @Test("Start Session Success via Delegate")
    func startSessionSuccessViaDelegate() async {
        // Set up shared state before creating the store
        @Shared(.lastGoal) var lastGoal: String
        @Shared(.lastTimeMinutes) var lastTimeMinutes: String
        $lastGoal.withLock { $0 = "Test Goal" }
        $lastTimeMinutes.withLock { $0 = "30" }

        let store = TestStore(
            initialState: AppFeature.State()
        ) {
            AppFeature()
        } withDependencies: {
            $0.rustCoreClient.checkList = {
                ChecklistState(
                    items: (0..<10).map { i in
                        ChecklistItem(id: String(i), text: "Item \(i)", on: true)
                    })
            }
        }
        store.exhaustivity = .off

        // Destination already set by init, onAppear should not change anything
        await store.send(.onAppear)

        // Load checklist - this will trigger the Rust CLI
        await store.send(.destination(.presented(.preparation(.onAppear))))
        await store.send(.destination(.presented(.preparation(.loadChecklist))))

        // Simulate checklist loaded with all items checked
        let checklistState = ChecklistState(
            items: (0..<10).map { i in
                ChecklistItem(id: String(i), text: "Item \(i)", on: true)
            })
        await store.send(.destination(.presented(.preparation(.checklistResponse(.success(checklistState))))))

        // Start session through delegate action from PreparationFeature
        let sessionData = SessionData.mock(
            goal: "Test Goal",
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            timeExpected: 30  // 30 minutes
        )

        // Send delegate action from PreparationFeature
        await store.send(.destination(.presented(.preparation(.delegate(.sessionStarted(sessionData)))))) {
            $0.isLoading = false
            // Don't manually update shared state - the reducer handles it
            $0.reflectionPath = nil
            $0.destination = .activeSession(
                ActiveSessionFeature.State(
                    goal: "Test Goal",
                    startTime: Date(timeIntervalSince1970: 1_700_000_000),
                    expectedMinutes: 30
                ))
        }
    }

    @Test("Start Session Error via Delegate")
    func startSessionErrorViaDelegate() async {
        let store = TestStore(
            initialState: AppFeature.State()
        ) {
            AppFeature()
        }
        store.exhaustivity = .off

        // Send error delegate action from PreparationFeature
        let error = AppError.rustCore(.binaryNotFound)
        await store.send(.destination(.presented(.preparation(.delegate(.sessionFailedToStart(error)))))) {
            $0.isLoading = false
            // Error handled in PreparationFeature
        }
    }

    @Test("Stop Session")
    func stopSession() async {
        let startTime = Date(timeIntervalSince1970: 1_700_000_000)
        let sessionData = SessionData.mock(
            goal: "Test Goal",
            startTime: startTime,
            timeExpected: 30  // 30 minutes
        )

        // Set up shared state before creating the store
        @Shared(.sessionData) var sharedSessionData: SessionData?
        $sharedSessionData.withLock { $0 = sessionData }

        let store = TestStore(
            initialState: AppFeature.State()
        ) {
            AppFeature()
        } withDependencies: {
            $0.rustCoreClient.stop = {
                "/tmp/test-reflection.md"
            }
        }
        store.exhaustivity = .off

        // Destination already set by init, onAppear should not change anything
        await store.send(.onAppear)

        // Stop session immediately
        await store.send(.destination(.presented(.activeSession(.stopButtonTapped)))) {
            $0.isLoading = true
        }

        // Forward the performStop action to ActiveSessionFeature
        await store.receive(.destination(.presented(.activeSession(.performStop))))

        // Receive delegate response from ActiveSessionFeature
        await store
            .receive(
                .destination(
                    .presented(
                        .activeSession(.delegate(.sessionStopped(reflectionPath: "/tmp/test-reflection.md")))
                    ))
            ) {
                $0.isLoading = false
                // Don't manually update shared state - the reducer handles it
                $0.reflectionPath = "/tmp/test-reflection.md"
                $0.destination = .reflection(ReflectionFeature.State(reflectionPath: "/tmp/test-reflection.md"))
            }
    }
}
