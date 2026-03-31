import Foundation
import UIKit

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: UserInfo?
    @Published var accessToken: String?
    @Published var isLoading = false

    private let clientId = "client_01KN0787FG2DSXJ64G8ZMKN0P7"
    private let redirectScheme = "ariaglasses"
    private let redirectURI = "ariaglasses://auth/callback"

    // Backend server for code exchange
    var serverBaseURL: String {
        get { UserDefaults.standard.string(forKey: "serverBaseURL") ?? "https://aria-ai-backend-27308708253a.herokuapp.com" }
        set { UserDefaults.standard.set(newValue, forKey: "serverBaseURL") }
    }

    struct UserInfo: Codable {
        let id: String
        let email: String
        let firstName: String?
        let lastName: String?

        enum CodingKeys: String, CodingKey {
            case id, email
            case firstName = "first_name"
            case lastName = "last_name"
        }
    }

    init() {
        // Restore session from Keychain
        if let token = KeychainHelper.load(key: "access_token"),
           let userData = KeychainHelper.loadData(key: "user_info"),
           let user = try? JSONDecoder().decode(UserInfo.self, from: userData) {
            self.accessToken = token
            self.user = user
            self.isAuthenticated = true
        }
    }

    func signIn() {
        // Build WorkOS authorization URL
        var components = URLComponents(string: "https://api.workos.com/user_management/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "provider", value: "authkit"),
        ]

        guard let authURL = components.url else { return }

        // Open in Safari instead of ASWebAuthenticationSession
        UIApplication.shared.open(authURL)
    }

    /// Called from onOpenURL when the app receives the callback
    func handleCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("[Auth] No authorization code in callback URL")
            return
        }

        isLoading = true
        Task {
            await exchangeCode(code)
            isLoading = false
        }
    }

    private func exchangeCode(_ code: String) async {
        guard let url = URL(string: "\(serverBaseURL)/auth/token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "code": code,
            "redirect_uri": redirectURI,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            if let error = json?["error"] as? String {
                print("[Auth] Token exchange error: \(error)")
                return
            }

            guard let token = json?["access_token"] as? String,
                  let userDict = json?["user"] as? [String: Any] else {
                print("[Auth] Invalid token response")
                return
            }

            let userData = try JSONSerialization.data(withJSONObject: userDict)
            let user = try JSONDecoder().decode(UserInfo.self, from: userData)

            // Persist to Keychain
            KeychainHelper.save(key: "access_token", value: token)
            KeychainHelper.saveData(key: "user_info", data: userData)

            self.accessToken = token
            self.user = user
            self.isAuthenticated = true
        } catch {
            print("[Auth] Token exchange failed: \(error)")
        }
    }

    func signOut() {
        KeychainHelper.delete(key: "access_token")
        KeychainHelper.delete(key: "user_info")
        accessToken = nil
        user = nil
        isAuthenticated = false
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        saveData(key: key, data: data)
    }

    static func saveData(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)

        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        guard let data = loadData(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func loadData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

