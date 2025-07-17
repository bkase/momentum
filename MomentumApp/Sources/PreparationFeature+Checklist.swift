import ComposableArchitecture
import Foundation

extension PreparationFeature {
    struct ChecklistSlot: Equatable, Identifiable, Codable {
        let id: Int // Position 0-3
        var item: ChecklistItem?
        var isTransitioning: Bool = false
        var isFadingIn: Bool = false
        
        private enum CodingKeys: String, CodingKey {
            case id, item
            // Don't persist animation states
        }
    }
    
    struct ItemTransition: Equatable {
        let slotId: Int
        let replacementText: String?
        let startTime: Date
    }
    
    static func handleChecklistSlotToggled(
        state: inout State,
        slotId: Int,
        clock: any Clock<Duration>
    ) -> Effect<Action> {
        guard slotId < state.checklistSlots.count,
              let item = state.checklistSlots[slotId].item else { return .none }
        
        if !item.isCompleted {
            // Mark item as completed
            var slots = state.checklistSlots
            slots[slotId].item?.isCompleted = true
            state.checklistSlots = slots
            state.totalItemsCompleted += 1
            
            // Check if we have more items to show
            let replacementText: String?
            if state.nextItemIndex < ChecklistItemPool.allItems.count {
                replacementText = ChecklistItemPool.allItems[state.nextItemIndex]
                state.nextItemIndex += 1
            } else {
                replacementText = nil
            }
            
            // Start fade-out transition after 600ms delay
            return .run { send in
                try await clock.sleep(for: .milliseconds(600))
                await send(.beginSlotTransition(slotId: slotId, replacementText: replacementText))
            }
        } else {
            // Unchecking an item (not in spec, but handling for completeness)
            var slots = state.checklistSlots
            slots[slotId].item?.isCompleted = false
            state.checklistSlots = slots
            state.totalItemsCompleted -= 1
        }
        return .none
    }
    
    static func handleBeginSlotTransition(
        state: inout State,
        slotId: Int,
        replacementText: String?,
        clock: any Clock<Duration>
    ) -> Effect<Action> {
        // Mark slot as transitioning
        var slots = state.checklistSlots
        slots[slotId].isTransitioning = true
        state.checklistSlots = slots
        state.activeTransitions[slotId] = ItemTransition(
            slotId: slotId,
            replacementText: replacementText,
            startTime: Date()
        )
        
        // Complete transition after fade-out duration (300ms)
        return .run { send in
            try await clock.sleep(for: .milliseconds(300))
            await send(.completeSlotTransition(slotId: slotId))
        }
    }
    
    static func handleCompleteSlotTransition(
        state: inout State,
        slotId: Int,
        clock: any Clock<Duration>
    ) -> Effect<Action> {
        guard let transition = state.activeTransitions[slotId] else { return .none }
        
        // First, clear the slot completely to prevent overlap
        var slots = state.checklistSlots
        slots[slotId].item = nil
        slots[slotId].isTransitioning = false
        slots[slotId].isFadingIn = false
        state.checklistSlots = slots
        
        state.activeTransitions.removeValue(forKey: slotId)
        
        // If there's a replacement, add it after a small gap
        if let replacementText = transition.replacementText {
            return .run { send in
                // Small delay to ensure clean visual gap
                try await clock.sleep(for: .milliseconds(100))
                await send(.fadeInNewItem(slotId: slotId, text: replacementText))
            }
        }
        return .none
    }
    
    static func handleFadeInNewItem(
        state: inout State,
        slotId: Int,
        text: String,
        clock: any Clock<Duration>
    ) -> Effect<Action> {
        // Add the new item to the slot with fade-in animation
        let newId = UUID().uuidString
        let newItem = ChecklistItem(id: newId, text: text, isCompleted: false)
        var slots = state.checklistSlots
        slots[slotId].item = newItem
        slots[slotId].isFadingIn = true
        state.checklistSlots = slots
        
        // Reset the fade-in flag after animation duration
        return .run { send in
            try await clock.sleep(for: .milliseconds(350)) // Slightly longer than animation
            await send(.resetFadeInFlag(slotId: slotId))
        }
    }
}