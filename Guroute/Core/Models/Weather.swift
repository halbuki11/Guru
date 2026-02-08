import Foundation

// MARK: - Weather
struct Weather: Codable, Equatable {
    var temperature: Double
    var feelsLike: Double
    var conditionCode: String
    var conditionText: String
    var humidity: Int
    var windSpeed: Double
    var uvIndex: Double
    var locationName: String
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case temperature
        case feelsLike = "feels_like"
        case conditionCode = "condition_code"
        case conditionText = "condition_text"
        case humidity
        case windSpeed = "wind_speed"
        case uvIndex = "uv_index"
        case locationName = "location_name"
        case updatedAt = "updated_at"
    }

    var temperatureFormatted: String {
        "\(Int(temperature))°"
    }

    var conditionIcon: String {
        switch conditionCode {
        case "sunny", "clear":
            return "sun.max.fill"
        case "partly_cloudy":
            return "cloud.sun.fill"
        case "cloudy", "overcast":
            return "cloud.fill"
        case "rain", "light_rain", "moderate_rain":
            return "cloud.rain.fill"
        case "heavy_rain", "torrential_rain":
            return "cloud.heavyrain.fill"
        case "thunderstorm":
            return "cloud.bolt.rain.fill"
        case "snow", "light_snow":
            return "cloud.snow.fill"
        case "fog", "mist":
            return "cloud.fog.fill"
        default:
            return "cloud.fill"
        }
    }
}

// MARK: - Daily Forecast
struct DailyForecast: Codable, Identifiable, Equatable {
    var id: String { date.ISO8601Format() }
    var date: Date
    var conditionCode: String
    var conditionText: String
    var temperatureMax: Double
    var temperatureMin: Double
    var precipitationChance: Double
    var humidity: Int?
    var windSpeed: Double?

    enum CodingKeys: String, CodingKey {
        case date
        case conditionCode = "condition_code"
        case conditionText = "condition_text"
        case temperatureMax = "temperature_max"
        case temperatureMin = "temperature_min"
        case precipitationChance = "precipitation_chance"
        case humidity
        case windSpeed = "wind_speed"
    }

    var temperatureRangeFormatted: String {
        "\(Int(temperatureMin))° - \(Int(temperatureMax))°"
    }

    var dayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date).capitalized
    }

    var shortDayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).capitalized
    }

    var conditionIcon: String {
        switch conditionCode {
        case "sunny", "clear":
            return "sun.max.fill"
        case "partly_cloudy":
            return "cloud.sun.fill"
        case "cloudy", "overcast":
            return "cloud.fill"
        case "rain", "light_rain", "moderate_rain":
            return "cloud.rain.fill"
        case "heavy_rain", "torrential_rain":
            return "cloud.heavyrain.fill"
        case "thunderstorm":
            return "cloud.bolt.rain.fill"
        case "snow", "light_snow":
            return "cloud.snow.fill"
        case "fog", "mist":
            return "cloud.fog.fill"
        default:
            return "cloud.fill"
        }
    }
}

// MARK: - Location Data
struct LocationData: Codable, Equatable {
    var displayName: String
    var countryCode: String
    var countryName: String
    var latitude: Double?
    var longitude: Double?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case countryCode = "country_code"
        case countryName = "country_name"
        case latitude
        case longitude
    }
}
