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
        let replacementItemId: String?
        let startTime: Date
    }
    
    static func handleChecklistSlotToggled(
        state: inout State,
        slotId: Int,
        clock: any Clock<Duration>
    ) -> Effect<Action> {
        guard slotId < state.checklistSlots.count,
              let item = state.checklistSlots[slotId].item else { return .none }
        
        // Toggle the item via Rust CLI
        return .run { send in
            await send(.checklistItemToggled(id: item.id))
        }
    }
    
    static func handleChecklistToggleSuccess(
        state: inout State,
        slotId: Int,
        updatedItems: [ChecklistItem],
        clock: any Clock<Duration>
    ) -> Effect<Action> {
        // Update our local items with the new state
        state.checklistItems = updatedItems
        
        // Update the slot's item to reflect the new state
        if let slotItem = state.checklistSlots[slotId].item,
           let updatedItem = updatedItems.first(where: { $0.id == slotItem.id }) {
            var slots = state.checklistSlots
            slots[slotId].item = updatedItem
            state.checklistSlots = slots
        }
        
        // If the item was just checked, start the transition
        if let slotItem = state.checklistSlots[slotId].item,
           slotItem.on {
            
            // Find next unchecked item
            let uncheckedItems = updatedItems.filter { !$0.on }
            let currentSlotIds = state.checklistSlots.compactMap { $0.item?.id }
            let nextItem = uncheckedItems.first { !currentSlotIds.contains($0.id) }
            
            // Start fade-out transition after delay
            return .run { send in
                try await clock.sleep(for: .milliseconds(600))
                await send(.beginSlotTransition(slotId: slotId, replacementItemId: nextItem?.id))
            }
        }
        
        return .none
    }
    
    static func handleBeginSlotTransition(
        state: inout State,
        slotId: Int,
        replacementItemId: String?,
        clock: any Clock<Duration>
    ) -> Effect<Action> {
        // Mark slot as transitioning
        var slots = state.checklistSlots
        slots[slotId].isTransitioning = true
        state.checklistSlots = slots
        state.activeTransitions[slotId] = ItemTransition(
            slotId: slotId,
            replacementItemId: replacementItemId,
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
        
        // Clear the slot
        var slots = state.checklistSlots
        slots[slotId].item = nil
        slots[slotId].isTransitioning = false
        slots[slotId].isFadingIn = false
        state.checklistSlots = slots
        
        state.activeTransitions.removeValue(forKey: slotId)
        
        // If we have a replacement item, wait a bit then fade it in
        if let replacementId = transition.replacementItemId {
            return .run { send in
                try await clock.sleep(for: .milliseconds(100))
                await send(.fadeInNewItem(slotId: slotId, itemId: replacementId))
            }
        }
        
        return .none
    }
    
    static func handleFadeInNewItem(
        state: inout State,
        slotId: Int,
        itemId: String,
        clock: any Clock<Duration>
    ) -> Effect<Action> {
        // Find the item with this ID
        guard let item = state.checklistItems.first(where: { $0.id == itemId }) else {
            return .none
        }
        
        // Place the new item in the slot with fade-in flag
        var slots = state.checklistSlots
        slots[slotId].item = item
        slots[slotId].isFadingIn = true
        state.checklistSlots = slots
        
        // Reset fade-in after animation completes
        return .run { send in
            try await clock.sleep(for: .milliseconds(350))
            await send(.resetFadeInFlag(slotId: slotId))
        }
    }
}