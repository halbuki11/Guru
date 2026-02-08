import Foundation
import SwiftUI
import Supabase

/// App configuration manager
/// API keys should be stored securely and not committed to version control
final class AppConfig {
    static let shared = AppConfig()

    // MARK: - Supabase
    var supabaseUrl: String {
        ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
    }

    var supabaseAnonKey: String {
        ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    }

    // MARK: - AI Services
    var claudeApiKey: String {
        ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] ?? Bundle.main.infoDictionary?["CLAUDE_API_KEY"] as? String ?? ""
    }

    var groqApiKey: String {
        ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? Bundle.main.infoDictionary?["GROQ_API_KEY"] as? String ?? ""
    }

    // MARK: - Weather API (weatherapi.com)
    var weatherApiKey: String {
        ProcessInfo.processInfo.environment["WEATHER_API_KEY"] ?? Bundle.main.infoDictionary?["WEATHER_API_KEY"] as? String ?? ""
    }

    // MARK: - Ticketmaster API
    var ticketmasterApiKey: String {
        ProcessInfo.processInfo.environment["TICKETMASTER_API_KEY"] ?? Bundle.main.infoDictionary?["TICKETMASTER_API_KEY"] as? String ?? ""
    }

    // MARK: - Supabase Client
    private(set) var supabaseClient: SupabaseClient!

    private init() {}

    var isConfigured: Bool {
        !supabaseUrl.isEmpty && !supabaseAnonKey.isEmpty
    }

    func initialize() {
        // If not configured, create a dummy client for UI preview
        // The app will show configuration error in AuthView
        if !isConfigured {
            // Create a placeholder client that won't work but won't crash
            supabaseClient = SupabaseClient(
                supabaseURL: URL(string: "https://placeholder.supabase.co")!,
                supabaseKey: "placeholder-key"
            )
            return
        }

        supabaseClient = SupabaseClient(
            supabaseURL: URL(string: supabaseUrl)!,
            supabaseKey: supabaseAnonKey
        )
    }

    // MARK: - App Info
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

// MARK: - Environment Keys
private struct SupabaseClientKey: EnvironmentKey {
    static let defaultValue: SupabaseClient? = nil
}

extension EnvironmentValues {
    var supabaseClient: SupabaseClient? {
        get { self[SupabaseClientKey.self] }
        set { self[SupabaseClientKey.self] = newValue }
    }
}
