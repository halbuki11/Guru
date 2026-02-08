import Foundation
import StoreKit
import Supabase

/// Manages Apple In-App Purchases for premium features and credit packs
@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    // MARK: - Product IDs

    // Premium Abonelik
    static let premiumMonthlyID = "com.guroute.premium.monthly"
    static let premiumYearlyID = "com.guroute.premium.yearly"

    // Kredi Paketleri (Consumable)
    static let credits3ID = "com.guroute.credits.3"
    static let credits5ID = "com.guroute.credits.5"
    static let credits10ID = "com.guroute.credits.10"

    static let subscriptionIDs: [String] = [premiumMonthlyID, premiumYearlyID]

    static let creditPackIDs: [String] = [credits3ID, credits5ID, credits10ID]

    static let allProductIDs: [String] = [
        premiumMonthlyID, premiumYearlyID,
        credits3ID, credits5ID, credits10ID
    ]

    // MARK: - Published State

    @Published private(set) var subscriptionProducts: [Product] = []
    @Published private(set) var creditProducts: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var purchaseError: String?
    @Published private(set) var isSupabasePremium = false

    var isPremium: Bool {
        !purchasedProductIDs.isEmpty || isSupabasePremium
    }

    private var updateListenerTask: Task<Void, Error>?

    init() {
        // Start listening for transactions
        updateListenerTask = listenForTransactions()

        // Load products and check premium
        Task {
            await loadProducts()
            await updatePurchasedProducts()
            await checkSupabasePremium()
        }
    }

    /// Supabase'den premium durumunu kontrol et
    /// Birden fazla kez çağrılabilir — userId hazır olduğunda çalışır
    func checkSupabasePremium() async {
        guard let userId = UserManager.shared.userId else {
            return
        }
        do {
            let isPremium = try await SupabaseService.shared.checkPremiumStatus(userId: userId)
            self.isSupabasePremium = isPremium
        } catch {
            // Silent
        }
    }

    /// Çıkış yapıldığında premium durumunu sıfırla
    func resetPremiumState() {
        isSupabasePremium = false
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let allProducts = try await Product.products(for: Self.allProductIDs)

            // Abonelik ürünlerini ayır
            subscriptionProducts = allProducts
                .filter { Self.subscriptionIDs.contains($0.id) }
                .sorted { $0.price < $1.price }

            // Kredi paketlerini ayır
            creditProducts = allProducts
                .filter { Self.creditPackIDs.contains($0.id) }
                .sorted { $0.price < $1.price }
        } catch {
            // Silent
        }
    }

    // MARK: - Purchase Subscription

    func purchaseSubscription(_ product: Product) async throws -> Bool {
        purchaseError = nil
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()

            // Premium durumunu Supabase'e kaydet
            await syncPremiumStatus(isPremium: true)
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Purchase Credit Pack

    func purchaseCreditPack(_ product: Product) async throws -> Int? {
        purchaseError = nil
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)

            // Kredi miktarını belirle
            guard let pack = CreditPack.fromProductID(product.id) else {
                await transaction.finish()
                return nil
            }

            // Kullanıcı ID'sini al (Apple Sign In → UserManager)
            guard let userId = UserManager.shared.userId else {
                await transaction.finish()
                return nil
            }

            // Kredileri ekle
            let newBalance = await CreditManager.shared.addPurchasedCredits(
                userId: userId,
                amount: pack.creditAmount,
                productId: product.id
            )

            await transaction.finish()
            return newBalance

        case .userCancelled:
            return nil

        case .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            purchaseError = "restoreFailed".localized
        }
    }

    // MARK: - Check Entitlements

    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []

        // Check current entitlements (only subscriptions show up here)
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchasedIDs.insert(transaction.productID)
            } catch {
                // Silent
            }
        }

        purchasedProductIDs = purchasedIDs
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    // Silent
                }
            }
        }
    }

    // MARK: - Verify Transaction

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Sync Premium to Supabase

    private func syncPremiumStatus(isPremium: Bool) async {
        // Apple Sign In → UserManager kullan
        guard let userId = UserManager.shared.userId else {
            return
        }

        do {
            try await AppConfig.shared.supabaseClient
                .from("profiles")
                .update(["is_premium": AnyJSON.bool(isPremium)])
                .eq("id", value: userId)
                .execute()

            // Hemen UI'ı güncelle
            self.isSupabasePremium = isPremium
        } catch {
            // Silent
        }
    }
}

// MARK: - Store Errors

enum StoreError: LocalizedError {
    case failedVerification
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "store.verificationFailed".localized
        case .purchaseFailed:
            return "store.purchaseFailed".localized
        }
    }
}

// MARK: - Product Extensions

extension Product {
    var periodText: String {
        guard let subscription = subscription else { return "" }

        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value

        switch unit {
        case .month:
            return value == 1 ? "/ " + "period.month".localized : "/ \(value) " + "period.months".localized
        case .year:
            return value == 1 ? "/ " + "period.year".localized : "/ \(value) " + "period.years".localized
        case .week:
            return value == 1 ? "/ " + "period.week".localized : "/ \(value) " + "period.weeks".localized
        case .day:
            return value == 1 ? "/ " + "period.day".localized : "/ \(value) " + "period.days".localized
        @unknown default:
            return ""
        }
    }

    /// Bu ürün kredi paketi mi?
    var isCreditPack: Bool {
        StoreManager.creditPackIDs.contains(id)
    }

    /// Bu ürün abonelik mi?
    var isSubscription: Bool {
        StoreManager.subscriptionIDs.contains(id)
    }

    /// Kredi paketi miktarı
    var creditAmount: Int? {
        CreditPack.fromProductID(id)?.creditAmount
    }
}
