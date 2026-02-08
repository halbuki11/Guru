import Foundation

/// Ticketmaster Discovery API v2 Service
/// Docs: https://developer.ticketmaster.com/products-and-docs/apis/discovery-api/v2/
/// Base: https://app.ticketmaster.com/discovery/v2/events.json?apikey={apikey}
actor TicketmasterService {
    static let shared = TicketmasterService()

    private let baseURL = "https://app.ticketmaster.com/discovery/v2"
    private let apiKey: String

    private init() {
        apiKey = AppConfig.shared.ticketmasterApiKey
    }

    // MARK: - Public API

    /// Fetch events for a trip's destination cities and date range
    func fetchEventsForTrip(cities: [String], startDate: Date?, durationNights: Int) async throws -> [TicketmasterEvent] {
        guard !apiKey.isEmpty && apiKey != "your-ticketmaster-api-key" else {
            return []
        }

        let calendar = Calendar.current
        let start = startDate ?? Date()
        let end = calendar.date(byAdding: .day, value: durationNights, to: start) ?? start

        var allEvents: [TicketmasterEvent] = []

        for city in cities {
            do {
                // Try with countryCode if we can detect it
                let countryCode = detectCountryCode(for: city)
                let events = try await searchEvents(
                    city: city,
                    countryCode: countryCode,
                    startDate: start,
                    endDate: end
                )
                allEvents.append(contentsOf: events)
            } catch {
                // Silent
            }
        }

        // Remove duplicates by id
        var seen = Set<String>()
        allEvents = allEvents.filter { event in
            guard !seen.contains(event.id) else { return false }
            seen.insert(event.id)
            return true
        }

        // Sort by date
        allEvents.sort { ($0.localDate ?? "") < ($1.localDate ?? "") }

        return allEvents
    }

    // MARK: - API Call

    /// GET /discovery/v2/events.json
    /// Docs: https://developer.ticketmaster.com/products-and-docs/apis/discovery-api/v2/
    private func searchEvents(
        city: String,
        countryCode: String? = nil,
        startDate: Date,
        endDate: Date,
        size: Int = 50
    ) async throws -> [TicketmasterEvent] {
        // Format: YYYY-MM-DDTHH:mm:ssZ (ISO 8601)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        var endComponents = DateComponents()
        endComponents.day = 1
        endComponents.second = -1
        let endOfDay = calendar.date(byAdding: endComponents, to: calendar.startOfDay(for: endDate)) ?? endDate

        let startStr = isoFormatter.string(from: startOfDay)
        let endStr = isoFormatter.string(from: endOfDay)

        var components = URLComponents(string: "\(baseURL)/events.json")!
        var queryItems = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "city", value: city),
            URLQueryItem(name: "startDateTime", value: startStr),
            URLQueryItem(name: "endDateTime", value: endStr),
            URLQueryItem(name: "sort", value: "date,asc"),
            URLQueryItem(name: "size", value: "\(size)"),
            URLQueryItem(name: "locale", value: "*")
        ]

        // Add countryCode if detected
        if let countryCode = countryCode {
            queryItems.append(URLQueryItem(name: "countryCode", value: countryCode))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw TicketmasterError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TicketmasterError.invalidResponse
        }

        // Handle rate limit (429)
        if httpResponse.statusCode == 429 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return try await searchEvents(city: city, countryCode: countryCode, startDate: startDate, endDate: endDate, size: size)
        }

        guard httpResponse.statusCode == 200 else {
            throw TicketmasterError.apiError(statusCode: httpResponse.statusCode)
        }

        return parseResponse(data)
    }

    // MARK: - Response Parser

    /// Parse _embedded.events[] from API response
    private func parseResponse(_ data: Data) -> [TicketmasterEvent] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let embedded = json["_embedded"] as? [String: Any],
              let eventsArray = embedded["events"] as? [[String: Any]] else {
            // No events found — this is normal for cities with no upcoming events
            return []
        }

        return eventsArray.compactMap { parseEvent($0) }
    }

    private func parseEvent(_ dict: [String: Any]) -> TicketmasterEvent? {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String else { return nil }

        // Skip test events
        if dict["test"] as? Bool == true { return nil }

        let url = dict["url"] as? String

        // Parse dates — dates.start.localDate, dates.start.localTime
        var localDate: String?
        var localTime: String?
        var statusCode: String?
        if let dates = dict["dates"] as? [String: Any] {
            if let start = dates["start"] as? [String: Any] {
                localDate = start["localDate"] as? String
                localTime = start["localTime"] as? String
            }
            // dates.status.code — "onsale", "offsale", "cancelled", "postponed", "rescheduled"
            if let status = dates["status"] as? [String: Any] {
                statusCode = status["code"] as? String
            }
        }

        // Skip cancelled or postponed events
        if let status = statusCode?.lowercased() {
            if status == "cancelled" || status == "postponed" {
                return nil
            }
        }

        // Parse venue — _embedded.venues[0]
        var venueName: String?
        var venueCity: String?
        if let eventEmbedded = dict["_embedded"] as? [String: Any],
           let venues = eventEmbedded["venues"] as? [[String: Any]],
           let firstVenue = venues.first {
            venueName = firstVenue["name"] as? String
            if let city = firstVenue["city"] as? [String: Any] {
                venueCity = city["name"] as? String
            }
        }

        // Parse classification — classifications[0].segment.name, classifications[0].genre.name
        var category: String?
        var genre: String?
        if let classifications = dict["classifications"] as? [[String: Any]],
           let first = classifications.first {
            if let segment = first["segment"] as? [String: Any] {
                category = segment["name"] as? String
            }
            if let genreObj = first["genre"] as? [String: Any] {
                genre = genreObj["name"] as? String
            }
        }

        // Parse image — prefer 16:9 ratio with ≥500px width
        var imageUrl: String?
        if let images = dict["images"] as? [[String: Any]] {
            let preferred = images.first(where: {
                let ratio = $0["ratio"] as? String
                let width = $0["width"] as? Int ?? 0
                return ratio == "16_9" && width >= 500
            })
            imageUrl = (preferred ?? images.first)?["url"] as? String
        }

        // Parse price range — priceRanges[0].min, max, currency
        var priceRange: String?
        if let priceRanges = dict["priceRanges"] as? [[String: Any]],
           let first = priceRanges.first {
            let min = first["min"] as? Double
            let max = first["max"] as? Double
            let currency = first["currency"] as? String ?? ""
            if let min = min, let max = max {
                priceRange = "\(Int(min))-\(Int(max)) \(currency)"
            } else if let min = min {
                priceRange = "\(Int(min))+ \(currency)"
            }
        }

        return TicketmasterEvent(
            id: id,
            name: name,
            url: url,
            localDate: localDate,
            localTime: localTime,
            venueName: venueName,
            venueCity: venueCity,
            category: category,
            genre: genre,
            imageUrl: imageUrl,
            priceRange: priceRange
        )
    }

    // MARK: - Country Code Detection

    /// Map common destination cities to ISO country codes for better API results
    private func detectCountryCode(for city: String) -> String? {
        let lowered = city.lowercased().trimmingCharacters(in: .whitespaces)
        let countryMap: [String: String] = [
            // Türkiye
            "istanbul": "TR", "ankara": "TR", "izmir": "TR", "antalya": "TR",
            "bodrum": "TR", "kapadokya": "TR", "cappadocia": "TR", "bursa": "TR",
            "trabzon": "TR", "fethiye": "TR", "muğla": "TR", "eskişehir": "TR",
            "gaziantep": "TR", "adana": "TR", "konya": "TR", "mersin": "TR",
            // Avrupa
            "paris": "FR", "lyon": "FR", "nice": "FR", "marsilya": "FR", "marseille": "FR",
            "london": "GB", "londra": "GB", "manchester": "GB", "edinburgh": "GB",
            "roma": "IT", "rome": "IT", "milano": "IT", "milan": "IT", "venedik": "IT", "venice": "IT", "floransa": "IT", "florence": "IT",
            "barcelona": "ES", "madrid": "ES", "sevilla": "ES", "seville": "ES",
            "berlin": "DE", "münih": "DE", "munich": "DE", "frankfurt": "DE", "hamburg": "DE",
            "amsterdam": "NL", "rotterdam": "NL",
            "brüksel": "BE", "brussels": "BE",
            "viyana": "AT", "vienna": "AT",
            "prag": "CZ", "prague": "CZ",
            "budapeşte": "HU", "budapest": "HU",
            "varşova": "PL", "warsaw": "PL", "krakow": "PL",
            "atina": "GR", "athens": "GR",
            "lizbon": "PT", "lisbon": "PT", "porto": "PT",
            "dublin": "IE",
            "kopenhag": "DK", "copenhagen": "DK",
            "stockholm": "SE",
            "oslo": "NO",
            "helsinki": "FI",
            "zürich": "CH", "zurich": "CH", "cenevre": "CH", "geneva": "CH",
            // Amerika
            "new york": "US", "los angeles": "US", "chicago": "US", "miami": "US",
            "las vegas": "US", "san francisco": "US", "boston": "US", "washington": "US",
            "toronto": "CA", "vancouver": "CA", "montreal": "CA",
            // Asya & Ortadoğu
            "tokyo": "JP", "osaka": "JP", "kyoto": "JP",
            "seoul": "KR", "seul": "KR",
            "dubai": "AE", "abu dhabi": "AE",
            "bangkok": "TH",
            "singapur": "SG", "singapore": "SG",
            "hong kong": "HK",
            // Avustralya
            "sydney": "AU", "melbourne": "AU",
            // Afrika
            "cape town": "ZA", "johannesburg": "ZA",
            "kahire": "EG", "cairo": "EG", "marakeş": "MA", "marrakech": "MA"
        ]
        return countryMap[lowered]
    }
}

