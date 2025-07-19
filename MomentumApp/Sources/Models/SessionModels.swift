import ComposableArchitecture
import Foundation
import IdentifiedCollections

// MARK: - Preparation State

struct PreparationState: Equatable {
    var goal: String = ""
    var timeInput: String = ""
    var checklist: IdentifiedArrayOf<ChecklistItem> = []

    var isStartButtonEnabled: Bool {
        !goal.isEmpty && Int(timeInput).map { $0 > 0 } == true && checklist.allSatisfy { $0.on }
    }
}
