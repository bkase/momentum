import SwiftUI
import ComposableArchitecture

// Helper to create states with specific checklist configurations for previews
extension PreparationFeature.State {
    static func preview(
        goal: String = "",
        timeInput: String = "",
        checklistItems: [(id: String, text: String, on: Bool)] = []
    ) -> Self {
        var state = Self(goal: goal, timeInput: timeInput)
        state.checklistItems = checklistItems.map { ChecklistItem(id: $0.id, text: $0.text, on: $0.on) }
        return state
    }
}

#Preview("Empty State") {
    PreparationView(
        store: Store(initialState: PreparationFeature.State()) {
            PreparationFeature()
        }
    )
    .frame(width: 400, height: 500)
}

#Preview("With Goal") {
    PreparationView(
        store: Store(
            initialState: PreparationFeature.State(
                goal: "Write a comprehensive report on Q4 performance",
                timeInput: ""
            )
        ) {
            PreparationFeature()
        }
    )
    .frame(width: 400, height: 500)
}

#Preview("With Goal and Time") {
    PreparationView(
        store: Store(
            initialState: PreparationFeature.State(
                goal: "Write a comprehensive report on Q4 performance",
                timeInput: "45"
            )
        ) {
            PreparationFeature()
        }
    )
    .frame(width: 400, height: 500)
}

#Preview("With Checklist - Incomplete") {
    PreparationView(
        store: Store(
            initialState: PreparationFeature.State.preview(
                goal: "Write a comprehensive report on Q4 performance",
                timeInput: "45",
                checklistItems: [
                    ("check-rested", "Rested", false),
                    ("check-hungry", "Not hungry", false),
                    ("check-bathroom", "Bathroom break", false),
                    ("check-phone", "Phone on silent", false)
                ]
            )
        ) {
            PreparationFeature()
        }
    )
    .frame(width: 400, height: 500)
}

#Preview("With Checklist - Partially Complete") {
    PreparationView(
        store: Store(
            initialState: PreparationFeature.State.preview(
                goal: "Write a comprehensive report on Q4 performance",
                timeInput: "45",
                checklistItems: [
                    ("check-rested", "Rested", true),
                    ("check-hungry", "Not hungry", true),
                    ("check-bathroom", "Bathroom break", false),
                    ("check-phone", "Phone on silent", false)
                ]
            )
        ) {
            PreparationFeature()
        }
    )
    .frame(width: 400, height: 500)
}

#Preview("Ready to Start") {
    PreparationView(
        store: Store(
            initialState: PreparationFeature.State.preview(
                goal: "Write a comprehensive report on Q4 performance",
                timeInput: "45",
                checklistItems: [
                    ("check-rested", "Rested", true),
                    ("check-hungry", "Not hungry", true),
                    ("check-distractions", "Distractions closed", true),
                    ("check-mind", "Mind centered", true),
                    ("check-water", "Water bottle filled", true),
                    ("check-playlist", "Choose a good playlist", true),
                    ("check-disturb", "Tell anyone not to disturb", true),
                    ("check-materials", "Materials in place", true),
                    ("check-time", "Enough time set aside", true)
                ]
            )
        ) {
            PreparationFeature()
        }
    )
    .frame(width: 400, height: 500)
}

#Preview("Invalid Time Input") {
    PreparationView(
        store: Store(
            initialState: PreparationFeature.State.preview(
                goal: "Write a comprehensive report on Q4 performance",
                timeInput: "0",
                checklistItems: [
                    ("check-rested", "Rested", true),
                    ("check-hungry", "Not hungry", true),
                    ("check-bathroom", "Bathroom break", true),
                    ("check-phone", "Phone on silent", true),
                    ("check-water", "Water bottle filled", true),
                    ("check-playlist", "Choose a good playlist", true),
                    ("check-disturb", "Tell anyone not to disturb", true),
                    ("check-materials", "Materials in place", true),
                    ("check-time", "Enough time set aside", true)
                ]
            )
        ) {
            PreparationFeature()
        }
    )
    .frame(width: 400, height: 500)
}