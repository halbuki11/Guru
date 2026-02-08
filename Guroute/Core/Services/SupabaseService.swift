import Foundation
import Supabase
import SwiftUI

// MARK: - Insert Request Structs (Encodable)

struct TripInsertData: Encodable {
    var userId: String
    var destinationCities: [String]
    var durationNights: Int
    var startDate: Date?
    var arrivalTime: String?
    var departureTime: String?
    var companion: String
    var arrivalPoint: String?
    var stayArea: String
    var transportMode: String
    var iconicPreference: String
    var budget: String
    var pace: String
    var mustVisitPlaces: [String]
    var status: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case destinationCities = "destination_cities"
        case durationNights = "duration_nights"
        case startDate = "start_date"
        case arrivalTime = "arrival_time"
        case departureTime = "departure_time"
        case companion
        case arrivalPoint = "arrival_point"
        case stayArea = "stay_area"
        case transportMode = "transport_mode"
        case iconicPreference = "iconic_preference"
        case budget
        case pace
        case mustVisitPlaces = "must_visit_places"
        case status
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(destinationCities, forKey: .destinationCities)
        try container.encode(durationNights, forKey: .durationNights)

        // Encode date as ISO8601 string for Supabase DATE column
        if let date = startDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            try container.encode(formatter.string(from: date), forKey: .startDate)
        } else {
            try container.encodeNil(forKey: .startDate)
        }

        try container.encodeIfPresent(arrivalTime, forKey: .arrivalTime)
        try container.encodeIfPresent(departureTime, forKey: .departureTime)
        try container.encode(companion, forKey: .companion)
        try container.encodeIfPresent(arrivalPoint, forKey: .arrivalPoint)
        try container.encode(stayArea, forKey: .stayArea)
        try container.encode(transportMode, forKey: .transportMode)
        try container.encode(iconicPreference, forKey: .iconicPreference)
        try container.encode(budget, forKey: .budget)
        try container.encode(pace, forKey: .pace)
        try container.encode(mustVisitPlaces, forKey: .mustVisitPlaces)
        try container.encode(status, forKey: .status)
    }
}

struct VisitedRegionInsertData: Encodable {
    var userId: String
    var countryCode: String
    var status: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case countryCode = "country_code"
        case status
    }
}

struct UserStampInsertData: Encodable {
    var userId: String
    var countryCode: String
    var stampDate: String
    var tripId: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case countryCode = "country_code"
        case stampDate = "stamp_date"
        case tripId = "trip_id"
    }
}

