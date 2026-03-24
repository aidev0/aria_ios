import SwiftUI
import MWDATCore

@main
struct AriaGlassesApp: App {
    init() {
        do {
            try Wearables.configure()
        } catch {
            NSLog("[AriaGlasses] Failed to configure Wearables SDK: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
            RegistrationView()
        }
    }
}
