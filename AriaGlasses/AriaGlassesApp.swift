import SwiftUI
import MWDATCore

@main
struct AriaGlassesApp: App {
    @StateObject private var authManager = AuthManager()

    init() {
        do {
            try Wearables.configure()
        } catch {
            NSLog("[AriaGlasses] Failed to configure Wearables SDK: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                        .environmentObject(authManager)
                    RegistrationView()
                } else {
                    LoginView(authManager: authManager)
                }
            }
            .onOpenURL { url in
                if url.scheme == "ariaglasses" && url.path.contains("callback") {
                    authManager.handleCallback(url: url)
                }
            }
        }
    }
}
