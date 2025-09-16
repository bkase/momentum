import AppKit
import ComposableArchitecture
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let store: StoreOf<AppFeature>
    private var popover: NSPopover?
    private var miniPopover: NSPopover?
    private var miniDismissWorkItem: DispatchWorkItem?

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
        closeMiniPopover()
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

    func setNormalIcon() {
        statusItem?.button?.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Momentum")
        closeMiniPopover()
    }

    func setApproachIcon() {
        let image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "Approaching end")
            ?? NSImage(systemSymbolName: "timer", accessibilityDescription: "Approaching end")
        statusItem?.button?.image = image
    }

    func setTimeoutIcon() {
        let image = NSImage(systemSymbolName: "hourglass.bottomhalf.filled", accessibilityDescription: "Session complete")
            ?? NSImage(systemSymbolName: "hourglass", accessibilityDescription: "Session complete")
        statusItem?.button?.image = image
    }

    func showMini(text: String) {
        guard (popover?.isShown ?? false) == false else { return }

        miniDismissWorkItem?.cancel()
        closeMiniPopover()

        let miniPopover = NSPopover()
        miniPopover.behavior = .transient
        miniPopover.animates = false
        miniPopover.contentViewController = NSHostingController(
            rootView: MiniPopoverView(message: text)
        )

        if let button = statusItem?.button {
            miniPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }

        self.miniPopover = miniPopover

        let workItem = DispatchWorkItem { [weak self] in
            self?.closeMiniPopover()
        }
        miniDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 7, execute: workItem)
    }

    private func closeMiniPopover() {
        miniDismissWorkItem?.cancel()
        miniDismissWorkItem = nil
        if let miniPopover, miniPopover.isShown {
            miniPopover.performClose(nil)
        }
        miniPopover = nil
    }
}

private struct MiniPopoverView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message)
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minWidth: 220, maxWidth: 260, alignment: .leading)
    }
}
