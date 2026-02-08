import Foundation

// MARK: - Date Formatter Helper
private let supabaseDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

private let supabaseTimestampFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private let supabaseTimestampFormatterNoFraction: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

func parseSupabaseDate(_ string: String) -> Date? {
    // Try date-only format first (2026-02-05)
    if let date = supabaseDateFormatter.date(from: string) {
        return date
    }
    // Try full ISO8601 with fractional seconds
    if let date = supabaseTimestampFormatter.date(from: string) {
        return date
    }
    // Try full ISO8601 without fractional seconds
    if let date = supabaseTimestampFormatterNoFraction.date(from: string) {
        return date
    }
    return nil
}

// MARK: - Trip Model
struct Trip: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    var destinationCities: [String]
    var durationNights: Int
    var startDate: Date?
    var arrivalTime: String?
    var departureTime: String?
    var companion: CompanionType
    var arrivalPoint: String?
    var stayArea: StayAreaType
    var transportMode: TransportMode
    var iconicPreference: IconicPreference
    var budget: BudgetType
    var pace: PaceType
    var mustVisitPlaces: [String]
    var title: String?
    var status: TripStatus
    let createdAt: Date
    var updatedAt: Date

    // Joined data
    var days: [TripDay]?
    var weather: [DailyForecast]?

    enum CodingKeys: String, CodingKey {
        case id
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
        case title
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case days
        case weather
    }

    // MARK: - Memberwise Initializer
    init(
        id: String,
        userId: String,
        destinationCities: [String],
        durationNights: Int,
        startDate: Date? = nil,
        arrivalTime: String? = nil,
        departureTime: String? = nil,
        companion: CompanionType,
        arrivalPoint: String? = nil,
        stayArea: StayAreaType,
        transportMode: TransportMode,
        iconicPreference: IconicPreference,
        budget: BudgetType,
        pace: PaceType,
        mustVisitPlaces: [String] = [],
        title: String? = nil,
        status: TripStatus,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        days: [TripDay]? = nil,
        weather: [DailyForecast]? = nil
    ) {
        self.id = id
        self.userId = userId
        self.destinationCities = destinationCities
        self.durationNights = durationNights
        self.startDate = startDate
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
        self.companion = companion
        self.arrivalPoint = arrivalPoint
        self.stayArea = stayArea
        self.transportMode = transportMode
        self.iconicPreference = iconicPreference
        self.budget = budget
        self.pace = pace
        self.mustVisitPlaces = mustVisitPlaces
        self.title = title
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.days = days
        self.weather = weather
    }

    // MARK: - Decoder Initializer
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        destinationCities = try container.decode([String].self, forKey: .destinationCities)
        durationNights = try container.decode(Int.self, forKey: .durationNights)

        // Custom date parsing for startDate
        if let dateString = try container.decodeIfPresent(String.self, forKey: .startDate) {
            startDate = parseSupabaseDate(dateString)
        } else {
            startDate = nil
        }

        arrivalTime = try container.decodeIfPresent(String.self, forKey: .arrivalTime)
        departureTime = try container.decodeIfPresent(String.self, forKey: .departureTime)
        companion = try container.decode(CompanionType.self, forKey: .companion)
        arrivalPoint = try container.decodeIfPresent(String.self, forKey: .arrivalPoint)
        stayArea = try container.decode(StayAreaType.self, forKey: .stayArea)
        transportMode = try container.decode(TransportMode.self, forKey: .transportMode)
        iconicPreference = try container.decode(IconicPreference.self, forKey: .iconicPreference)
        budget = try container.decode(BudgetType.self, forKey: .budget)
        pace = try container.decode(PaceType.self, forKey: .pace)
        mustVisitPlaces = try container.decodeIfPresent([String].self, forKey: .mustVisitPlaces) ?? []
        title = try container.decodeIfPresent(String.self, forKey: .title)
        status = try container.decode(TripStatus.self, forKey: .status)

        // Custom date parsing for timestamps
        if let createdString = try container.decodeIfPresent(String.self, forKey: .createdAt),
           let date = parseSupabaseDate(createdString) {
            createdAt = date
        } else {
            createdAt = Date()
        }

        if let updatedString = try container.decodeIfPresent(String.self, forKey: .updatedAt),
           let date = parseSupabaseDate(updatedString) {
            updatedAt = date
        } else {
            updatedAt = Date()
        }

        days = try container.decodeIfPresent([TripDay].self, forKey: .days)
        weather = try container.decodeIfPresent([DailyForecast].self, forKey: .weather)
    }
}

// MARK: - Trip Enums
enum CompanionType: String, Codable, CaseIterable {
    case solo
    case friends
    case family
    case couple

