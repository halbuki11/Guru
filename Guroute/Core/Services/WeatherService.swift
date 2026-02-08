import Foundation
import CoreLocation
import WeatherKit

/// Weather service using Apple WeatherKit
/// Free with Apple Developer account: 500k calls/month
class WeatherService {
    static let shared = WeatherService()

    private let weatherService = WeatherKit.WeatherService.shared

    private init() {}

    // MARK: - Get Current Weather

    func getCurrentWeather(latitude: Double, longitude: Double, locationName: String? = nil) async throws -> Weather {
        let location = CLLocation(latitude: latitude, longitude: longitude)

        do {
            let weather = try await weatherService.weather(for: location, including: .current)

            return Weather(
                temperature: weather.temperature.value,
                feelsLike: weather.apparentTemperature.value,
                conditionCode: mapCondition(weather.condition),
                conditionText: weather.condition.description,
                humidity: Int(weather.humidity * 100),
                windSpeed: weather.wind.speed.value,
                uvIndex: Double(weather.uvIndex.value),
                locationName: locationName ?? "Unknown",
                updatedAt: Date()
            )
        } catch {
            throw WeatherError.networkError
        }
    }

    // MARK: - Get Weather for City

    func getWeatherForCity(_ city: String) async throws -> Weather {
        // Geocode city name to coordinates
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.geocodeAddressString(city)
            guard let location = placemarks.first?.location else {
                throw WeatherError.invalidResponse
            }

            return try await getCurrentWeather(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                locationName: city
            )
        } catch let error as WeatherError {
            throw error
        } catch {
            throw WeatherError.invalidResponse
        }
    }

    // MARK: - Get Forecast

    func getForecast(city: String, days: Int = 7) async throws -> [DailyForecast] {
        // Geocode city name to coordinates
        let geocoder = CLGeocoder()

        let placemarks = try await geocoder.geocodeAddressString(city)
        guard let location = placemarks.first?.location else {
            throw WeatherError.invalidResponse
        }

        do {
            let weather = try await weatherService.weather(for: location, including: .daily)

            // Take only requested number of days
            let forecasts = weather.prefix(min(days, weather.count)).map { day -> DailyForecast in
                return DailyForecast(
                    date: day.date,
                    conditionCode: self.mapCondition(day.condition),
                    conditionText: day.condition.description,
                    temperatureMax: day.highTemperature.value,
                    temperatureMin: day.lowTemperature.value,
                    precipitationChance: day.precipitationChance * 100,
                    humidity: nil,
                    windSpeed: day.wind.speed.value
                )
            }

            return Array(forecasts)
        } catch {
            throw WeatherError.networkError
        }
    }

    // MARK: - Get Forecast for Specific Date Range

    /// Belirli bir tarihten itibaren hava durumu tahmini çeker
    func getForecastForDate(city: String, startDate: Date, days: Int) async throws -> ForecastResult {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tripStart = calendar.startOfDay(for: startDate)

        // Seyahat başlangıcına kaç gün var?
        let daysUntilTrip = calendar.dateComponents([.day], from: today, to: tripStart).day ?? 0

        // WeatherKit 10 güne kadar tahmin veriyor
        let maxForecastDays = 10

        // Durum analizi
        if daysUntilTrip < 0 {
            // Geçmiş tarih - tahmin yok
            return ForecastResult(
                forecasts: [],
                isExactForecast: false,
                unavailableReason: .pastDate,
                message: "Seçilen tarih geçmişte. Güncel hava tahmini sağlanamıyor."
            )
        } else if daysUntilTrip > maxForecastDays {
            // Çok uzak tarih - tahmin yok, ama mevsimsel bilgi verilebilir
            let month = calendar.component(.month, from: startDate)
            let seasonalInfo = getSeasonalWeatherInfo(for: city, month: month)
            return ForecastResult(
                forecasts: [],
                isExactForecast: false,
                unavailableReason: .tooFarAhead,
                message: "Seçilen tarih için henüz hava tahmini yok (10 günden uzak). \(seasonalInfo)"
            )
        }

        // Tahmin çekilebilir - kaç gün çekeceğimizi hesapla
        let forecastDaysNeeded = min(daysUntilTrip + days, maxForecastDays)

        // API'den çek
        let allForecasts = try await getForecast(city: city, days: forecastDaysNeeded)

        // Sadece seyahat günlerini filtrele
        let tripForecasts = allForecasts.filter { forecast in
            let forecastDate = calendar.startOfDay(for: forecast.date)
            let tripEnd = calendar.date(byAdding: .day, value: days - 1, to: tripStart) ?? tripStart
            return forecastDate >= tripStart && forecastDate <= tripEnd
        }

        // Tam mı yoksa kısmi mi?
        let isComplete = tripForecasts.count >= days
        var message = ""
        if !isComplete && tripForecasts.count > 0 {
            message = "Seyahatin ilk \(tripForecasts.count) günü için hava tahmini mevcut."
        }

        return ForecastResult(
            forecasts: tripForecasts,
            isExactForecast: isComplete,
            unavailableReason: isComplete ? nil : .partialForecast,
            message: message
        )
    }

    // MARK: - Helpers

    private func mapCondition(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear:
            return "sunny"
        case .partlyCloudy:
            return "partly_cloudy"
        case .cloudy, .mostlyCloudy:
            return "cloudy"
        case .foggy, .haze, .smoky:
            return "fog"
        case .drizzle, .rain:
            return "rain"
        case .heavyRain:
            return "heavy_rain"
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms:
            return "thunderstorm"
        case .snow, .heavySnow, .blizzard, .flurries:
            return "snow"
        case .sleet, .freezingRain, .freezingDrizzle:
            return "sleet"
        case .hail:
            return "hail"
        case .windy, .breezy:
            return "windy"
        default:
            return "cloudy"
        }
    }

    /// Mevsimsel ortalama hava bilgisi
    private func getSeasonalWeatherInfo(for city: String, month: Int) -> String {
        let season: String
        let tempRange: String

        switch month {
        case 12, 1, 2:
            season = "kış"
            tempRange = "Genellikle soğuk ve yağışlı olabilir"
        case 3, 4, 5:
            season = "ilkbahar"
            tempRange = "Ilıman hava, ara sıra yağmur olabilir"
        case 6, 7, 8:
            season = "yaz"
            tempRange = "Genellikle sıcak ve güneşli"
        case 9, 10, 11:
            season = "sonbahar"
            tempRange = "Serin ve değişken hava"
        default:
            season = ""
            tempRange = ""
        }

        return "Mevsim: \(season). \(tempRange)."
    }
}

// MARK: - Weather Errors

enum WeatherError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case networkError
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Geçersiz URL"
        case .invalidResponse: return "Sunucu hatası"
        case .decodingError: return "Veri işleme hatası"
        case .networkError: return "Bağlantı hatası"
        case .notAvailable: return "Hava durumu servisi kullanılamıyor"
        }
    }
}

// MARK: - Forecast Result

/// Hava durumu tahmin sonucu - veri ve durum bilgisi içerir
struct ForecastResult {
    let forecasts: [DailyForecast]
    let isExactForecast: Bool
    let unavailableReason: ForecastUnavailableReason?
    let message: String

    var hasForecasts: Bool {
        !forecasts.isEmpty
    }
}

enum ForecastUnavailableReason {
    case pastDate           // Geçmiş tarih
    case tooFarAhead        // 10 günden uzak
    case partialForecast    // Kısmi tahmin (bazı günler eksik)
    case apiError           // API hatası
}
