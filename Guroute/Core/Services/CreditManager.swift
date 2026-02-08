import Foundation
import Supabase

/// Kredi sistemi yöneticisi
/// Hibrit model: Free (2 hoşgeldin + 1/ay) + Kredi Paketleri + Premium Abonelik
@MainActor
class CreditManager: ObservableObject {
    static let shared = CreditManager()

    @Published private(set) var credits: UserCredits?
    @Published private(set) var referralCode: ReferralCode?
    @Published private(set) var transactions: [CreditTransaction] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    /// Mevcut kredi bakiyesi
    var balance: Int {
        credits?.balance ?? 0
    }

    /// Kullanıcı rota oluşturabilir mi? (Premium VEYA kredi >= 1)
    var canGenerate: Bool {
        StoreManager.shared.isPremium || balance >= 1
    }

    /// Aylık ücretsiz kredi almaya uygun mu?
    var eligibleForMonthlyCredit: Bool {
        credits?.eligibleForMonthlyCredit ?? false
    }

    private var supabase: SupabaseClient {
        AppConfig.shared.supabaseClient
    }

    private init() {}

    // MARK: - Load Credits

    /// Kullanıcının kredi bilgilerini yükle
    func loadCredits(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Kredi bakiyesini çek
            let creditData: [UserCredits] = try await supabase
                .from("user_credits")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            credits = creditData.first

            // Referans kodunu çek
            let referralData: [ReferralCode] = try await supabase
                .from("referral_codes")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            referralCode = referralData.first

            // Aylık ücretsiz kredi kontrolü
            if credits != nil && eligibleForMonthlyCredit {
                await grantMonthlyCredit(userId: userId)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Initialize Credits (Yeni kullanıcı)

    /// Yeni kullanıcı için kredi sistemini başlat
    func initializeCredits(userId: String, referralCode: String? = nil) async -> Bool {
        do {
            let params: [String: AnyJSON]
            if let code = referralCode, !code.isEmpty {
                params = [
                    "p_user_id": .string(userId),
                    "p_referral_code": .string(code.uppercased())
                ]
            } else {
                params = [
                    "p_user_id": .string(userId)
                ]
            }

            try await supabase.rpc("initialize_user_credits", params: params).execute()

            // Kredileri yeniden yükle
            await loadCredits(userId: userId)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Spend Credit

    /// Rota oluşturma için kredi harca
    /// Returns: true = başarılı (kredi harcandı veya premium), false = yetersiz kredi
    func spendCredit(userId: String, tripId: String) async -> CreditSpendResult {
        // Premium kullanıcılar için kredi harcama yok
        if StoreManager.shared.isPremium {
            return CreditSpendResult(success: true, reason: "premium", balance: -1)
        }

        do {
            let params: [String: AnyJSON] = [
                "p_user_id": .string(userId),
                "p_trip_id": .string(tripId)
            ]

            let result: CreditSpendResult = try await supabase
                .rpc("spend_credit", params: params)
                .execute()
                .value

            if result.success {
                // Lokal bakiyeyi güncelle
                credits?.balance = result.balance
            }

            return result
        } catch {
            return CreditSpendResult(success: false, reason: "error", balance: balance)
        }
    }

    // MARK: - Add Purchased Credits

    /// Satın alma sonrası kredi ekle
    func addPurchasedCredits(userId: String, amount: Int, productId: String) async -> Int {
        do {
            let params: [String: AnyJSON] = [
                "p_user_id": .string(userId),
                "p_amount": .integer(amount),
                "p_product_id": .string(productId)
            ]

            let newBalance: Int = try await supabase
                .rpc("add_purchased_credits", params: params)
                .execute()
                .value

            // Lokal bakiyeyi güncelle
            credits?.balance = newBalance
            return newBalance
        } catch {
            return balance
        }
    }

    // MARK: - Monthly Free Credit

    /// Aylık ücretsiz kredi ver
    private func grantMonthlyCredit(userId: String) async {
        do {
            let params: [String: AnyJSON] = [
                "p_user_id": .string(userId)
            ]

            try await supabase.rpc("grant_monthly_credit", params: params).execute()

            // Kredileri yeniden çek
            let creditData: [UserCredits] = try await supabase
                .from("user_credits")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            credits = creditData.first
        } catch {
            // Silent
        }
    }

    // MARK: - Transaction History

    /// Kredi işlem geçmişini yükle
    func loadTransactions(userId: String, limit: Int = 50) async {
        do {
            transactions = try await supabase
                .from("credit_transactions")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } catch {
            // Silent
        }
    }

    // MARK: - Referral

    /// Referans kodu ile paylaşım metni oluştur
    func referralShareText() -> String {
        guard let code = referralCode?.code else { return "" }
        let text = String(format: "referral.shareMessage".localized, code)
        return text
    }

    /// Referans kodunu doğrula (kayıt öncesi)
    func validateReferralCode(_ code: String) async -> Bool {
        do {
            let results: [ReferralCode] = try await supabase
                .from("referral_codes")
                .select()
                .eq("code", value: code.uppercased())
                .eq("is_active", value: true)
                .execute()
                .value

            return !results.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Reset

    /// Çıkış yapıldığında temizle
    func reset() {
        credits = nil
        referralCode = nil
        transactions = []
        error = nil
    }
}
