import Foundation

/// Claude Service for trip itinerary generation with weather integration
actor ClaudeService {
    static let shared = ClaudeService()

    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1"

    private init() {
        apiKey = AppConfig.shared.claudeApiKey
    }

    // MARK: - Generate Itinerary with Weather

    func generateItinerary(for trip: Trip, events: [TicketmasterEvent] = [], locale: String = "tr") async throws -> [TripDay] {
        // Fetch weather forecast for destination based on trip's start date
        var weatherForecast: [DailyForecast] = []
        var weatherMessage: String = ""

        if let firstCity = trip.destinationCities.first {
            do {
                if let startDate = trip.startDate {
                    // Tarihe göre hava durumu çek
                    let forecastResult = try await WeatherService.shared.getForecastForDate(
                        city: firstCity,
                        startDate: startDate,
                        days: trip.durationNights + 1
                    )
                    weatherForecast = forecastResult.forecasts
                    weatherMessage = forecastResult.message
                } else {
                    // Tarih yoksa bugünden itibaren çek
                    weatherForecast = try await WeatherService.shared.getForecast(
                        city: firstCity,
                        days: min(trip.durationNights + 1, 7)
                    )
                }
            } catch {
                // Silent
            }
        }

        let prompt = buildItineraryPrompt(trip: trip, weatherForecast: weatherForecast, weatherMessage: weatherMessage, events: events, locale: locale)
        let response = try await callClaude(prompt: prompt, maxTokens: 4096)

        return parseItineraryResponse(response, weatherForecast: weatherForecast, tripStartDate: trip.startDate)
    }

    // MARK: - Revise Plan

    func revisePlan(trip: Trip, revisionType: RevisionType) async throws -> [TripDay] {
        // Fetch weather forecast for destination based on trip's start date
        var weatherForecast: [DailyForecast] = []
        var weatherMessage: String = ""

        if let firstCity = trip.destinationCities.first {
            do {
                if let startDate = trip.startDate {
                    // Tarihe göre hava durumu çek
                    let forecastResult = try await WeatherService.shared.getForecastForDate(
                        city: firstCity,
                        startDate: startDate,
                        days: trip.durationNights + 1
                    )
                    weatherForecast = forecastResult.forecasts
                    weatherMessage = forecastResult.message
                } else {
                    // Tarih yoksa bugünden itibaren çek
                    weatherForecast = try await WeatherService.shared.getForecast(
                        city: firstCity,
                        days: min(trip.durationNights + 1, 7)
                    )
                }
            } catch {
                // Silent
            }
        }

        let prompt = buildRevisionPrompt(trip: trip, weatherForecast: weatherForecast, weatherMessage: weatherMessage, revisionType: revisionType)
        let response = try await callClaude(prompt: prompt, maxTokens: 4096)

        return parseItineraryResponse(response, weatherForecast: weatherForecast, tripStartDate: trip.startDate)
    }

    // MARK: - Claude API Call

    private func callClaude(prompt: String, maxTokens: Int) async throws -> String {
        guard !apiKey.isEmpty else {
            throw ClaudeError.missingAPIKey
        }

        let url = URL(string: "\(baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw ClaudeError.parsingError
        }

        return text
    }

    // MARK: - Prompt Builders

    private func buildItineraryPrompt(trip: Trip, weatherForecast: [DailyForecast], weatherMessage: String = "", events: [TicketmasterEvent] = [], locale: String) -> String {
        // Check if we should use English - use app's selected language
        let appLanguage = UserDefaults.standard.string(forKey: "AppLanguage") ?? "tr"
        let isEnglish = locale.starts(with: "en") || appLanguage == "en"

        let destinations = trip.destinationCities.joined(separator: ", ")
        let nights = trip.durationNights
        let companion = trip.companion.displayName
        let transport = trip.transportMode.displayName
        let pace = trip.pace.displayName
        let budget = trip.budget.displayName
        let iconic = trip.iconicPreference.displayName
        let notSpecified = isEnglish ? "Not specified" : "Belirtilmemiş"
        let mustVisit = trip.mustVisitPlaces.isEmpty ? notSpecified : trip.mustVisitPlaces.joined(separator: ", ")
        let stayArea = trip.stayArea.displayName
        let arrivalPoint = trip.arrivalPoint ?? notSpecified

        // Format dates and times
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: isEnglish ? "en_US" : "tr_TR")
        dateFormatter.dateFormat = isEnglish ? "MMMM d, yyyy" : "d MMMM yyyy"

        var startDateStr = notSpecified
        var seasonInfo = ""
        if let startDate = trip.startDate {
            startDateStr = dateFormatter.string(from: startDate)
            let month = Calendar.current.component(.month, from: startDate)
            if isEnglish {
                switch month {
                case 12, 1, 2: seasonInfo = " (Winter season - suggest cold weather activities)"
                case 3, 4, 5: seasonInfo = " (Spring - ideal for outdoor activities)"
                case 6, 7, 8: seasonInfo = " (Summer season - hot weather, suggest shaded areas)"
                case 9, 10, 11: seasonInfo = " (Fall - mild weather)"
                default: break
                }
            } else {
                switch month {
                case 12, 1, 2: seasonInfo = " (Kış sezonu - soğuk hava aktiviteleri öner)"
                case 3, 4, 5: seasonInfo = " (İlkbahar - açık hava için ideal)"
                case 6, 7, 8: seasonInfo = " (Yaz sezonu - sıcak hava, gölgelik mekanlar öner)"
                case 9, 10, 11: seasonInfo = " (Sonbahar - ılıman hava)"
                default: break
                }
            }
        }

        let arrivalTime = trip.arrivalTime ?? notSpecified
        let departureTime = trip.departureTime ?? notSpecified

        // Build weather info string
        var weatherInfo = ""
        if !weatherForecast.isEmpty {
            if isEnglish {
                weatherInfo = "\n\n## Weather Forecast (For Travel Dates)\n"
                for (index, forecast) in weatherForecast.enumerated() {
                    let dayNum = index + 1
                    let dateStr = dateFormatter.string(from: forecast.date)
                    weatherInfo += "- Day \(dayNum) (\(dateStr)): \(forecast.conditionText), \(Int(forecast.temperatureMin))°C - \(Int(forecast.temperatureMax))°C, Rain: \(Int(forecast.precipitationChance))%\n"
                }
                weatherInfo += "\n**IMPORTANT:** This is real weather forecast! Plan activities accordingly:\n"
                weatherInfo += "- Rainy days: Suggest museums, malls, indoor venues\n"
                weatherInfo += "- Sunny days: Suggest outdoor activities, parks, walking tours\n"
                weatherInfo += "- Hot days: Suggest shaded areas, water activities, evening outings\n"
                weatherInfo += "- Cold days: Suggest indoor activities, warm beverage spots"
            } else {
                weatherInfo = "\n\n## Hava Durumu Tahmini (Seyahat Tarihleri İçin)\n"
                for (index, forecast) in weatherForecast.enumerated() {
                    let dayNum = index + 1
                    let dateStr = dateFormatter.string(from: forecast.date)
                    weatherInfo += "- Gün \(dayNum) (\(dateStr)): \(forecast.conditionText), \(Int(forecast.temperatureMin))°C - \(Int(forecast.temperatureMax))°C, Yağış: %\(Int(forecast.precipitationChance))\n"
                }
                weatherInfo += "\n**ÖNEMLİ:** Bu gerçek hava tahminidir! Aktiviteleri bu verilere göre planla:\n"
                weatherInfo += "- Yağışlı günlerde: Müze, AVM, kapalı mekanlar öner\n"
                weatherInfo += "- Güneşli günlerde: Açık hava, parklar, yürüyüş turları öner\n"
                weatherInfo += "- Sıcak günlerde: Gölgelik mekanlar, su aktiviteleri, akşam gezileri öner\n"
                weatherInfo += "- Soğuk günlerde: İç mekan aktiviteleri, sıcak içecek mekanları öner"
            }
        } else if !weatherMessage.isEmpty {
            if isEnglish {
                weatherInfo = "\n\n## Weather Note\n"
                weatherInfo += weatherMessage
                weatherInfo += "\n\n**NOTE:** Since exact weather forecast is not available, suggest activities based on seasonal characteristics."
            } else {
                weatherInfo = "\n\n## Hava Durumu Notu\n"
                weatherInfo += weatherMessage
                weatherInfo += "\n\n**NOT:** Kesin hava tahmini olmadığı için mevsimsel özelliklere göre aktivite öner."
            }
        }

        // Build events info string
        var eventsInfo = ""
        if !events.isEmpty {
            if isEnglish {
                eventsInfo = "\n\n## Events & Concerts (During Travel Dates)\n"
                eventsInfo += "These events are happening at the destination during the travel dates:\n"
                for event in events {
                    eventsInfo += "- \(event.promptSummary)\n"
                }
                eventsInfo += "\n**IMPORTANT:** Include these events in the itinerary! For each event:\n"
                eventsInfo += "- Place the event at the correct date and time\n"
                eventsInfo += "- Leave preparation/travel time before the event\n"
                eventsInfo += "- Suggest nearby restaurants before/after the event\n"
                eventsInfo += "- Add the event's ticket URL in the 'tips' field if available\n"
                eventsInfo += "- Use the event name as the activity name\n"
            } else {
                eventsInfo = "\n\n## Etkinlikler & Konserler (Seyahat Tarihlerinde)\n"
                eventsInfo += "Bu etkinlikler gidilecek şehirde seyahat tarihlerinde gerçekleşiyor:\n"
                for event in events {
                    eventsInfo += "- \(event.promptSummary)\n"
                }
                eventsInfo += "\n**ÖNEMLİ:** Bu etkinlikleri plana dahil et! Her etkinlik için:\n"
                eventsInfo += "- Etkinliği doğru gün ve saate yerleştir\n"
                eventsInfo += "- Etkinlik öncesi hazırlık/ulaşım süresi bırak\n"
                eventsInfo += "- Etkinlik öncesi/sonrası yakın restoran öner\n"
                eventsInfo += "- Bilet URL'si varsa 'tips' alanına ekle\n"
                eventsInfo += "- Etkinlik adını aktivite adı olarak kullan\n"
            }
        }

        // Build arrival/departure constraints
        var timeConstraints = ""
        if arrivalTime != notSpecified || departureTime != notSpecified {
            if isEnglish {
                timeConstraints = "\n\n## Time Constraints\n"
                if arrivalTime != notSpecified {
                    timeConstraints += "- FIRST DAY: User arrives around \(arrivalTime). Plan first day activities accordingly (include post-arrival fatigue, check-in time).\n"
                }
                if departureTime != notSpecified {
                    timeConstraints += "- LAST DAY: User leaves around \(departureTime). Plan last day activities accordingly (include check-out, travel to airport).\n"
                }
            } else {
                timeConstraints = "\n\n## Zaman Kısıtlamaları\n"
                if arrivalTime != notSpecified {
                    timeConstraints += "- İLK GÜN: Kullanıcı saat \(arrivalTime) civarı varıyor. İlk gün aktivitelerini buna göre planla (varış sonrası yorgunluk, check-in süresi dahil).\n"
                }
                if departureTime != notSpecified {
                    timeConstraints += "- SON GÜN: Kullanıcı saat \(departureTime) civarı ayrılıyor. Son gün aktivitelerini buna göre planla (check-out, havalimanına gidiş süresi dahil).\n"
                }
            }
        }

        if isEnglish {
            return """
            You are an experienced travel planner. Create a detailed travel plan based on the following information.

            ## Travel Information
            - Destination: \(destinations)
            - Duration: \(nights) nights
            - Start Date: \(startDateStr)\(seasonInfo)
            - Travel Type: \(companion)
            - Arrival Point: \(arrivalPoint)
            - Stay Area: \(stayArea)
            - Transport Preference: \(transport)
            - Pace: \(pace)
            - Budget: \(budget)
            - Tourist Attractions Preference: \(iconic)
            - Must-See Places: \(mustVisit)\(timeConstraints)\(weatherInfo)\(eventsInfo)

            ## Output Format
            Create activities in JSON format for each day. Specify realistic start and end times for each activity:

            ```json
            {
              "days": [
                {
                  "dayNumber": 1,
                  "title": "Day title",
                  "summary": "Brief day summary (include weather)",
                  "activities": [
                    {
                      "slot": "morning|noon|afternoon|evening",
                      "name": "Activity name",
                      "description": "Detailed description",
                      "address": "Address",
                      "latitude": 48.8584,
                      "longitude": 2.2945,
                      "duration": 90,
                      "startTime": "09:00",
                      "endTime": "10:30",
                      "cost": "Free or estimated price",
                      "tips": "Useful tips"
                    }
                  ]
                }
              ]
            }
            ```

            ## Rules
            1. Plan at least 4 activities per day (morning, noon, afternoon, evening)
            2. **IMPORTANT: Specify realistic startTime and endTime values for each activity (HH:mm format)**
            3. Keep activity durations realistic:
               - Museum/gallery: 1.5-3 hours
               - Breakfast/lunch: 45-90 min
               - Dinner: 1.5-2 hours
               - Historical site visit: 1-2 hours
               - Shopping: 1-2 hours
               - Park/garden walk: 1-1.5 hours
               - Coffee break: 30-45 min
            4. Leave 15-30 min travel time between activities
            5. FIRST DAY: Adjust activities based on arrival time (late arrival = evening activities only)
            6. LAST DAY: Adjust activities based on departure time (early flight = no morning activity)
            7. Activities should be near accommodation or on a logical route
            8. Make budget-appropriate suggestions
            9. Adjust activity intensity based on pace (relaxed = 3-4/day, intensive = 5-6/day)
            10. Suggest places appropriate for travel type (family = kid-friendly, couple = romantic)
            11. Include local cuisine recommendations
            12. Adjust distances based on transport preference (walking = nearby places)
            13. Suggest weather-appropriate activities
            14. Pay attention to tourist preference (avoid crowds = alternative places)
            15. Only respond in JSON format, do not add other explanations
            """
        } else {
            return """
            Sen deneyimli bir seyahat planlayıcısısın. Aşağıdaki bilgilere göre detaylı bir seyahat planı oluştur.

            ## Seyahat Bilgileri
            - Destinasyon: \(destinations)
            - Süre: \(nights) gece
            - Başlangıç Tarihi: \(startDateStr)\(seasonInfo)
            - Seyahat Tipi: \(companion)
            - Varış Noktası: \(arrivalPoint)
            - Konaklama Bölgesi: \(stayArea)
            - Ulaşım Tercihi: \(transport)
            - Tempo: \(pace)
            - Bütçe: \(budget)
            - Turistik Yerler Tercihi: \(iconic)
            - Mutlaka Görülmesi Gereken Yerler: \(mustVisit)\(timeConstraints)\(weatherInfo)\(eventsInfo)

            ## Çıktı Formatı
            Her gün için JSON formatında aktiviteler oluştur. Her aktivitenin gerçekçi başlangıç ve bitiş saatlerini belirt:

            ```json
            {
              "days": [
                {
                  "dayNumber": 1,
                  "title": "Gün başlığı",
                  "summary": "Günün kısa özeti (hava durumunu da belirt)",
                  "activities": [
                    {
                      "slot": "morning|noon|afternoon|evening",
                      "name": "Aktivite adı",
                      "description": "Detaylı açıklama",
                      "address": "Adres",
                      "latitude": 48.8584,
                      "longitude": 2.2945,
                      "duration": 90,
                      "startTime": "09:00",
                      "endTime": "10:30",
                      "cost": "Ücretsiz veya tahmini fiyat",
                      "tips": "Faydalı ipuçları"
                    }
                  ]
                }
              ]
            }
            ```

            ## Kurallar
            1. Her gün için en az 4 aktivite planla (sabah, öğle, öğleden sonra, akşam)
            2. **ÖNEMLİ: Her aktivite için gerçekçi startTime ve endTime değerleri belirt (HH:mm formatında)**
            3. Aktivite süreleri gerçekçi olsun:
               - Müze/galeri: 1.5-3 saat
               - Kahvaltı/öğle yemeği: 45-90 dk
               - Akşam yemeği: 1.5-2 saat
               - Tarihi yer gezisi: 1-2 saat
               - Alışveriş: 1-2 saat
               - Park/bahçe yürüyüşü: 1-1.5 saat
               - Kafe molası: 30-45 dk
            4. Aktiviteler arasında 15-30 dk ulaşım süresi bırak
            5. İLK GÜN varış saatine göre aktiviteleri ayarla (geç varışta akşam aktiviteleri yeterli)
            6. SON GÜN ayrılış saatine göre aktiviteleri ayarla (erken uçuşta sabah aktivitesi yok)
            7. Aktiviteler konaklama bölgesine yakın veya mantıklı güzergahta olsun
            8. Bütçeye uygun öneriler yap
            9. Tempoya göre aktivite yoğunluğunu ayarla (rahat = günde 3-4, yoğun = günde 5-6)
            10. Seyahat tipine uygun yerler öner (aile = çocuk dostu, çift = romantik)
            11. Yerel mutfak önerileri ekle
            12. Ulaşım tercihine göre mesafeleri ayarla (yürüyüş = yakın yerler)
            13. Hava durumuna uygun aktiviteler öner
            14. Turistik yer tercihine dikkat et (kalabalıktan kaçın = alternatif yerler)
            15. Sadece JSON formatında yanıt ver, başka açıklama ekleme
            """
        }
    }

    private func buildRevisionPrompt(trip: Trip, weatherForecast: [DailyForecast], weatherMessage: String = "", revisionType: RevisionType) -> String {
        // Check if we should use English - use app's selected language
        let appLanguage = UserDefaults.standard.string(forKey: "AppLanguage") ?? "tr"
        let isEnglish = appLanguage == "en"
        let locale = isEnglish ? "en" : "tr"
        let basePrompt = buildItineraryPrompt(trip: trip, weatherForecast: weatherForecast, weatherMessage: weatherMessage, locale: locale)

        let revisionInstruction: String
        switch revisionType {
        case .lighter:
            if isEnglish {
                revisionInstruction = """

                ## Revision: Lighter Plan
                - 2-3 activities per day is enough
                - Leave more rest time
                - Reduce crowded tourist spots
                - Add pleasant cafe/park suggestions
                """
            } else {
                revisionInstruction = """

                ## Revizyon: Daha Hafif Plan
                - Her gün için 2-3 aktivite yeterli
                - Daha fazla dinlenme zamanı bırak
                - Yoğun turist yerlerini azalt
                - Keyifli kafe/park önerileri ekle
                """
            }
        case .heavier:
            if isEnglish {
                revisionInstruction = """

                ## Revision: More Intensive Plan
                - Plan 5-6 activities per day
                - Start early, finish late
                - Add more places to see
                - Ensure efficient time usage
                """
            } else {
                revisionInstruction = """

                ## Revizyon: Daha Yoğun Plan
                - Her gün için 5-6 aktivite planla
                - Erken başla, geç bitir
                - Daha fazla görülecek yer ekle
                - Etkin zaman kullanımı sağla
                """
            }
        case .alternative:
            if isEnglish {
                revisionInstruction = """

                ## Revision: Alternative Plan
                - Suggest completely different places
                - Hidden gems instead of main tourist spots
                - Focus on local experiences
                - Explore different neighborhoods/areas
                """
            } else {
                revisionInstruction = """

                ## Revizyon: Alternatif Plan
                - Tamamen farklı yerler öner
                - Ana turistik yerler yerine gizli hazineler
                - Yerel deneyimlere odaklan
                - Farklı semtler/bölgeler keşfet
                """
            }
        }

        return basePrompt + revisionInstruction
    }

    // MARK: - Response Parser

    private func parseItineraryResponse(_ response: String, weatherForecast: [DailyForecast] = [], tripStartDate: Date? = nil) -> [TripDay] {
        // Extract JSON from response
        guard let jsonStart = response.firstIndex(of: "{"),
              let jsonEnd = response.lastIndex(of: "}") else {
            return []
        }

        let jsonString = String(response[jsonStart...jsonEnd])

        guard let jsonData = jsonString.data(using: .utf8) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            let itinerary = try decoder.decode(ItineraryResponse.self, from: jsonData)
            let calendar = Calendar.current

            return itinerary.days.enumerated().map { (index, dayResponse) in
                // Calculate the date for this day
                var dayDate: Date? = nil
                if let startDate = tripStartDate {
                    dayDate = calendar.date(byAdding: .day, value: index, to: startDate)
                }

                // Attach weather data if available - match by date or index
                var dayWeather: DayWeather? = nil

                // Try to find matching weather by date first
                if let targetDate = dayDate {
                    let targetDayStart = calendar.startOfDay(for: targetDate)
                    if let matchingForecast = weatherForecast.first(where: {
                        calendar.startOfDay(for: $0.date) == targetDayStart
                    }) {
                        dayWeather = DayWeather(
                            condition: matchingForecast.conditionCode,
                            conditionText: matchingForecast.conditionText,
                            temperatureMax: matchingForecast.temperatureMax,
                            temperatureMin: matchingForecast.temperatureMin,
                            precipitationChance: Int(matchingForecast.precipitationChance),
                            humidity: matchingForecast.humidity ?? 0,
                            windSpeed: matchingForecast.windSpeed ?? 0.0,
                            icon: nil
                        )
                    }
                }

                // Fallback to index-based matching if no date match
                if dayWeather == nil && index < weatherForecast.count {
                    let forecast = weatherForecast[index]
                    dayWeather = DayWeather(
                        condition: forecast.conditionCode,
                        conditionText: forecast.conditionText,
                        temperatureMax: forecast.temperatureMax,
                        temperatureMin: forecast.temperatureMin,
                        precipitationChance: Int(forecast.precipitationChance),
                        humidity: forecast.humidity ?? 0,
                        windSpeed: forecast.windSpeed ?? 0.0,
                        icon: nil
                    )
                }

                return TripDay(
                    id: UUID().uuidString,
                    tripId: "",
                    dayNumber: dayResponse.dayNumber,
                    date: dayDate,
                    title: dayResponse.title,
                    summary: dayResponse.summary,
                    activities: dayResponse.activities.map { activityResponse in
                        TripActivity(
                            id: UUID().uuidString,
                            dayId: "",
                            slot: ActivitySlot(rawValue: activityResponse.slot) ?? .morning,
                            name: activityResponse.name,
                            description: activityResponse.description,
                            address: activityResponse.address,
                            latitude: activityResponse.latitude,
                            longitude: activityResponse.longitude,
                            duration: activityResponse.duration,
                            startTime: activityResponse.startTime,
                            endTime: activityResponse.endTime,
                            cost: activityResponse.cost,
                            tips: activityResponse.tips,
                            photoUrl: nil,
                            isCompleted: false
                        )
                    },
                    weather: dayWeather
                )
            }
        } catch {
            return []
        }
    }
}

