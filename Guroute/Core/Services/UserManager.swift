import Foundation
import Security
import AuthenticationServices
import Supabase

/// Centralized user management with Apple Sign-In
/// Apple user identifier is stored in Keychain - consistent across all devices with same Apple ID
@MainActor
class UserManager: NSObject, ObservableObject {
    static let shared = UserManager()

    @Published private(set) var userId: String?
    @Published private(set) var userEmail: String?
    @Published private(set) var userName: String?
    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var isLoading: Bool = true
    @Published var lastError: String?

    private let keychainUserIdKey = "com.guroute.appleUserId"
    private let keychainEmailKey = "com.guroute.appleEmail"
    private let keychainNameKey = "com.guroute.appleName"

    private var signInContinuation: CheckedContinuation<Bool, Never>?

    private override init() {
        super.init()
        Task {
            await checkExistingCredential()
        }
    }

    // MARK: - Check Existing Credential

    /// Check if user has previously signed in with Apple
    func checkExistingCredential() async {
        isLoading = true
        defer { isLoading = false }

        // First check if we have stored user ID
        guard let storedUserId = Self.getFromKeychain(key: keychainUserIdKey) else {
            isSignedIn = false
            return
        }

        // Verify the credential is still valid with Apple
        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: storedUserId)
            switch state {
            case .authorized:
                // Credential is valid
                self.userId = storedUserId
                self.userEmail = Self.getFromKeychain(key: keychainEmailKey)
                self.userName = Self.getFromKeychain(key: keychainNameKey)
                self.isSignedIn = true

                // Also update UserDefaults for backward compatibility
                UserDefaults.standard.set(storedUserId, forKey: "localUserId")

                // Sync profile to Supabase (ensure profile exists)
                await syncProfileToSupabase(
                    userId: storedUserId,
                    email: self.userEmail,
                    fullName: self.userName
                )

            case .revoked, .notFound:
                // Credential is no longer valid, clear stored data
                clearStoredCredentials()
                isSignedIn = false

            case .transferred:
                // Handle transferred state if needed
                isSignedIn = false

            @unknown default:
                isSignedIn = false
            }
        } catch {
            // If we can't verify, still use stored ID (offline case)
            self.userId = storedUserId
            self.isSignedIn = true
        }
    }

    // MARK: - Sign In with Apple

    /// Trigger Apple Sign-In flow
    func signInWithApple() async -> Bool {
        // Prevent multiple concurrent sign-in attempts
        if signInContinuation != nil {
            return false
        }

        lastError = nil

        return await withCheckedContinuation { continuation in
            self.signInContinuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Process Apple Sign-In (from SwiftUI SignInWithAppleButton)

    func processAppleSignIn(userIdentifier: String, email: String?, fullName: String?) async {
        // Save to Keychain
        Self.saveToKeychain(key: keychainUserIdKey, value: userIdentifier)

        if let email = email {
            Self.saveToKeychain(key: keychainEmailKey, value: email)
            self.userEmail = email
        }

        if let name = fullName {
            Self.saveToKeychain(key: keychainNameKey, value: name)
            self.userName = name
            // Also save to UserDefaults for display
            UserDefaults.standard.set(name, forKey: "userName")
        }

        // Update state
        self.userId = userIdentifier
        self.isSignedIn = true

        // Save to UserDefaults for backward compatibility
        UserDefaults.standard.set(userIdentifier, forKey: "localUserId")
    }

    // MARK: - Display Properties

    /// Display name: userName > userEmail prefix > "Gezgin"
    var displayName: String {
        if let name = userName, !name.isEmpty {
            return name
        }
        if let email = userEmail, !email.isEmpty {
            return String(email.split(separator: "@").first ?? "Gezgin")
        }
        return "Gezgin"
    }

    /// Initials for avatar: first letters of name parts, or first letter of email
    var displayInitials: String {
        if let name = userName, !name.isEmpty {
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
            }
            return String(name.prefix(1)).uppercased()
        }
        if let email = userEmail, !email.isEmpty {
            return String(email.prefix(1)).uppercased()
        }
        return "G"
    }

    // MARK: - Update Profile

    func updateName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        self.userName = trimmed
        Self.saveToKeychain(key: keychainNameKey, value: trimmed)
        UserDefaults.standard.set(trimmed, forKey: "userName")

        // Sync to Supabase
        if let uid = userId {
            Task {
                try? await SupabaseService.shared.updateProfile(
                    userId: uid,
                    updates: ["display_name": .string(trimmed)]
                )
            }
        }
    }

    func updateEmail(_ email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        self.userEmail = trimmed
        Self.saveToKeychain(key: keychainEmailKey, value: trimmed)

        // Sync to Supabase
        if let uid = userId {
            Task {
                try? await SupabaseService.shared.updateProfile(
                    userId: uid,
                    updates: ["email": .string(trimmed)]
                )
            }
        }
    }

    // MARK: - Supabase Sync

    /// Profil ve kredileri Supabase'e senkronize et
    private func syncProfileToSupabase(userId: String, email: String?, fullName: String?) async {
        do {
            // Profil oluştur/güncelle
            try await SupabaseService.shared.upsertProfile(
                userId: userId,
                email: email,
                fullName: fullName
            )

            // Kredi başlat (yoksa)
            try await SupabaseService.shared.initializeUserCredits(userId: userId)

            // Referans kodu oluştur (yoksa)
            let existingCode = try? await SupabaseService.shared.fetchReferralCode(userId: userId)
            if existingCode == nil {
                let code = "GR-" + String(UUID().uuidString.prefix(6)).uppercased()
                let codeData: [String: AnyJSON] = [
                    "user_id": .string(userId),
                    "code": .string(code),
                    "total_referrals": .integer(0),
                    "total_credits_earned": .integer(0),
                    "is_active": .bool(true)
                ]
                try await SupabaseService.shared.insertReferralCode(codeData)
            }

            // Premium durumunu kontrol et — userId artık hazır
            await StoreManager.shared.checkSupabasePremium()
        } catch {
            // Silent
        }
    }

    // MARK: - Sign Out

    func signOut() {
        clearStoredCredentials()
        userId = nil
        userEmail = nil
        userName = nil
        isSignedIn = false

        // Kredi ve premium verilerini temizle
        CreditManager.shared.reset()
        StoreManager.shared.resetPremiumState()
    }

    // MARK: - Keychain Operations

    private func clearStoredCredentials() {
        // Clear Keychain
        Self.deleteFromKeychain(key: keychainUserIdKey)
        Self.deleteFromKeychain(key: keychainEmailKey)
        Self.deleteFromKeychain(key: keychainNameKey)

        // Clear all user-specific data from UserDefaults
        // NOT: hasCompletedOnboarding burada temizlenmez
        // Çıkış yapan kullanıcı tekrar girdiğinde onboarding'i görmemeli
        let userDataKeys = [
            "localUserId",
            "userName",
            "userBio",
            "userAvatarData",
            "visitedRegions",
            "visitedCities",
            "countriesVisited",
            "citiesVisited",
            "tripsCount",
        ]
        for key in userDataKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private static func saveToKeychain(key: String, value: String) {
        guard let data = value.data(using: .utf8) else {
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            // Keychain save failed
        }
    }

    static func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private static func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension UserManager: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Task { @MainActor in
                self.lastError = "Could not get Apple ID credential"
                signInContinuation?.resume(returning: false)
                signInContinuation = nil
            }
            return
        }

        let userIdentifier = appleIDCredential.user
        let email = appleIDCredential.email
        let fullName = appleIDCredential.fullName

        // Build full name string
        var nameString: String? = nil
        if let givenName = fullName?.givenName {
            nameString = givenName
            if let familyName = fullName?.familyName {
                nameString = "\(givenName) \(familyName)"
            }
        }

        Task { @MainActor in
            // Save to Keychain
            Self.saveToKeychain(key: keychainUserIdKey, value: userIdentifier)

            if let email = email {
                Self.saveToKeychain(key: keychainEmailKey, value: email)
                self.userEmail = email
            }

            if let name = nameString {
                Self.saveToKeychain(key: keychainNameKey, value: name)
                self.userName = name
                // Also save to UserDefaults for display
                UserDefaults.standard.set(name, forKey: "userName")
            }

            // Update state
            self.userId = userIdentifier
            self.isSignedIn = true

            // Save to UserDefaults for backward compatibility
            UserDefaults.standard.set(userIdentifier, forKey: "localUserId")

            // Sync profile to Supabase
            await syncProfileToSupabase(
                userId: userIdentifier,
                email: email,
                fullName: nameString
            )

            signInContinuation?.resume(returning: true)
            signInContinuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            self.lastError = error.localizedDescription
            signInContinuation?.resume(returning: false)
            signInContinuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension UserManager: ASAuthorizationControllerPresentationContextProviding {

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Find the key window safely
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            return window
        }

        // Fallback: try to get any window
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first {
            return window
        }

        // Last resort - this shouldn't happen but better than crash
        return UIWindow()
    }
}
