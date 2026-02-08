import Foundation

// MARK: - User Stamp
struct UserStamp: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    var countryCode: String
    var stampDate: Date
    var tripId: String?
    var stampVariantId: String?
    var displayVariantId: String?
    var usedVariantIds: [String]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case countryCode = "country_code"
        case stampDate = "stamp_date"
        case tripId = "trip_id"
        case stampVariantId = "stamp_variant_id"
        case displayVariantId = "display_variant_id"
        case usedVariantIds = "used_variant_ids"
        case createdAt = "created_at"
    }
}

// MARK: - Country Stamp (Template)
struct CountryStamp: Codable, Identifiable, Equatable {
    let id: String
    var countryCode: String
    var countryName: String
    var variants: [StampVariant]
    var isActive: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case countryCode = "country_code"
        case countryName = "country_name"
        case variants
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

// MARK: - Stamp Variant
struct StampVariant: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var imageUrl: String
    var isPremium: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case imageUrl = "image_url"
        case isPremium = "is_premium"
    }
}

// MARK: - Achievement Stamp
struct AchievementStamp: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var nameTr: String?
    var description: String?
    var descriptionTr: String?
    var imageUrl: String
    var requirement: AchievementRequirement
    var threshold: Int
    var isPremium: Bool
    var isActive: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameTr = "name_tr"
        case description
        case descriptionTr = "description_tr"
        case imageUrl = "image_url"
        case requirement
        case threshold
        case isPremium = "is_premium"
        case isActive = "is_active"
        case createdAt = "created_at"
    }

    var localizedName: String {
        if LocalizationManager.shared.currentLanguage == "tr" {
            return nameTr ?? name
        }
        return name
    }

    var localizedDescription: String? {
        if LocalizationManager.shared.currentLanguage == "tr" {
            return descriptionTr ?? description
        }
        return description
    }
}

enum AchievementRequirement: String, Codable {
    case countriesVisited = "countries_visited"
    case citiesVisited = "cities_visited"
    case tripsCompleted = "trips_completed"
    case continentsVisited = "continents_visited"
    case worldExplorer = "world_explorer"

    var displayName: String {
        switch self {
        case .countriesVisited: return "achievement.countriesVisited".localized
        case .citiesVisited: return "achievement.citiesVisited".localized
        case .tripsCompleted: return "achievement.tripsCompleted".localized
        case .continentsVisited: return "achievement.continentsVisited".localized
        case .worldExplorer: return "achievement.worldExplorer".localized
        }
    }
}

// MARK: - User Achievement
struct UserAchievement: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    var achievementId: String
    var unlockedAt: Date
    var achievement: AchievementStamp?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case achievementId = "achievement_id"
        case unlockedAt = "unlocked_at"
        case achievement
    }
}

// MARK: - Passport Stats
struct PassportStats: Equatable {
    var countriesVisited: Int
    var citiesVisited: Int
    var continentsVisited: Int
    var totalStamps: Int
    var achievementsUnlocked: Int
    var worldPercentage: Double

    static var empty: PassportStats {
        PassportStats(
            countriesVisited: 0,
            citiesVisited: 0,
            continentsVisited: 0,
            totalStamps: 0,
            achievementsUnlocked: 0,
            worldPercentage: 0
        )
    }
}
