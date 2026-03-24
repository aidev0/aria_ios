import SwiftUI
import MWDATCore

struct RegistrationView: View {
    var onError: ((String) -> Void)?

    var body: some View {
        EmptyView()
            .onOpenURL { url in
                print("[RegistrationView] Received URL: \(url)")

                guard
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                    components.queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true
                else {
                    print("[RegistrationView] URL ignored - not a metaWearablesAction")
                    return
                }

                print("[RegistrationView] Processing Meta Wearables callback")
                Task {
                    do {
                        _ = try await Wearables.shared.handleUrl(url)
                        print("[RegistrationView] handleUrl completed successfully")
                    } catch {
                        print("[RegistrationView] Registration error: \(error)")
                        onError?(error.localizedDescription)
                    }
                }
            }
    }
}
