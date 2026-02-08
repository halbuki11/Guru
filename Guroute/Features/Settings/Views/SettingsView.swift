import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var storeManager: StoreManager
    @StateObject private var userManager = UserManager.shared
    @StateObject private var creditManager = CreditManager.shared
    @State private var showPremiumSheet = false
    @State private var showCreditStore = false
    @State private var showSignOutAlert = false
    @State private var showSignInError = false
    @State private var signInErrorMessage = ""
    @State private var isSigningIn = false
    @State private var showEditProfile = false

    var body: some View {
        NavigationStack {
            List {
                // Account section
                accountSection

                // Profile stats (only when signed in)
                if userManager.isSignedIn {
                    profileStatsSection
                }

                // Premium section
                premiumSection

                // Preferences section
                preferencesSection

                // About section
                aboutSection

                // Support section
                supportSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("settings.title".localized)
            .sheet(isPresented: $showPremiumSheet) {
                PremiumPaywallView()
            }
            .sheet(isPresented: $showCreditStore) {
                CreditStoreView()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .onAppear {
                // Her SettingsView açıldığında güncel verileri çek
                if userManager.isSignedIn, let userId = userManager.userId {
                    Task {
                        // Premium durumunu kontrol et
                        await storeManager.checkSupabasePremium()
                        // Kredi bakiyesini yükle
                        await creditManager.loadCredits(userId: userId)
                    }
                }
            }
            .confirmationDialog(
                "account.signOutConfirm".localized,
                isPresented: $showSignOutAlert,
                titleVisibility: .visible
            ) {
                Button("account.signOut".localized, role: .destructive) {
                    userManager.signOut()
                }
                Button("common.cancel".localized, role: .cancel) { }
            } message: {
                Text("account.signOutMessage".localized)
            }
            .alert("common.error".localized, isPresented: $showSignInError) {
                Button("common.close".localized) { }
            } message: {
                Text(signInErrorMessage)
            }
        }
    }

    // MARK: - Account Section
    private var accountSection: some View {
        Section {
            if userManager.isSignedIn {
                // User is signed in - show profile card
                Button {
                    showEditProfile = true
                } label: {
                    HStack(spacing: ThemeManager.Spacing.md) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.primary, AppColors.primary.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 56, height: 56)

                            if let avatarData = UserDefaults.standard.data(forKey: "userAvatarData"),
                               let uiImage = UIImage(data: avatarData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(Circle())
                            } else {
                                Text(userManager.displayInitials)
                                    .font(.custom("SpaceMono-Bold", size: 20))
                                    .foregroundStyle(.white)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(userManager.displayName)
                                    .font(ThemeManager.Typography.headline)
                                    .foregroundStyle(AppColors.textPrimary)

                                // Premium badge
                                if storeManager.isPremium {
                                    HStack(spacing: 3) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 8))
                                        Text("PRO")
                                            .font(.custom("SpaceMono-Bold", size: 9))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        LinearGradient(
                                            colors: [AppColors.primary, AppColors.primary.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(4)
                                }
                            }

                            if let email = userManager.userEmail {
                                Text(email)
                                    .font(ThemeManager.Typography.caption1)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .lineLimit(1)
                            }

                            // Member since
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppColors.success)
                                Text("profile.verified".localized)
                                    .font(ThemeManager.Typography.caption2)
                                    .foregroundStyle(AppColors.success)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppColors.textTertiary)
                            .font(.system(size: 14))
                    }
                }

                // Sign out button
                Button {
                    showSignOutAlert = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.forward")
                            .foregroundStyle(AppColors.error)
                            .frame(width: 24)

                        Text("account.signOut".localized)
                            .font(ThemeManager.Typography.body)
                            .foregroundStyle(AppColors.error)
                    }
                }
            } else {
                // User is not signed in - show sign in button
                VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 40))
                            .foregroundStyle(AppColors.textTertiary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("signIn.welcomeTo".localized + " Guroute")
                                .font(ThemeManager.Typography.headline)
                                .foregroundStyle(AppColors.textPrimary)

                            Text("signIn.subtitle".localized)
                                .font(ThemeManager.Typography.caption1)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(2)
                        }
                    }

                    // Apple Sign In Button (Custom for localization)
                    Button {
                        guard !isSigningIn else { return }
                        isSigningIn = true
                        Task {
                            let success = await userManager.signInWithApple()
                            isSigningIn = false
                            if !success && userManager.lastError != nil {
                                signInErrorMessage = userManager.lastError ?? "signIn.failed".localized
                                showSignInError = true
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isSigningIn {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 16))
                            }
                            Text(isSigningIn ? "signIn.signingIn".localized : "signIn.appleButton".localized)
                                .font(.custom("SpaceMono-Bold", size: 17))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(isSigningIn ? Color.gray : Color.black)
                        .cornerRadius(8)
                    }
                    .disabled(isSigningIn)
                }
                .padding(.vertical, ThemeManager.Spacing.xs)
            }
        } header: {
            Text("account.title".localized)
        }
        .listRowBackground(AppColors.surface)
    }

    // MARK: - Profile Stats Section
    private var profileStatsSection: some View {
        Section {
            HStack(spacing: 0) {
                // Countries visited
                profileStatItem(
                    value: "\(UserDefaults.standard.integer(forKey: "countriesVisited"))",
                    label: "profile.countries".localized,
                    icon: "flag.fill"
                )

                Divider()
                    .frame(height: 40)

                // Cities visited
                profileStatItem(
                    value: "\(UserDefaults.standard.integer(forKey: "citiesVisited"))",
                    label: "profile.cities".localized,
                    icon: "building.2.fill"
                )

                Divider()
                    .frame(height: 40)

                // Trips count
                profileStatItem(
                    value: "\(UserDefaults.standard.integer(forKey: "tripsCount"))",
                    label: "profile.trips".localized,
                    icon: "map.fill"
                )
            }
            .padding(.vertical, ThemeManager.Spacing.xs)
        }
        .listRowBackground(AppColors.surface)
    }

    private func profileStatItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.primary)

            Text(value)
                .font(.custom("SpaceMono-Bold", size: 20))
                .foregroundStyle(AppColors.textPrimary)

            Text(label)
                .font(ThemeManager.Typography.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Premium Section
    private var premiumSection: some View {
        Section {
            if storeManager.isPremium {
                // Premium üye
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(AppColors.primary)

                    VStack(alignment: .leading) {
                        Text("settings.premiumMember".localized)
                            .font(ThemeManager.Typography.headline)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("settings.allFeaturesUnlocked".localized)
                            .font(ThemeManager.Typography.caption1)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(AppColors.success)
                }
            } else {
                // Kredi bakiyesi + Kredi mağazası butonu
                Button {
                    showCreditStore = true
                } label: {
                    HStack {
                        Image(systemName: "bolt.circle.fill")
                            .foregroundStyle(AppColors.primary)
                            .font(.system(size: 20))

                        VStack(alignment: .leading) {
                            Text("settings.creditBalance".localized)
                                .font(ThemeManager.Typography.headline)
                                .foregroundStyle(AppColors.textPrimary)

                            Text("creditStore.buyCredits".localized)
                                .font(ThemeManager.Typography.caption1)
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        Spacer()

                        Text("\(creditManager.balance)")
                            .font(.custom("SpaceMono-Bold", size: 22))
                            .foregroundStyle(AppColors.primary)

                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppColors.textTertiary)
                            .font(.system(size: 14))
                    }
                }

                // Premium'a yükselt
                Button {
                    showPremiumSheet = true
                } label: {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(AppColors.primary)

                        VStack(alignment: .leading) {
                            Text("settings.upgradePremium".localized)
                                .font(ThemeManager.Typography.headline)
                                .foregroundStyle(AppColors.textPrimary)

                            Text("settings.unlimitedTrips".localized)
                                .font(ThemeManager.Typography.caption1)
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
        } header: {
            Text("settings.premium".localized)
        }
        .listRowBackground(AppColors.surface)
    }

    // MARK: - Preferences Section
    private var preferencesSection: some View {
        Section {
            // Language
            NavigationLink {
                LanguageSettingsView()
            } label: {
                SettingsRow(
                    icon: "globe",
                    title: "settings.language".localized,
                    subtitle: appState.locale.displayName
                )
            }

            // Notifications
            NavigationLink {
                NotificationSettingsView()
            } label: {
                SettingsRow(
                    icon: "bell.fill",
                    title: "settings.notifications".localized,
                    subtitle: nil
                )
            }
        } header: {
            Text("settings.preferences".localized)
        }
        .listRowBackground(AppColors.surface)
    }

    // MARK: - About Section
    private var aboutSection: some View {
        Section {
            // Rate app
            Button {
                rateApp()
            } label: {
                SettingsRow(
                    icon: "star.fill",
                    title: "settings.rateApp".localized,
                    subtitle: nil
                )
            }

            // Share app
            Button {
                shareApp()
            } label: {
                SettingsRow(
                    icon: "square.and.arrow.up",
                    title: "settings.shareWithFriends".localized,
                    subtitle: nil
                )
            }

            // Terms
            Link(destination: URL(string: "https://guroute.app/terms")!) {
                SettingsRow(
                    icon: "doc.text.fill",
                    title: "settings.termsOfService".localized,
                    subtitle: nil
                )
            }

            // Privacy Policy
            Link(destination: URL(string: "https://guroute.app/privacy")!) {
                SettingsRow(
                    icon: "hand.raised.fill",
                    title: "settings.privacyPolicy".localized,
                    subtitle: nil
                )
            }

            // Version
            HStack {
                SettingsRow(
                    icon: "info.circle.fill",
                    title: "settings.version".localized,
                    subtitle: nil
                )
                Spacer()
                Text("\(AppConfig.shared.appVersion) (\(AppConfig.shared.buildNumber))")
                    .font(ThemeManager.Typography.subheadline)
                    .foregroundStyle(AppColors.textTertiary)
            }
        } header: {
            Text("settings.about".localized)
        }
        .listRowBackground(AppColors.surface)
    }

    // MARK: - Support Section
    private var supportSection: some View {
        Section {
            Button {
                Task {
                    await storeManager.restorePurchases()
                }
            } label: {
                SettingsRow(
                    icon: "arrow.clockwise",
                    title: "settings.restorePurchases".localized,
                    subtitle: nil
                )
            }

            Link(destination: URL(string: "mailto:support@guroute.app")!) {
                SettingsRow(
                    icon: "envelope.fill",
                    title: "settings.support".localized,
                    subtitle: nil
                )
            }
        } header: {
            Text("settings.support".localized)
        }
        .listRowBackground(AppColors.surface)
    }

    // MARK: - Actions

    private func rateApp() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }

    private func shareApp() {
        let url = URL(string: "https://apps.apple.com/app/guroute/id6744894498")!
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: ThemeManager.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ThemeManager.Typography.body)
                    .foregroundStyle(AppColors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(ThemeManager.Typography.caption1)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Settings Helper Views

struct LanguageSettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var showRestartAlert = false

    var body: some View {
        List {
            ForEach(AppLocale.allCases, id: \.self) { locale in
                Button {
                    appState.locale = locale
                    localizationManager.currentLanguage = locale.rawValue
                    showRestartAlert = true
                } label: {
                    HStack {
                        Text(locale.displayName)
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        if appState.locale == locale {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppColors.primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("settings.language".localized)
        .alert("language.changed".localized, isPresented: $showRestartAlert) {
            Button("common.done".localized) { }
        } message: {
            Text("language.restartNote".localized)
        }
    }
}

struct NotificationSettingsView: View {
    @AppStorage("tripReminders") private var tripReminders = true
    @AppStorage("weatherAlerts") private var weatherAlerts = true
    @AppStorage("promotions") private var promotions = false

    var body: some View {
        List {
            Toggle("notifications.tripReminders".localized, isOn: $tripReminders)
            Toggle("notifications.weatherAlerts".localized, isOn: $weatherAlerts)
            Toggle("notifications.promotions".localized, isOn: $promotions)
        }
        .navigationTitle("settings.notifications".localized)
        .tint(AppColors.primary)
    }
}

// MARK: - Premium Paywall View (Sadece Abonelik)

struct PremiumPaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storeManager: StoreManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var purchaseSuccessMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ThemeManager.Spacing.lg) {
                    // Header
                    premiumHeader

                    // Premium özellikler
                    premiumFeatures

                    // Abonelik planları
                    subscriptionPlans

                    // Alt bilgi
                    premiumFooter
                }
            }
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            }
            .alert("premium.error".localized, isPresented: .constant(errorMessage != nil)) {
                Button("common.close".localized) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("premium.success".localized, isPresented: .constant(purchaseSuccessMessage != nil)) {
                Button("common.close".localized) {
                    purchaseSuccessMessage = nil
                    dismiss()
                }
            } message: {
                Text(purchaseSuccessMessage ?? "")
            }
        }
    }

    // MARK: - Header
    private var premiumHeader: some View {
        VStack(spacing: ThemeManager.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(AppColors.primary.opacity(0.05))
                    .frame(width: 140, height: 140)

                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.premiumGradient)
            }
            .padding(.top, ThemeManager.Spacing.xl)

            Text("premium.title".localized)
                .font(ThemeManager.Typography.title1)
                .foregroundStyle(AppColors.textPrimary)

            Text("premium.subtitle".localized)
                .font(ThemeManager.Typography.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ThemeManager.Spacing.xl)
        }
    }

    // MARK: - Features
    private var premiumFeatures: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.md) {
            FeatureRow(icon: "infinity", text: "premium.unlimitedAI".localized)
            FeatureRow(icon: "bolt.fill", text: "premium.priorityAI".localized)
            FeatureRow(icon: "arrow.clockwise", text: "premium.unlimitedRevisions".localized)
            FeatureRow(icon: "star.fill", text: "premium.prioritySupport".localized)
        }
        .padding()
        .background(AppColors.surface)
        .cornerRadius(ThemeManager.CornerRadius.medium)
        .padding(.horizontal)
    }

    // MARK: - Subscription Plans
    private var subscriptionPlans: some View {
        VStack(spacing: ThemeManager.Spacing.md) {
            if !storeManager.subscriptionProducts.isEmpty {
                ForEach(storeManager.subscriptionProducts) { product in
                    SubscriptionCard(product: product) {
                        Task {
                            isLoading = true
                            do {
                                let success = try await storeManager.purchaseSubscription(product)
                                if success {
                                    purchaseSuccessMessage = "premium.subscriptionActivated".localized
                                }
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isLoading = false
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                // Placeholder abonelikler
                PricingCard(
                    title: "premium.monthly".localized,
                    price: "$9.99",
                    period: "premium.perMonth".localized,
                    isPopular: false,
                    action: {}
                )
                .padding(.horizontal)

                PricingCard(
                    title: "premium.yearly".localized,
                    price: "$59.99",
                    period: "premium.perYear".localized,
                    isPopular: true,
                    savings: "premium.savings".localized,
                    action: {}
                )
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Footer
    private var premiumFooter: some View {
        VStack(spacing: ThemeManager.Spacing.sm) {
            Button {
                Task { await storeManager.restorePurchases() }
            } label: {
                Text("settings.restorePurchases".localized)
                    .font(ThemeManager.Typography.caption1)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Text("premium.legalText".localized)
                .font(ThemeManager.Typography.caption2)
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom)
        }
    }
}

// MARK: - Credit Pack Card (StoreKit)

struct CreditPackCard: View {
    let product: Product
    let action: () -> Void

    private var credits: Int {
        product.creditAmount ?? 0
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: ThemeManager.Spacing.md) {
                // Kredi ikonu
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Text("\(credits)")
                        .font(.custom("SpaceMono-Bold", size: 20))
                        .foregroundStyle(AppColors.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(ThemeManager.Typography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(product.description)
                        .font(ThemeManager.Typography.caption1)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(ThemeManager.Typography.title3)
                    .foregroundStyle(AppColors.primary)
            }
            .padding()
            .background(AppColors.surface)
            .cornerRadius(ThemeManager.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Credit Pack Placeholder

struct CreditPackPlaceholder: View {
    let credits: Int
    let price: String
    let perCredit: String
    var isPopular: Bool = false
    var isBestValue: Bool = false

    var body: some View {
        HStack(spacing: ThemeManager.Spacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 48, height: 48)

                Text("\(credits)")
                    .font(.custom("SpaceMono-Bold", size: 20))
                    .foregroundStyle(AppColors.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(credits) " + "credits.credits".localized)
                        .font(ThemeManager.Typography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    if isPopular {
                        Text("paywall.popular".localized)
                            .font(.custom("SpaceMono-Bold", size: 9))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.primary)
                            .cornerRadius(4)
                    }

                    if isBestValue {
                        Text("paywall.bestValue".localized)
                            .font(.custom("SpaceMono-Bold", size: 9))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.success)
                            .cornerRadius(4)
                    }
                }

                Text(perCredit + " / " + "credits.credit".localized)
                    .font(ThemeManager.Typography.caption1)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Text(price)
                .font(ThemeManager.Typography.title3)
                .foregroundStyle(AppColors.primary)
        }
        .padding()
        .background(isPopular || isBestValue ? AppColors.primary.opacity(0.05) : AppColors.surface)
        .cornerRadius(ThemeManager.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                .stroke(isPopular || isBestValue ? AppColors.primary.opacity(0.5) : AppColors.cardBorder, lineWidth: isPopular || isBestValue ? 1.5 : 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Subscription Card

struct SubscriptionCard: View {
    let product: Product
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(AppColors.primary)
                        Text(product.displayName)
                            .font(ThemeManager.Typography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    Text(product.description)
                        .font(ThemeManager.Typography.caption1)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(product.displayPrice)
                        .font(ThemeManager.Typography.title3)
                        .foregroundStyle(AppColors.primary)

                    Text(product.periodText)
                        .font(ThemeManager.Typography.caption1)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding()
            .background(AppColors.primary.opacity(0.08))
            .cornerRadius(ThemeManager.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                    .stroke(AppColors.primary, lineWidth: 2)
            )
        }
    }
}

// MARK: - Pricing Card (Placeholder)

struct PricingCard: View {
    let title: String
    let price: String
    let period: String
    var isPopular: Bool = false
    var savings: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(AppColors.primary)
                        Text(title)
                            .font(ThemeManager.Typography.headline)
                            .foregroundStyle(AppColors.textPrimary)

                        if isPopular {
                            Text("premium.mostPopular".localized)
                                .font(.custom("SpaceMono-Bold", size: 10))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.primary)
                                .cornerRadius(4)
                        }
                    }

                    if let savings = savings {
                        Text(savings)
                            .font(ThemeManager.Typography.caption1)
                            .foregroundStyle(AppColors.success)
                    }
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(price)
                        .font(ThemeManager.Typography.title3)
                        .foregroundStyle(AppColors.primary)

                    Text(period)
                        .font(ThemeManager.Typography.caption1)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding()
            .background(isPopular ? AppColors.primary.opacity(0.1) : AppColors.surface)
            .cornerRadius(ThemeManager.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                    .stroke(isPopular ? AppColors.primary : AppColors.cardBorder, lineWidth: isPopular ? 2 : 1)
            )
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: ThemeManager.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.primary)
                .frame(width: 24)

            Text(text)
                .font(ThemeManager.Typography.body)
                .foregroundStyle(AppColors.textPrimary)
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .environmentObject(StoreManager())
}
