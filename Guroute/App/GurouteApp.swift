import SwiftUI
import StoreKit
import Nuke

@main
struct GurouteApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var storeManager = StoreManager()
    @StateObject private var creditManager = CreditManager.shared

    init() {
        // Initialize AppConfig (Supabase client, API keys, etc.)
        AppConfig.shared.initialize()

        // Configure Nuke image pipeline (cache, progressive loading, prefetch)
        ImagePipelineConfigurator.configure()

        // Configure appearance
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environmentObject(storeManager)
                .environmentObject(creditManager)
                .preferredColorScheme(.dark)
                .tint(AppColors.primary)
        }
    }

    private func configureAppearance() {
        // Space Mono fonts for UIKit elements
        let titleFont = UIFont(name: "SpaceMono-Bold", size: 17) ?? .boldSystemFont(ofSize: 17)
        let largeTitleFont = UIFont(name: "SpaceMono-Bold", size: 34) ?? .boldSystemFont(ofSize: 34)
        let tabItemFont = UIFont(name: "SpaceMono-Bold", size: 10) ?? .boldSystemFont(ofSize: 10)
        let barButtonFont = UIFont(name: "SpaceMono-Bold", size: 15) ?? .boldSystemFont(ofSize: 15)

        // Navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(AppColors.background)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textPrimary),
            .font: titleFont
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textPrimary),
            .font: largeTitleFont
        ]
        navAppearance.buttonAppearance.normal.titleTextAttributes = [.font: barButtonFont]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        // Tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(AppColors.surface)

        // Apply Space Mono to all tab bar item states
        let tabItemAppearance = UITabBarItemAppearance()
        tabItemAppearance.normal.titleTextAttributes = [
            .font: tabItemFont,
            .foregroundColor: UIColor(AppColors.textTertiary)
        ]
        tabItemAppearance.selected.titleTextAttributes = [
            .font: tabItemFont,
            .foregroundColor: UIColor(AppColors.primary)
        ]
        tabAppearance.stackedLayoutAppearance = tabItemAppearance
        tabAppearance.inlineLayoutAppearance = tabItemAppearance
        tabAppearance.compactInlineLayoutAppearance = tabItemAppearance

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var isLoading = false
    @Published var currentTab: Tab = .explore
    @Published var showOnboarding: Bool
    @Published var locale: AppLocale

    init() {
        // Load saved language preference
        let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage") ?? "tr"
        self.locale = AppLocale(rawValue: savedLanguage) ?? .turkish

        // Yeni kullanıcılar için onboarding göster
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.showOnboarding = !hasCompleted
    }

    enum Tab: String, CaseIterable {
        case explore = "explore"
        case trips = "trips"
        case map = "map"
        case passport = "passport"
        case settings = "settings"

        var title: String {
            switch self {
            case .explore: return "tab.explore".localized
            case .trips: return "tab.trips".localized
            case .map: return "tab.map".localized
            case .passport: return "tab.passport".localized
            case .settings: return "tab.settings".localized
            }
        }

        var icon: String {
            switch self {
            case .explore: return "globe.europe.africa"
            case .trips: return "airplane"
            case .map: return "map"
            case .passport: return "book.closed"
            case .settings: return "gearshape"
            }
        }
    }
}

// MARK: - Locale
enum AppLocale: String, CaseIterable {
    case turkish = "tr"
    case english = "en"

    var displayName: String {
        switch self {
        case .turkish: return "Türkçe"
        case .english: return "English"
        }
    }
}
