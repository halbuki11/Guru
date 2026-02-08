import SwiftUI
import StoreKit

// MARK: - Credit Store View (Bağımsız Kredi Mağazası)

struct CreditStoreView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storeManager: StoreManager
    @StateObject private var creditManager = CreditManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var purchaseSuccessMessage: String?
    @State private var showReferralShare = false
    @State private var showTransactions = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ThemeManager.Spacing.lg) {
                    // Kredi Bakiyesi Hero
                    creditHeroSection

                    // Kredi Paketleri
                    creditPacksSection

                    // Ücretsiz Kredi Bilgisi
                    freeCreditsInfo

                    // Referans Bölümü
                    referralSection

                    // İşlem Geçmişi Link
                    transactionLink

                    // Premium Tanıtımı
                    premiumBanner

                    // Alt bilgi
                    footerSection
                }
                .padding(.bottom, ThemeManager.Spacing.xl)
            }
            .background(AppColors.background)
            .navigationTitle("creditStore.title".localized)
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
                Button("common.close".localized) { purchaseSuccessMessage = nil }
            } message: {
                Text(purchaseSuccessMessage ?? "")
            }
            .sheet(isPresented: $showReferralShare) {
                if let _ = creditManager.referralCode?.code {
                    ShareSheet(items: [creditManager.referralShareText()])
                }
            }
            .sheet(isPresented: $showTransactions) {
                CreditTransactionsView()
            }
            .task {
                // Açılışta kredi bakiyesini yükle
                if let userId = UserManager.shared.userId {
                    await creditManager.loadCredits(userId: userId)
                }
            }
        }
    }

    // MARK: - Credit Hero Section
    private var creditHeroSection: some View {
        VStack(spacing: ThemeManager.Spacing.md) {
            // Büyük bakiye gösterimi
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(AppColors.primary.opacity(0.05))
                    .frame(width: 160, height: 160)

                VStack(spacing: 2) {
                    Text("\(creditManager.balance)")
                        .font(.custom("SpaceMono-Bold", size: 48))
                        .foregroundStyle(AppColors.primary)

                    Text("credits.credits".localized)
                        .font(ThemeManager.Typography.caption1)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.top, ThemeManager.Spacing.lg)

            // Alt açıklama
            HStack(spacing: ThemeManager.Spacing.lg) {
                VStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.primary)
                    Text("1 " + "credits.credit".localized)
                        .font(ThemeManager.Typography.caption1Bold)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("paywall.perTrip".localized)
                        .font(ThemeManager.Typography.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                }

                Rectangle()
                    .fill(AppColors.divider)
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Image(systemName: "infinity")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.success)
                    Text("creditStore.neverExpire".localized)
                        .font(ThemeManager.Typography.caption1Bold)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("creditStore.keepForever".localized)
                        .font(ThemeManager.Typography.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                }

                Rectangle()
                    .fill(AppColors.divider)
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.info)
                    Text("creditStore.freeRevision".localized)
                        .font(ThemeManager.Typography.caption1Bold)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("creditStore.unlimited".localized)
                        .font(ThemeManager.Typography.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Credit Packs Section
    private var creditPacksSection: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
            // Başlık
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(AppColors.primary)
                Text("paywall.creditPacks".localized)
                    .font(ThemeManager.Typography.headline)
                    .foregroundStyle(AppColors.textPrimary)
            }
            .padding(.horizontal)

            // StoreKit ürünleri
            if !storeManager.creditProducts.isEmpty {
                ForEach(storeManager.creditProducts) { product in
                    CreditPackCard(product: product) {
                        Task {
                            isLoading = true
                            do {
                                if let newBalance = try await storeManager.purchaseCreditPack(product) {
                                    purchaseSuccessMessage = String(format: "paywall.creditsPurchased".localized, product.creditAmount ?? 0, newBalance)
                                    // Bakiyeyi anında güncelle
                                    if let userId = UserManager.shared.userId {
                                        await creditManager.loadCredits(userId: userId)
                                    }
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
                // Placeholder kredi paketleri (StoreKit bağlanmadan)
                creditPackPlaceholder(credits: 3, price: "$2.99", perCredit: "$1.00", tag: nil)
                creditPackPlaceholder(credits: 5, price: "$4.99", perCredit: "$0.99", tag: "paywall.popular".localized)
                creditPackPlaceholder(credits: 10, price: "$7.99", perCredit: "$0.80", tag: "paywall.bestValue".localized)
            }
        }
    }

    private func creditPackPlaceholder(credits: Int, price: String, perCredit: String, tag: String?) -> some View {
        HStack(spacing: ThemeManager.Spacing.md) {
            // Kredi ikonu
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 52, height: 52)

                Text("\(credits)")
                    .font(.custom("SpaceMono-Bold", size: 22))
                    .foregroundStyle(AppColors.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(credits) " + "credits.credits".localized)
                        .font(ThemeManager.Typography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    if let tag = tag {
                        Text(tag)
                            .font(.custom("SpaceMono-Bold", size: 9))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tag == "paywall.bestValue".localized ? AppColors.success : AppColors.primary)
                            .cornerRadius(4)
                    }
                }

                Text(perCredit + " / " + "credits.credit".localized)
                    .font(ThemeManager.Typography.caption1)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(price)
                    .font(.custom("SpaceMono-Bold", size: 20))
                    .foregroundStyle(AppColors.primary)
            }
        }
        .padding()
        .background(tag != nil ? AppColors.primary.opacity(0.05) : AppColors.surface)
        .cornerRadius(ThemeManager.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                .stroke(tag != nil ? AppColors.primary.opacity(0.5) : AppColors.cardBorder, lineWidth: tag != nil ? 1.5 : 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Free Credits Info
    private var freeCreditsInfo: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
            HStack(spacing: ThemeManager.Spacing.xs) {
                Image(systemName: "gift.fill")
                    .foregroundStyle(AppColors.success)
                Text("paywall.freeCreditsTitle".localized)
                    .font(ThemeManager.Typography.headline)
                    .foregroundStyle(AppColors.textPrimary)
            }

            VStack(alignment: .leading, spacing: ThemeManager.Spacing.xs) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.success)
                    Text("creditStore.welcomeCredits".localized)
                        .font(ThemeManager.Typography.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.success)
                    Text("creditStore.monthlyCredit".localized)
                        .font(ThemeManager.Typography.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.success)
                    Text("creditStore.referralCredit".localized)
                        .font(ThemeManager.Typography.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.success.opacity(0.06))
        .cornerRadius(ThemeManager.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                .stroke(AppColors.success.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Referral Section
    private var referralSection: some View {
        VStack(spacing: ThemeManager.Spacing.sm) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(AppColors.primary)
                Text("referral.title".localized)
                    .font(ThemeManager.Typography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
            }

            Text("referral.description".localized)
                .font(ThemeManager.Typography.caption1)
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let code = creditManager.referralCode?.code {
                // Referans kodu göster
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("referral.codeLabel".localized)
                            .font(ThemeManager.Typography.caption1)
                            .foregroundStyle(AppColors.textTertiary)

                        Text(code)
                            .font(.custom("SpaceMono-Bold", size: 22))
                            .foregroundStyle(AppColors.primary)
                            .kerning(2)
                    }

                    Spacer()

                    // Kopyala butonu
                    Button {
                        UIPasteboard.general.string = code
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 18))
                            Text("creditStore.copy".localized)
                                .font(ThemeManager.Typography.caption2)
                        }
                        .foregroundStyle(AppColors.textSecondary)
                    }

                    // Paylaş butonu
                    Button {
                        showReferralShare = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18))
                            Text("referral.share".localized)
                                .font(ThemeManager.Typography.caption2)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColors.primary)
                        .cornerRadius(ThemeManager.CornerRadius.small)
                    }
                }
                .padding()
                .background(AppColors.primary.opacity(0.08))
                .cornerRadius(ThemeManager.CornerRadius.medium)

                // Referans istatistikleri
                if let referral = creditManager.referralCode, referral.totalReferrals > 0 {
                    HStack {
                        Label("\(referral.totalReferrals) " + "referral.friends".localized, systemImage: "person.fill.checkmark")
                        Spacer()
                        Label("+\(referral.totalCreditsEarned) " + "credits.credits".localized, systemImage: "bolt.fill")
                            .foregroundStyle(AppColors.success)
                    }
                    .font(ThemeManager.Typography.caption1)
                    .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding()
        .background(AppColors.surface)
        .cornerRadius(ThemeManager.CornerRadius.medium)
        .padding(.horizontal)
    }

    // MARK: - Transaction Link
    private var transactionLink: some View {
        Button {
            showTransactions = true
        } label: {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(AppColors.primary)
                Text("creditStore.transactionHistory".localized)
                    .font(ThemeManager.Typography.body)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColors.textTertiary)
                    .font(.system(size: 14))
            }
            .padding()
            .background(AppColors.surface)
            .cornerRadius(ThemeManager.CornerRadius.medium)
        }
        .padding(.horizontal)
    }

    // MARK: - Premium Banner
    private var premiumBanner: some View {
        VStack(spacing: ThemeManager.Spacing.sm) {
            HStack(spacing: ThemeManager.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColors.premiumGradient)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("creditStore.premiumBannerTitle".localized)
                        .font(ThemeManager.Typography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("creditStore.premiumBannerSubtitle".localized)
                        .font(ThemeManager.Typography.caption1)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColors.primary)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [AppColors.primary.opacity(0.08), AppColors.primary.opacity(0.03)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(ThemeManager.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: ThemeManager.Spacing.xs) {
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
        }
    }
}

// MARK: - Credit Transactions View

struct CreditTransactionsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var creditManager = CreditManager.shared
    @State private var isLoaded = false

    var body: some View {
        NavigationStack {
            Group {
                if creditManager.transactions.isEmpty && isLoaded {
                    VStack(spacing: ThemeManager.Spacing.md) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundStyle(AppColors.textTertiary)

                        Text("creditStore.noTransactions".localized)
                            .font(ThemeManager.Typography.body)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(creditManager.transactions) { transaction in
                            HStack(spacing: ThemeManager.Spacing.sm) {
                                // İkon
                                ZStack {
                                    Circle()
                                        .fill(transaction.amount > 0 ? AppColors.success.opacity(0.15) : AppColors.error.opacity(0.15))
                                        .frame(width: 40, height: 40)

                                    Image(systemName: transaction.type.icon)
                                        .font(.system(size: 16))
                                        .foregroundStyle(transaction.amount > 0 ? AppColors.success : AppColors.error)
                                }

                                // Açıklama
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(transaction.type.displayName)
                                        .font(ThemeManager.Typography.subheadline)
                                        .foregroundStyle(AppColors.textPrimary)

                                    Text(transaction.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(ThemeManager.Typography.caption2)
                                        .foregroundStyle(AppColors.textTertiary)
                                }

                                Spacer()

                                // Miktar
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(transaction.amount > 0 ? "+\(transaction.amount)" : "\(transaction.amount)")
                                        .font(.custom("SpaceMono-Bold", size: 18))
                                        .foregroundStyle(transaction.amount > 0 ? AppColors.success : AppColors.error)

                                    Text("creditStore.balanceAfter".localized + " \(transaction.balanceAfter)")
                                        .font(ThemeManager.Typography.caption2)
                                        .foregroundStyle(AppColors.textTertiary)
                                }
                            }
                            .listRowBackground(AppColors.surface)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppColors.background)
            .navigationTitle("creditStore.transactionHistory".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
            .task {
                if let userId = UserManager.shared.userId {
                    await creditManager.loadTransactions(userId: userId)
                }
                isLoaded = true
            }
        }
    }
}