// MARK: - Models

struct TicketmasterEvent: Identifiable {
    let id: String
    let name: String
    let url: String?
    let localDate: String?      // "2026-03-15"
    let localTime: String?      // "20:00" or "20:00:00"
    let venueName: String?
    let venueCity: String?
    let category: String?       // Segment: "Music", "Sports", "Arts & Theatre"
    let genre: String?          // Genre: "Rock", "Pop", "Football"
    let imageUrl: String?
    let priceRange: String?

    /// Formatted date for display — "15 Mart" or "March 15"
    var formattedDate: String {
        guard let localDate = localDate else { return "" }
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inputFormatter.date(from: localDate) else { return localDate }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage == "tr" ? "tr_TR" : "en_US")
        outputFormatter.dateFormat = "d MMMM"
        return outputFormatter.string(from: date)
    }

    /// Formatted time for display — "20:00"
    var formattedTime: String {
        guard let localTime = localTime else { return "" }
        // "20:00:00" or "20:00" -> "20:00"
        return String(localTime.prefix(5))
    }

    /// Category icon SF Symbol
    var categoryIcon: String {
        switch category?.lowercased() {
        case "music": return "music.note"
        case "sports": return "sportscourt"
        case "arts & theatre", "arts": return "theatermasks"
        case "film": return "film"
        default: return "star"
        }
    }

    /// Summary string for Claude prompt — includes all relevant info
    var promptSummary: String {
        var parts: [String] = []
        parts.append("\"\(name)\"")
        if let venue = venueName { parts.append(venue) }
        if let city = venueCity { parts.append(city) }
        if let date = localDate {
            var dateStr = date
            if let time = localTime {
                dateStr += " \(String(time.prefix(5)))"
            }
            parts.append(dateStr)
        }
        if let cat = category, let gen = genre {
            parts.append("[\(cat) / \(gen)]")
        } else if let cat = category {
            parts.append("[\(cat)]")
        }
        if let price = priceRange { parts.append("~\(price)") }
        if let ticketUrl = url { parts.append("Bilet: \(ticketUrl)") }
        return parts.joined(separator: " — ")
    }
}

// MARK: - Errors

enum TicketmasterError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case noApiKey

    var errorDescription: String? {
        let isEnglish = (UserDefaults.standard.string(forKey: "AppLanguage") ?? "tr") == "en"
        switch self {
        case .invalidURL:
            return isEnglish ? "Invalid Ticketmaster URL" : "Geçersiz Ticketmaster URL"
        case .invalidResponse:
            return isEnglish ? "Invalid Ticketmaster response" : "Geçersiz Ticketmaster yanıtı"
        case .apiError(let code):
            return isEnglish ? "Ticketmaster API error: \(code)" : "Ticketmaster API hatası: \(code)"
        case .noApiKey:
            return isEnglish ? "Ticketmaster API key not configured" : "Ticketmaster API anahtarı yapılandırılmamış"
        }
    }
}
