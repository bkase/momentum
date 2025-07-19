import ComposableArchitecture
import SwiftUI

@main
struct MomentumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        // Hidden window is necessary for menu bar apps to properly display
        // Settings windows and other UI elements. Without this, the app
        // cannot present new windows when running as .accessory
        WindowGroup("HiddenWindow") {
            HiddenWindowView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)
    }
}

struct HiddenWindowView: View {
    var body: some View {
        EmptyView()
            .frame(width: 0, height: 0)
            .onAppear {
                // Use async to avoid constraint update loops
                DispatchQueue.main.async {
                    if let window = NSApp.windows.first(where: { $0.title == "HiddenWindow" }) {
                        window.isExcludedFromWindowsMenu = true
                        window.collectionBehavior = [.auxiliary, .ignoresCycle, .fullScreenAuxiliary]
                        window.orderOut(nil)
                    }
                }
            }
    }
}