    var displayName: String {
        switch self {
        case .solo: return "companion.solo".localized
        case .friends: return "companion.friends".localized
        case .family: return "companion.family".localized
        case .couple: return "companion.couple".localized
        }
    }

    var icon: String {
        switch self {
        case .solo: return "person.fill"
        case .friends: return "person.2.fill"
        case .family: return "figure.2.and.child.holdinghands"
        case .couple: return "heart.fill"
        }
    }
}

enum StayAreaType: String, Codable, CaseIterable {
    case center
    case beach
    case downtown
    case unknown

    var displayName: String {
        switch self {
        case .center: return "stayArea.center".localized
        case .beach: return "stayArea.beach".localized
        case .downtown: return "stayArea.downtown".localized
        case .unknown: return "stayArea.unknown".localized
        }
    }
}

enum TransportMode: String, Codable, CaseIterable {
    case walking
    case publicTransport = "public_transport"
    case taxi
    case rentalCar = "rental_car"
    case mixed

    var displayName: String {
        switch self {
        case .walking: return "transport.walking".localized
        case .publicTransport: return "transport.publicTransport".localized
        case .taxi: return "transport.taxi".localized
        case .rentalCar: return "transport.rentalCar".localized
        case .mixed: return "transport.mixed".localized
        }
    }

    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .publicTransport: return "bus.fill"
        case .taxi: return "car.fill"
        case .rentalCar: return "car.2.fill"
        case .mixed: return "arrow.triangle.branch"
        }
    }
}

enum IconicPreference: String, Codable, CaseIterable {
    case essential
    case optional
    case avoid

    var displayName: String {
        switch self {
        case .essential: return "iconic.essential".localized
        case .optional: return "iconic.optional".localized
        case .avoid: return "iconic.avoid".localized
        }
    }
}

enum BudgetType: String, Codable, CaseIterable {
    case budget
    case moderate
    case luxury
    case flexible

    var displayName: String {
        switch self {
        case .budget: return "budgetType.budget".localized
        case .moderate: return "budgetType.moderate".localized
        case .luxury: return "budgetType.luxury".localized
        case .flexible: return "budgetType.flexible".localized
        }
    }

    var icon: String {
        switch self {
        case .budget: return "dollarsign"
        case .moderate: return "dollarsign.circle"
        case .luxury: return "dollarsign.circle.fill"
        case .flexible: return "questionmark.circle"
        }
    }
}

enum PaceType: String, Codable, CaseIterable {
    case relaxed
    case moderate
    case intensive

    var displayName: String {
        switch self {
        case .relaxed: return "paceType.relaxed".localized
        case .moderate: return "paceType.moderate".localized
        case .intensive: return "paceType.intensive".localized
        }
    }
}

enum TripStatus: String, Codable, CaseIterable {
    case draft
    case generating
    case completed
    case failed

    var displayName: String {
        switch self {
        case .draft: return "tripStatus.draft".localized
        case .generating: return "tripStatus.generating".localized
        case .completed: return "tripStatus.completed".localized
        case .failed: return "tripStatus.failed".localized
        }
    }
}

// MARK: - Trip Day
struct TripDay: Codable, Identifiable, Equatable {
    let id: String
    let tripId: String
    var dayNumber: Int
    var date: Date?
    var title: String?
    var summary: String?
    var activities: [TripActivity]?
    var weather: DayWeather?

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case dayNumber = "day_number"
        case date
        case title
        case summary
        case activities
        case tripActivities = "trip_activities"
        case weather
    }

    // Memberwise init
    init(id: String, tripId: String, dayNumber: Int, date: Date? = nil, title: String? = nil, summary: String? = nil, activities: [TripActivity]? = nil, weather: DayWeather? = nil) {
        self.id = id
        self.tripId = tripId
        self.dayNumber = dayNumber
        self.date = date
        self.title = title
        self.summary = summary
        self.activities = activities
        self.weather = weather
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        tripId = try container.decode(String.self, forKey: .tripId)
        dayNumber = try container.decode(Int.self, forKey: .dayNumber)

        // Custom date parsing
        if let dateString = try container.decodeIfPresent(String.self, forKey: .date) {
            date = parseSupabaseDate(dateString)
        } else {
            date = nil
        }

        title = try container.decodeIfPresent(String.self, forKey: .title)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)

        // Try both keys for activities (from Supabase it's "trip_activities")
        if let acts = try container.decodeIfPresent([TripActivity].self, forKey: .tripActivities) {
            activities = acts
        } else {
            activities = try container.decodeIfPresent([TripActivity].self, forKey: .activities)
        }

        weather = try container.decodeIfPresent(DayWeather.self, forKey: .weather)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tripId, forKey: .tripId)
        try container.encode(dayNumber, forKey: .dayNumber)
        try container.encodeIfPresent(date, forKey: .date)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(activities, forKey: .activities)
        try container.encodeIfPresent(weather, forKey: .weather)
    }
}

