import ComposableArchitecture
import Foundation
import Testing
@testable import MomentumApp

@MainActor
struct ReflectionFeatureTests {
    @Test
    func analyzeReflection_Success() async {
        let store = TestStore(
            initialState: ReflectionFeature.State(
                reflectionPath: "/test/reflection.md"
            )
        ) {
            ReflectionFeature()
        } withDependencies: {
            $0.rustCoreClient.analyze = { _ in
                AnalysisResult(
                    summary: "Test summary",
                    suggestion: "Test suggestion",
                    reasoning: "Test reasoning"
                )
            }
        }
        
        await store.send(.analyzeButtonTapped)
        await store.receive(.delegate(.analysisRequested(analysisResult: AnalysisResult(
            summary: "Test summary",
            suggestion: "Test suggestion",
            reasoning: "Test reasoning"
        ))))
    }
    
    @Test
    func analyzeReflection_Failure() async {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test error" }
        }
        
        let store = TestStore(
            initialState: ReflectionFeature.State(
                reflectionPath: "/test/reflection.md"
            )
        ) {
            ReflectionFeature()
        } withDependencies: {
            $0.rustCoreClient.analyze = { _ in
                throw TestError()
            }
        }
        
        await store.send(.analyzeButtonTapped)
        await store.receive(.delegate(.analysisFailedToStart(.other("Test error"))))
    }
    
    @Test
    func cancelReflection() async {
        let store = TestStore(
            initialState: ReflectionFeature.State(
                reflectionPath: "/test/reflection.md"
            )
        ) {
            ReflectionFeature()
        }
        
        await store.send(.cancelButtonTapped)
    }
}