/// Supabase database service
actor SupabaseService {
    static let shared = SupabaseService()

    private var client: SupabaseClient {
        AppConfig.shared.supabaseClient
    }

    private init() {}

    // MARK: - Trips

    func fetchTrips(userId: String, limit: Int = 20, offset: Int = 0) async throws -> [Trip] {
        try await client
            .from("trips")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
    }

    func fetchTrip(id: String) async throws -> Trip {
        try await client
            .from("trips")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func fetchTripDays(tripId: String) async throws -> [TripDay] {
        // Single query with nested join — no N+1 problem
        let days: [TripDay] = try await client
            .from("trip_days")
            .select("*, trip_activities(*)")
            .eq("trip_id", value: tripId)
            .order("day_number", ascending: true)
            .execute()
            .value

        return days
    }

    func createTrip(_ trip: TripCreateRequest, userId: String) async throws -> Trip {
        let insertData = TripInsertData(
            userId: userId,
            destinationCities: trip.destinationCities,
            durationNights: trip.durationNights,
            startDate: trip.startDate,
            arrivalTime: trip.arrivalTime,
            departureTime: trip.departureTime,
            companion: trip.companion.rawValue,
            arrivalPoint: trip.arrivalPoint,
            stayArea: trip.stayArea.rawValue,
            transportMode: trip.transportMode.rawValue,
            iconicPreference: trip.iconicPreference.rawValue,
            budget: trip.budget.rawValue,
            pace: trip.pace.rawValue,
            mustVisitPlaces: trip.mustVisitPlaces,
            status: TripStatus.draft.rawValue
        )

        return try await client
            .from("trips")
            .insert(insertData)
            .select()
            .single()
            .execute()
            .value
    }

    func updateTrip(id: String, updates: [String: AnyJSON]) async throws {
        try await client
            .from("trips")
            .update(updates)
            .eq("id", value: id)
            .execute()
    }

    private struct IdOnly: Codable { let id: String }

    func deleteTrip(id: String) async throws {
        // CASCADE handles trip_days → trip_activities automatically
        // Just delete the trip — foreign keys with ON DELETE CASCADE do the rest
        try await client
            .from("trips")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Trip Days

    func saveTripDays(tripId: String, days: [TripDay]) async throws {
        // First, delete existing days for this trip
        try await client
            .from("trip_days")
            .delete()
            .eq("trip_id", value: tripId)
            .execute()

        // Insert each day and its activities
        for day in days {
            // Insert the day
            let dayInsert: [String: AnyJSON] = [
                "trip_id": .string(tripId),
                "day_number": .integer(day.dayNumber),
                "date": day.date != nil ? .string(ISO8601DateFormatter().string(from: day.date!)) : .null,
                "title": day.title != nil ? .string(day.title!) : .null,
                "summary": day.summary != nil ? .string(day.summary!) : .null,
                "weather": day.weather != nil ? encodeWeather(day.weather!) : .null
            ]

            let insertedDay: [String: AnyJSON] = try await client
                .from("trip_days")
                .insert(dayInsert)
                .select("id")
                .single()
                .execute()
                .value

            guard let dayIdValue = insertedDay["id"],
                  case .string(let dayId) = dayIdValue else {
                continue
            }

            // Insert activities for this day
            if let activities = day.activities {
                for (index, activity) in activities.enumerated() {
                    let activityInsert: [String: AnyJSON] = [
                        "day_id": .string(dayId),
                        "slot": .string(activity.slot.rawValue),
                        "name": .string(activity.name),
                        "description": activity.description != nil ? .string(activity.description!) : .null,
                        "address": activity.address != nil ? .string(activity.address!) : .null,
                        "latitude": activity.latitude != nil ? .double(activity.latitude!) : .null,
                        "longitude": activity.longitude != nil ? .double(activity.longitude!) : .null,
                        "duration": activity.duration != nil ? .integer(activity.duration!) : .null,
                        "start_time": activity.startTime != nil ? .string(activity.startTime!) : .null,
                        "end_time": activity.endTime != nil ? .string(activity.endTime!) : .null,
                        "cost": activity.cost != nil ? .string(activity.cost!) : .null,
                        "tips": activity.tips != nil ? .string(activity.tips!) : .null,
                        "sort_order": .integer(index)
                    ]

                    try await client
                        .from("trip_activities")
                        .insert(activityInsert)
                        .execute()
                }
            }
        }

        // Update trip status to completed
        try await client
            .from("trips")
            .update(["status": AnyJSON.string("completed")])
            .eq("id", value: tripId)
            .execute()
    }

    private func encodeWeather(_ weather: DayWeather) -> AnyJSON {
        let dict: [String: AnyJSON] = [
            "condition": .string(weather.condition),
            "condition_text": .string(weather.conditionText),
            "temperature_max": .double(weather.temperatureMax),
            "temperature_min": .double(weather.temperatureMin),
            "precipitation_chance": .integer(weather.precipitationChance),
            "humidity": .integer(weather.humidity),
            "wind_speed": .double(weather.windSpeed)
        ]
        return .object(dict)
    }

    // MARK: - Visited Regions

    func fetchVisitedRegions(userId: String) async throws -> [VisitedRegion] {
        try await client
            .from("visited_regions")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    func addVisitedRegion(userId: String, countryCode: String, status: VisitStatus) async throws -> VisitedRegion {
        let insertData = VisitedRegionInsertData(
            userId: userId,
            countryCode: countryCode,
            status: status.rawValue
        )

        return try await client
            .from("visited_regions")
            .insert(insertData)
            .select()
            .single()
            .execute()
            .value
    }

    func updateVisitedRegion(id: String, status: VisitStatus) async throws {
        try await client
            .from("visited_regions")
            .update(["status": AnyJSON.string(status.rawValue)])
            .eq("id", value: id)
            .execute()
    }

    func deleteVisitedRegion(id: String) async throws {
        try await client
            .from("visited_regions")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - User Stamps

    func fetchUserStamps(userId: String) async throws -> [UserStamp] {
        try await client
            .from("user_stamps")
            .select()
            .eq("user_id", value: userId)
            .order("stamp_date", ascending: false)
            .execute()
            .value
    }

    func addUserStamp(userId: String, countryCode: String, tripId: String? = nil) async throws -> UserStamp {
        let insertData = UserStampInsertData(
            userId: userId,
            countryCode: countryCode,
            stampDate: ISO8601DateFormatter().string(from: Date()),
            tripId: tripId
        )

        return try await client
            .from("user_stamps")
            .insert(insertData)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Country Stamps

    func fetchCountryStamps() async throws -> [CountryStamp] {
        try await client
            .from("country_stamps")
            .select("*, variants:stamp_variants(*)")
            .eq("is_active", value: true)
            .execute()
            .value
    }

    // MARK: - Achievements

    func fetchAchievements() async throws -> [AchievementStamp] {
        try await client
            .from("achievement_stamps")
            .select()
            .eq("is_active", value: true)
            .execute()
            .value
    }

    func fetchUserAchievements(userId: String) async throws -> [UserAchievement] {
        try await client
            .from("user_achievements")
            .select("*, achievement:achievement_stamps(*)")
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    // MARK: - Cities

    func searchCities(query: String, limit: Int = 20) async throws -> [City] {
        try await client
            .from("cities")
            .select()
            .ilike("name", pattern: "%\(query)%")
            .limit(limit)
            .execute()
            .value
    }

    func fetchVisitedCities(userId: String) async throws -> [UserVisitedCity] {
        try await client
            .from("user_visited_cities")
            .select("*, city:cities(*)")
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    // MARK: - Profile

    func fetchProfile(userId: String) async throws -> UserProfile {
        try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }

    func updateProfile(userId: String, updates: [String: AnyJSON]) async throws {
        try await client
            .from("profiles")
            .update(updates)
            .eq("id", value: userId)
            .execute()
    }

    /// Profil yoksa oluştur, varsa güncelle (upsert)
    func upsertProfile(userId: String, email: String?, fullName: String?) async throws {
        var data: [String: AnyJSON] = [
            "id": .string(userId),
        ]

        if let email = email, !email.isEmpty {
            data["email"] = .string(email)
        }
        if let fullName = fullName, !fullName.isEmpty {
            data["display_name"] = .string(fullName)
        }

        try await client
            .from("profiles")
            .upsert(data, onConflict: "id")
            .execute()
    }

    /// Kullanıcı kredilerini başlat (yoksa oluştur)
    func initializeUserCredits(userId: String) async throws {
        // Önce mevcut kredi var mı kontrol et
        let existing: [UserCredits] = try await client
            .from("user_credits")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        if existing.isEmpty {
            // Yeni kullanıcı — hoşgeldin kredisi ver
            let insertData: [String: AnyJSON] = [
                "user_id": .string(userId),
                "balance": .integer(2),
                "lifetime_earned": .integer(2),
                "lifetime_spent": .integer(0)
            ]

            try await client
                .from("user_credits")
                .insert(insertData)
                .execute()

            // İşlem logu
            let transactionData: [String: AnyJSON] = [
                "user_id": .string(userId),
                "amount": .integer(2),
                "balance_after": .integer(2),
                "type": .string("welcome_bonus"),
                "description": .string("Hoşgeldin kredisi")
            ]

            try await client
                .from("credit_transactions")
                .insert(transactionData)
                .execute()
        }
    }

    // MARK: - Premium

    private struct PremiumCheck: Codable {
        let isPremium: Bool
        let premiumExpiresAt: Date?

        enum CodingKeys: String, CodingKey {
            case isPremium = "is_premium"
            case premiumExpiresAt = "premium_expires_at"
        }
    }

    func checkPremiumStatus(userId: String) async throws -> Bool {
        let result: PremiumCheck = try await client
            .from("profiles")
            .select("is_premium, premium_expires_at")
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        if result.isPremium {
            if let expiresAt = result.premiumExpiresAt {
                return expiresAt > Date()
            }
            return true
        }
        return false
    }

    // MARK: - Credits

    /// Kullanıcının kredi bakiyesini getir
    func fetchUserCredits(userId: String) async throws -> UserCredits? {
        let results: [UserCredits] = try await client
            .from("user_credits")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return results.first
    }

    /// Kullanıcının kredi işlem geçmişini getir
    func fetchCreditTransactions(userId: String, limit: Int = 50) async throws -> [CreditTransaction] {
        try await client
            .from("credit_transactions")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    // MARK: - Referral

    /// Kullanıcının referans kodunu getir
    func fetchReferralCode(userId: String) async throws -> ReferralCode? {
        let results: [ReferralCode] = try await client
            .from("referral_codes")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return results.first
    }

    /// Yeni referans kodu oluştur
    func insertReferralCode(_ data: [String: AnyJSON]) async throws {
        try await client
            .from("referral_codes")
            .insert(data)
            .execute()
    }

    /// Referans kodunu doğrula
    func validateReferralCode(_ code: String) async throws -> Bool {
        let results: [ReferralCode] = try await client
            .from("referral_codes")
            .select()
            .eq("code", value: code.uppercased())
            .eq("is_active", value: true)
            .execute()
            .value
        return !results.isEmpty
    }

    /// Referans geçmişini getir
    func fetchReferralHistory(userId: String) async throws -> [ReferralHistory] {
        try await client
            .from("referral_history")
            .select()
            .eq("referrer_user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Destinations (Explore Page)

    func fetchDestinations(category: String, season: String? = nil) async throws -> [DestinationDB] {
        let destinations: [DestinationDB] = try await client
            .from("destinations")
            .select()
            .eq("category", value: category)
            .eq("is_active", value: true)
            .order("display_order", ascending: true)
            .execute()
            .value

        // Filter by season locally if needed
        if let season = season {
            return destinations.filter { $0.season == season || $0.season == "all" }
        }

        return destinations
    }

    func fetchFeaturedDestination() async throws -> DestinationDB? {
        // First try to get by is_featured flag
        let featured: [DestinationDB] = try await client
            .from("destinations")
            .select()
            .eq("is_featured", value: true)
            .eq("is_active", value: true)
            .limit(1)
            .execute()
            .value

        if let dest = featured.first {
            return dest
        }

        // Fallback to category = "featured"
        let destinations: [DestinationDB] = try await client
            .from("destinations")
            .select()
            .eq("category", value: "featured")
            .eq("is_active", value: true)
            .limit(1)
            .execute()
            .value

        return destinations.first
    }

    func fetchHiddenGems(limit: Int = 10) async throws -> [DestinationDB] {
        try await client
            .from("destinations")
            .select()
            .eq("category", value: "hidden_gem")  // GPT kategorisi
            .eq("is_active", value: true)
            .order("trend_percentage", ascending: true) // Less trending = more hidden
            .limit(limit)
            .execute()
            .value
    }

    func fetchAllDestinations() async throws -> [String: [DestinationDB]] {
        let all: [DestinationDB] = try await client
            .from("destinations")
            .select()
            .eq("is_active", value: true)
            .order("display_order", ascending: true)
            .execute()
            .value

        // Group by category
        var grouped: [String: [DestinationDB]] = [:]
        for dest in all {
            if grouped[dest.category] == nil {
                grouped[dest.category] = []
            }
            grouped[dest.category]?.append(dest)
        }
        return grouped
    }

    func fetchTravelQuotes() async throws -> [TravelQuoteDB] {
        try await client
            .from("travel_quotes")
            .select()
            .eq("is_active", value: true)
            .execute()
            .value
    }

    // MARK: - Events (Explore Page)

    func fetchEvents() async throws -> [EventDB] {
        try await client
            .from("events")
            .select()
            .eq("is_active", value: true)
            .order("event_date", ascending: true)
            .execute()
            .value
    }

    func fetchUpcomingEvents(limit: Int = 10) async throws -> [EventDB] {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        let events: [EventDB] = try await client
            .from("events")
            .select()
            .eq("is_active", value: true)
            .gte("event_date", value: today)
            .order("event_date", ascending: true)
            .limit(limit)
            .execute()
            .value
        return events
    }

}

// MARK: - Destination Database Model
struct DestinationDB: Codable {
    let id: String
    let name: String
    let country: String
    let description: String?
    let imageUrl: String
    let rating: Double
    let trendPercentage: Int
    let seasonalTag: String?
    let primaryColor: String
    let secondaryColor: String
    let category: String
    let season: String?
    let displayOrder: Int?
    let isActive: Bool?
    let isFeatured: Bool?
    let searchKeywords: [String]?
    let createdAt: Date?
    let updatedAt: Date?
    // Localization fields (Turkish)
    let nameTr: String?
    let descriptionTr: String?
    let countryTr: String?
    let seasonalTagTr: String?

    enum CodingKeys: String, CodingKey {
        case id, name, country, description, rating, category, season
        case imageUrl = "image_url"
        case trendPercentage = "trend_percentage"
        case seasonalTag = "seasonal_tag"
        case primaryColor = "primary_color"
        case secondaryColor = "secondary_color"
        case displayOrder = "display_order"
        case isActive = "is_active"
        case isFeatured = "is_featured"
        case searchKeywords = "search_keywords"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case nameTr = "name_tr"
        case descriptionTr = "description_tr"
        case countryTr = "country_tr"
        case seasonalTagTr = "seasonal_tag_tr"
    }
}

// MARK: - Travel Quote Database Model
struct TravelQuoteDB: Codable {
    let id: String
    let quote: String
    let author: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, quote, author
        case isActive = "is_active"
    }
}

// MARK: - Event Database Model
struct EventDB: Codable {
    let id: String
    let name: String
    let nameTr: String?
    let description: String?
    let descriptionTr: String?
    let city: String?
    let country: String?
    let countryTr: String?
    let venue: String?
    let eventDate: String?
    let endDate: String?
    let category: String?
    let imageUrl: String?
    let ticketUrl: String?
    let ticketmasterId: String?
    let isActive: Bool?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, city, country, venue, category
        case nameTr = "name_tr"
        case descriptionTr = "description_tr"
        case countryTr = "country_tr"
        case eventDate = "event_date"
        case endDate = "end_date"
        case imageUrl = "image_url"
        case ticketUrl = "ticket_url"
        case ticketmasterId = "ticketmaster_id"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

// MARK: - EventDB Extension
extension EventDB {
    var localizedName: String {
        if LocalizationManager.shared.currentLanguage == "tr", let tr = nameTr, !tr.isEmpty { return tr }
        return name
    }

    var localizedDescription: String {
        if LocalizationManager.shared.currentLanguage == "tr", let tr = descriptionTr, !tr.isEmpty { return tr }
        return description ?? ""
    }

    var localizedCountry: String {
        if LocalizationManager.shared.currentLanguage == "tr", let tr = countryTr, !tr.isEmpty { return tr }
        return GeoLocalizer.localizeCountry(country ?? "")
    }

    var formattedDate: String {
        guard let dateStr = eventDate else { return "" }
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = inputFormatter.date(from: dateStr) else { return dateStr }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d MMM yyyy"
        outputFormatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage == "tr" ? "tr_TR" : "en_US")
        return outputFormatter.string(from: date)
    }

    var formattedDateRange: String {
        guard let startStr = eventDate else { return "" }
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let startDate = inputFormatter.date(from: startStr) else { return startStr }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage == "tr" ? "tr_TR" : "en_US")

        if let endStr = endDate, endStr != startStr,
           let endDate = inputFormatter.date(from: endStr) {
            outputFormatter.dateFormat = "d MMM"
            let start = outputFormatter.string(from: startDate)
            outputFormatter.dateFormat = "d MMM yyyy"
            let end = outputFormatter.string(from: endDate)
            return "\(start) - \(end)"
        }

        outputFormatter.dateFormat = "d MMM yyyy"
        return outputFormatter.string(from: startDate)
    }

    // Allowed event categories (only these 3)
    static let allowedCategories: Set<String> = ["music", "sports", "festival"]

    var isAllowedCategory: Bool {
        Self.allowedCategories.contains((category ?? "").lowercased())
    }

    var categoryIcon: String {
        switch (category ?? "").lowercased() {
        case "music": return "music.note"
        case "sports": return "sportscourt.fill"
        case "festival": return "party.popper.fill"
        default: return "music.note" // unreachable — filtered by isAllowedCategory
        }
    }

    var categoryColor: Color {
        switch (category ?? "").lowercased() {
        case "music": return Color(hex: "E91E63")
        case "sports": return Color(hex: "4CAF50")
        case "festival": return Color(hex: "FF5722")
        default: return Color(hex: "E91E63") // unreachable — filtered by isAllowedCategory
        }
    }

    var isUpcoming: Bool {
        guard let dateStr = eventDate else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: dateStr) else { return false }
        return date >= Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - EventDB ImageURLProvider
extension EventDB: ImageURLProvider {
    var imageURLString: String { imageUrl ?? "" }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
