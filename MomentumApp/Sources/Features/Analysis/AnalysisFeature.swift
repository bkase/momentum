import ComposableArchitecture
import Foundation

@Reducer
struct AnalysisFeature {
    @ObservableState
    struct State: Equatable {
        let analysis: AnalysisResult
    }
    
    enum Action: Equatable {
        case resetButtonTapped
        case dismissButtonTapped
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .resetButtonTapped:
                return .none
            case .dismissButtonTapped:
                return .none
            }
        }
    }
}