// MARK: - Response Models

private struct ItineraryResponse: Codable {
    let days: [DayResponse]
}

private struct DayResponse: Codable {
    let dayNumber: Int
    let title: String
    let summary: String?
    let activities: [ActivityResponse]
}

private struct ActivityResponse: Codable {
    let slot: String
    let name: String
    let description: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let duration: Int?
    let startTime: String?
    let endTime: String?
    let cost: String?
    let tips: String?
}

// MARK: - Claude Errors

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parsingError
    case networkError

    private var isEnglish: Bool {
        let appLanguage = UserDefaults.standard.string(forKey: "AppLanguage") ?? "tr"
        return appLanguage == "en"
    }

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return isEnglish ? "Claude API key not found" : "Claude API anahtarı bulunamadı"
        case .invalidResponse:
            return isEnglish ? "Invalid response" : "Geçersiz yanıt"
        case .apiError(let code, let message):
            return isEnglish ? "Claude API error (\(code)): \(message)" : "Claude API hatası (\(code)): \(message)"
        case .parsingError:
            return isEnglish ? "Could not process response" : "Yanıt işlenemedi"
        case .networkError:
            return isEnglish ? "Connection error" : "Bağlantı hatası"
        }
    }
}

// MARK: - Revision Type

enum RevisionType: String {
    case lighter
    case heavier
    case alternative
}