// MARK: - Day Weather (for trip planning)
struct DayWeather: Codable, Equatable {
    var condition: String          // sunny, cloudy, rain, etc.
    var conditionText: String      // "Güneşli", "Bulutlu", etc.
    var temperatureMax: Double
    var temperatureMin: Double
    var precipitationChance: Int   // Yağış olasılığı %
    var humidity: Int
    var windSpeed: Double
    var icon: String?              // SF Symbol name

    enum CodingKeys: String, CodingKey {
        case condition
        case conditionText = "condition_text"
        case temperatureMax = "temperature_max"
        case temperatureMin = "temperature_min"
        case precipitationChance = "precipitation_chance"
        case humidity
        case windSpeed = "wind_speed"
        case icon
    }

    var sfSymbol: String {
        switch condition {
        case "sunny": return "sun.max.fill"
        case "partly_cloudy": return "cloud.sun.fill"
        case "cloudy": return "cloud.fill"
        case "rain", "light_rain": return "cloud.rain.fill"
        case "heavy_rain": return "cloud.heavyrain.fill"
        case "thunderstorm": return "cloud.bolt.rain.fill"
        case "snow": return "cloud.snow.fill"
        case "fog": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
}

// MARK: - Trip Activity
struct TripActivity: Codable, Identifiable, Equatable {
    let id: String
    let dayId: String
    var slot: ActivitySlot
    var name: String
    var description: String?
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var duration: Int? // in minutes
    var startTime: String? // "09:00" format
    var endTime: String?   // "11:00" format
    var cost: String?
    var tips: String?
    var photoUrl: String?
    var isCompleted: Bool

    // Computed property for time range display
    var timeRangeDisplay: String? {
        if let start = startTime, let end = endTime {
            return "\(start) - \(end)"
        } else if let start = startTime {
            return start
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case dayId = "day_id"
        case slot
        case name
        case description
        case address
        case latitude
        case longitude
        case duration
        case startTime = "start_time"
        case endTime = "end_time"
        case cost
        case tips
        case photoUrl = "photo_url"
        case isCompleted = "is_completed"
    }

    // Memberwise init
    init(id: String, dayId: String, slot: ActivitySlot, name: String, description: String? = nil, address: String? = nil, latitude: Double? = nil, longitude: Double? = nil, duration: Int? = nil, startTime: String? = nil, endTime: String? = nil, cost: String? = nil, tips: String? = nil, photoUrl: String? = nil, isCompleted: Bool = false) {
        self.id = id
        self.dayId = dayId
        self.slot = slot
        self.name = name
        self.description = description
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime
        self.cost = cost
        self.tips = tips
        self.photoUrl = photoUrl
        self.isCompleted = isCompleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        dayId = try container.decode(String.self, forKey: .dayId)
        slot = try container.decode(ActivitySlot.self, forKey: .slot)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        cost = try container.decodeIfPresent(String.self, forKey: .cost)
        tips = try container.decodeIfPresent(String.self, forKey: .tips)
        photoUrl = try container.decodeIfPresent(String.self, forKey: .photoUrl)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
    }
}

enum ActivitySlot: String, Codable, CaseIterable {
    case morning
    case noon
    case afternoon
    case evening

    var displayName: String {
        switch self {
        case .morning: return "activitySlot.morning".localized
        case .noon: return "activitySlot.noon".localized
        case .afternoon: return "activitySlot.afternoon".localized
        case .evening: return "activitySlot.evening".localized
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .noon: return "sun.max.fill"
        case .afternoon: return "sun.haze.fill"
        case .evening: return "moon.stars.fill"
        }
    }

    var timeRange: String {
        switch self {
        case .morning: return "08:00 - 12:00"
        case .noon: return "12:00 - 14:00"
        case .afternoon: return "14:00 - 18:00"
        case .evening: return "18:00 - 22:00"
        }
    }
}

// MARK: - Trip Create Request
struct TripCreateRequest: Codable {
    var destinationCities: [String]
    var durationNights: Int
    var startDate: Date?
    var arrivalTime: String?
    var departureTime: String?
    var companion: CompanionType
    var arrivalPoint: String?
    var stayArea: StayAreaType
    var transportMode: TransportMode
    var iconicPreference: IconicPreference
    var budget: BudgetType
    var pace: PaceType
    var mustVisitPlaces: [String]

    enum CodingKeys: String, CodingKey {
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
    }
}
