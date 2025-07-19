import AppKit
import ComposableArchitecture
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let store: StoreOf<AppFeature>
    private var popover: NSPopover?

    init(store: StoreOf<AppFeature>) {
        self.store = store
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Momentum")
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])

            // Accessibility
            button.setAccessibilityTitle("Momentum")
            button.setAccessibilityRole(.button)
            button.setAccessibilityHelp("Focus session tracking")
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            showPopover()
            return
        }

        // Only handle left mouse clicks for now
        if event.type == .leftMouseUp {
            if let popover = popover, popover.isShown {
                popover.performClose(nil)
                self.popover = nil
            } else {
                showPopover()
            }
        }
    }

    func showMenu() {
        showPopover()
    }

    private func showPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false

        // Create the content view with the store
        let contentView = ContentView(store: store)
        let hostingController = NSHostingController(rootView: contentView)
        popover.contentViewController = hostingController

        if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }

        self.popover = popover
    }
}
