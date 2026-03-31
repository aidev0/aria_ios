import SwiftUI

struct LoginView: View {
    @ObservedObject var authManager: AuthManager
    @State private var serverURL: String = UserDefaults.standard.string(forKey: "serverBaseURL") ?? "https://aria-ai-backend-27308708253a.herokuapp.com"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Logo
                ZStack {
                    Image("aria_logo_body")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white)
                    Image("aria_logo_dot")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white)
                }
                .frame(height: 80)

                Text("aria glasses")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                    .tracking(3)

                Spacer()

                // Sign in button
                Button {
                    authManager.signIn()
                } label: {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(12)
                    } else {
                        Text("sign in")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                }
                .disabled(authManager.isLoading)
                .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 60)
            }
        }
        .preferredColorScheme(.dark)
    }
}
