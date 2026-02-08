import Foundation

// MARK: - User Profile
struct UserProfile: Codable, Identifiable, Equatable {
    let id: String
    var email: String?
    var fullName: String?
    var avatarUrl: String?
    var bio: String?
    var isPublic: Bool
    var allowFollowRequests: Bool
    var countriesVisited: Int
    var citiesVisited: Int
    var tripsCount: Int
    var isPremium: Bool
    var premiumExpiresAt: Date?
    let createdAt: Date
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "display_name"
        case avatarUrl = "avatar_url"
        case bio
        case isPublic = "is_public"
        case allowFollowRequests = "allow_follow_requests"
        case countriesVisited = "countries_visited"
        case citiesVisited = "cities_visited"
        case tripsCount = "trips_count"
        case isPremium = "is_premium"
        case premiumExpiresAt = "premium_expires_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Kullanıcı premium mi ya da kredisi var mı?
    var canGenerateTrip: Bool {
        isPremium
    }

    // Display name with fallback
    var displayName: String {
        if let name = fullName, !name.isEmpty {
            return name
        }
        if let email = email {
            return email.components(separatedBy: "@").first ?? "Kullanıcı"
        }
        return "Kullanıcı"
    }

    // Initials for avatar placeholder
    var initials: String {
        let name = displayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - User Credits
struct UserCredits: Codable, Equatable {
    let id: String
    let userId: String
    var balance: Int
    var lifetimeEarned: Int
    var lifetimeSpent: Int
    var lastFreeCreditAt: Date?
    let createdAt: Date
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case balance
        case lifetimeEarned = "lifetime_earned"
        case lifetimeSpent = "lifetime_spent"
        case lastFreeCreditAt = "last_free_credit_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Aylık ücretsiz kredi almaya uygun mu?
    var eligibleForMonthlyCredit: Bool {
        guard let lastFree = lastFreeCreditAt else { return true }
        return Date().timeIntervalSince(lastFree) >= 30 * 24 * 60 * 60
    }
}

// MARK: - Credit Transaction
struct CreditTransaction: Codable, Identifiable {
    let id: String
    let userId: String
    let amount: Int
    let balanceAfter: Int
    let type: CreditTransactionType
    let description: String?
    let referenceId: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case amount
        case balanceAfter = "balance_after"
        case type
        case description
        case referenceId = "reference_id"
        case createdAt = "created_at"
    }
}

enum CreditTransactionType: String, Codable {
    case welcomeBonus = "welcome_bonus"
    case monthlyFree = "monthly_free"
    case purchase = "purchase"
    case tripGeneration = "trip_generation"
    case referralBonus = "referral_bonus"
    case referralWelcome = "referral_welcome"
    case adminGrant = "admin_grant"
    case refund = "refund"

    var displayName: String {
        switch self {
        case .welcomeBonus: return "credits.welcomeBonus".localized
        case .monthlyFree: return "credits.monthlyFree".localized
        case .purchase: return "credits.purchase".localized
        case .tripGeneration: return "credits.tripGeneration".localized
        case .referralBonus: return "credits.referralBonus".localized
        case .referralWelcome: return "credits.referralWelcome".localized
        case .adminGrant: return "credits.adminGrant".localized
        case .refund: return "credits.refund".localized
        }
    }

    var icon: String {
        switch self {
        case .welcomeBonus: return "gift.fill"
        case .monthlyFree: return "calendar.badge.plus"
        case .purchase: return "creditcard.fill"
        case .tripGeneration: return "airplane"
        case .referralBonus: return "person.2.fill"
        case .referralWelcome: return "hand.wave.fill"
        case .adminGrant: return "star.fill"
        case .refund: return "arrow.uturn.backward"
        }
    }
}

// MARK: - Referral Code
struct ReferralCode: Codable, Equatable {
    let id: String
    let userId: String
    var code: String
    var totalReferrals: Int
    var totalCreditsEarned: Int
    var isActive: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case code
        case totalReferrals = "total_referrals"
        case totalCreditsEarned = "total_credits_earned"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

// MARK: - Referral History
struct ReferralHistory: Codable, Identifiable {
    let id: String
    let referrerUserId: String
    let referredUserId: String
    let referralCode: String
    let referrerCredited: Bool
    let referredCredited: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case referrerUserId = "referrer_user_id"
        case referredUserId = "referred_user_id"
        case referralCode = "referral_code"
        case referrerCredited = "referrer_credited"
        case referredCredited = "referred_credited"
        case createdAt = "created_at"
    }
}

// MARK: - Credit Spend Result
struct CreditSpendResult: Codable {
    let success: Bool
    let reason: String
    let balance: Int
}

// MARK: - Credit Pack (StoreKit ürünleri için)
enum CreditPack: String, CaseIterable {
    case small = "com.guroute.credits.3"     // 3 kredi
    case medium = "com.guroute.credits.5"    // 5 kredi
    case large = "com.guroute.credits.10"    // 10 kredi

    var creditAmount: Int {
        switch self {
        case .small: return 3
        case .medium: return 5
        case .large: return 10
        }
    }

    var displayName: String {
        "\(creditAmount) " + "credits.credits".localized
    }

    static func fromProductID(_ id: String) -> CreditPack? {
        CreditPack(rawValue: id)
    }
}

// MARK: - Auth State
enum AuthState {
    case unknown
    case authenticated(UserProfile)
    case unauthenticated

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }

    var user: UserProfile? {
        if case .authenticated(let user) = self { return user }
        return nil
    }
}

// MARK: - Login Request
struct LoginRequest {
    let email: String
    let password: String
}

// MARK: - Register Request
struct RegisterRequest {
    let email: String
    let password: String
    let fullName: String?
}

// MARK: - Visited Region
struct VisitedRegion: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    var countryCode: String
    var regionCode: String?
    var cityId: String?
    var visitedAt: Date?
    var notes: String?
    var status: VisitStatus
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case countryCode = "country_code"
        case regionCode = "region_code"
        case cityId = "city_id"
        case visitedAt = "visited_at"
        case notes
        case status
        case createdAt = "created_at"
    }
}

enum VisitStatus: String, Codable {
    case visited
    case wishlist

    var displayName: String {
        switch self {
        case .visited: return "Ziyaret Edildi"
        case .wishlist: return "Gitmek İstiyorum"
        }
    }

    var color: String {
        switch self {
        case .visited: return "4CAF50"
        case .wishlist: return "D4A574"
        }
    }
}

// MARK: - City
struct City: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var nameEn: String?
    var countryCode: String
    var latitude: Double
    var longitude: Double
    var population: Int?
    var isCapital: Bool
    var adminRegion: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameEn = "name_en"
        case countryCode = "country_code"
        case latitude
        case longitude
        case population
        case isCapital = "is_capital"
        case adminRegion = "admin_region"
    }

    var displayName: String {
        nameEn ?? name
    }
}

// MARK: - User Visited City
struct UserVisitedCity: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    var cityId: String
    var visitedAt: Date?
    var notes: String?
    var rating: Int?
    var status: VisitStatus
    let createdAt: Date
    var city: City?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case cityId = "city_id"
        case visitedAt = "visited_at"
        case notes
        case rating
        case status
        case createdAt = "created_at"
        case city
    }
}
