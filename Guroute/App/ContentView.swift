import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .onAppear {
                        // Animated splash then transition to main
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                showSplash = false
                            }
                        }
                    }
            } else if appState.showOnboarding {
                OnboardingView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(ThemeManager.Animation.springSmooth, value: showSplash)
    }
}

// MARK: - Splash View
struct SplashView: View {
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringRotation: Double = 0

    var body: some View {
        ZStack {
            // Gradient background
            AppColors.heroMeshGradient
                .ignoresSafeArea()

            VStack(spacing: ThemeManager.Spacing.xl) {
                Spacer()

                // Logo area
                ZStack {
                    // Animated ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    AppColors.primary.opacity(0.5),
                                    AppColors.accent.opacity(0.3),
                                    AppColors.primary.opacity(0.1),
                                    AppColors.primary.opacity(0.5)
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(ringScale)
                        .rotationEffect(.degrees(ringRotation))

                    // Inner glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppColors.primary.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: 100, height: 100)

                    // App icon
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(AppColors.primaryGradient)
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)
                }

                // App name
                VStack(spacing: ThemeManager.Spacing.xs) {
                    Text("GUROUTE")
                        .font(ThemeManager.Typography.displaySmall)
                        .foregroundStyle(AppColors.textPrimary)
                        .tracking(4)

                    Text("splash.tagline".localized)
                        .font(ThemeManager.Typography.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .opacity(textOpacity)

                Spacer()

                // Loading indicator
                VStack(spacing: ThemeManager.Spacing.sm) {
                    ProgressView()
                        .tint(AppColors.primary)
                        .scaleEffect(1.2)

                    Text("splash.loading".localized)
                        .font(ThemeManager.Typography.caption1)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .opacity(textOpacity)
                .padding(.bottom, ThemeManager.Spacing.xxl)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Icon animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }

        // Text fade in
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            textOpacity = 1.0
        }

        // Ring animation
        withAnimation(.easeInOut(duration: 0.8)) {
            ringScale = 1.0
        }

        // Continuous ring rotation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var tabBarVisible = true

    var body: some View {
        TabView(selection: $appState.currentTab) {
            // Explore Tab
            ExploreView()
                .tabItem {
                    Label(AppState.Tab.explore.title, systemImage: AppState.Tab.explore.icon)
                }
                .tag(AppState.Tab.explore)

            // Trips Tab
            TripsListView()
                .tabItem {
                    Label(AppState.Tab.trips.title, systemImage: AppState.Tab.trips.icon)
                }
                .tag(AppState.Tab.trips)

            // Map Tab
            WorldMapView()
                .tabItem {
                    Label(AppState.Tab.map.title, systemImage: AppState.Tab.map.icon)
                }
                .tag(AppState.Tab.map)

            // Passport Tab
            PassportView()
                .tabItem {
                    Label(AppState.Tab.passport.title, systemImage: AppState.Tab.passport.icon)
                }
                .tag(AppState.Tab.passport)

            // Settings Tab
            SettingsView()
                .tabItem {
                    Label(AppState.Tab.settings.title, systemImage: AppState.Tab.settings.icon)
                }
                .tag(AppState.Tab.settings)
        }
        .tint(AppColors.primary)
        .onAppear {
            configureTabBarAppearance()
        }
    }

    private func configureTabBarAppearance() {
        let tabFont = UIFont(name: "SpaceMono-Bold", size: 10) ?? .boldSystemFont(ofSize: 10)

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.surface)

        // Normal state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.textTertiary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textTertiary),
            .font: tabFont
        ]

        // Selected state
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.primary)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.primary),
            .font: tabFont
        ]

        // Add subtle top border
        appearance.shadowColor = UIColor(AppColors.cardBorder)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Navigation Bar Configuration
extension View {
    func configureNavigationBar() -> some View {
        self.onAppear {
            let titleFont = UIFont(name: "SpaceMono-Bold", size: 17) ?? .boldSystemFont(ofSize: 17)
            let largeTitleFont = UIFont(name: "SpaceMono-Bold", size: 34) ?? .boldSystemFont(ofSize: 34)

            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppColors.background)
            appearance.titleTextAttributes = [
                .foregroundColor: UIColor(AppColors.textPrimary),
                .font: titleFont
            ]
            appearance.largeTitleTextAttributes = [
                .foregroundColor: UIColor(AppColors.textPrimary),
                .font: largeTitleFont
            ]

            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().tintColor = UIColor(AppColors.primary)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(ThemeManager())
        .environmentObject(StoreManager())
        .preferredColorScheme(.dark)
}
