import Foundation
import MapKit
import Combine

/// Real-time city search using Apple's MKLocalSearchCompleter
/// No API key required — uses built-in MapKit
@MainActor
class CitySearchService: NSObject, ObservableObject {
    @Published var results: [CityResult] = []
    @Published var isSearching = false

    private let completer = MKLocalSearchCompleter()
    private var currentQuery = ""

    struct CityResult: Identifiable, Equatable {
        let id = UUID()
        let name: String          // "Barcelona"
        let subtitle: String      // "Spain"
        let countryCode: String   // "ES"
        let coordinate: CLLocationCoordinate2D?

        static func == (lhs: CityResult, rhs: CityResult) -> Bool {
            lhs.name == rhs.name && lhs.subtitle == rhs.subtitle
        }
    }

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func search(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            return
        }
        currentQuery = trimmed
        isSearching = true
        completer.queryFragment = trimmed
    }

    func clear() {
        results = []
        isSearching = false
        currentQuery = ""
        completer.queryFragment = ""
    }

    /// Resolve a completer result to get country code and full details
    private func resolve(_ completion: MKLocalSearchCompletion) async -> CityResult? {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = .address
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            if let item = response.mapItems.first {
                let placemark = item.placemark
                let cityName = placemark.locality ?? completion.title
                let country = placemark.country ?? completion.subtitle
                let code = placemark.isoCountryCode ?? countryCodeFromName(country)

                return CityResult(
                    name: cityName,
                    subtitle: country,
                    countryCode: code,
                    coordinate: placemark.coordinate
                )
            }
        } catch {
            // Fallback: use the raw completion data
        }

        return CityResult(
            name: completion.title,
            subtitle: completion.subtitle,
            countryCode: countryCodeFromName(completion.subtitle),
            coordinate: nil
        )
    }

    /// Fallback country code from country name
    private func countryCodeFromName(_ name: String) -> String {
        let map: [String: String] = [
            "türkiye": "TR", "turkey": "TR",
            "fransa": "FR", "france": "FR",
            "almanya": "DE", "germany": "DE",
            "ingiltere": "GB", "birleşik krallık": "GB", "united kingdom": "GB",
            "italya": "IT", "italy": "IT",
            "ispanya": "ES", "spain": "ES",
            "hollanda": "NL", "netherlands": "NL",
            "birleşik arap emirlikleri": "AE", "united arab emirates": "AE",
            "japonya": "JP", "japan": "JP",
            "amerika birleşik devletleri": "US", "united states": "US",
            "çekya": "CZ", "czechia": "CZ",
            "portekiz": "PT", "portugal": "PT",
            "avusturya": "AT", "austria": "AT",
            "macaristan": "HU", "hungary": "HU",
            "yunanistan": "GR", "greece": "GR",
            "belçika": "BE", "belgium": "BE",
            "danimarka": "DK", "denmark": "DK",
            "isveç": "SE", "sweden": "SE",
            "norveç": "NO", "norway": "NO",
            "finlandiya": "FI", "finland": "FI",
            "polonya": "PL", "poland": "PL",
            "isviçre": "CH", "switzerland": "CH",
            "irlanda": "IE", "ireland": "IE",
            "hırvatistan": "HR", "croatia": "HR",
            "tayland": "TH", "thailand": "TH",
            "singapur": "SG", "singapore": "SG",
            "güney kore": "KR", "south korea": "KR",
            "endonezya": "ID", "indonesia": "ID",
            "çin": "CN", "china": "CN",
            "hindistan": "IN", "india": "IN",
            "katar": "QA", "qatar": "QA",
            "israil": "IL", "israel": "IL",
            "kanada": "CA", "canada": "CA",
            "meksika": "MX", "mexico": "MX",
            "brezilya": "BR", "brazil": "BR",
            "arjantin": "AR", "argentina": "AR",
            "mısır": "EG", "egypt": "EG",
            "fas": "MA", "morocco": "MA",
            "güney afrika": "ZA", "south africa": "ZA",
            "avustralya": "AU", "australia": "AU",
        ]
        return map[name.lowercased()] ?? "🌍"
    }
}

// MARK: - MKLocalSearchCompleterDelegate
extension CitySearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let completions = completer.results

        Task { @MainActor in
            // Filter: only show city/region level results (no specific addresses)
            let cityCompletions = completions.filter { result in
                // Skip results with street-level details (numbers, specific addresses)
                let title = result.title
                let subtitle = result.subtitle

                // A city result typically has a country/region as subtitle
                // Skip if title contains numbers (street addresses)
                let hasNumbers = title.rangeOfCharacter(from: .decimalDigits) != nil
                if hasNumbers { return false }

                // Skip if subtitle is empty (too vague)
                if subtitle.isEmpty { return false }

                // Skip if title contains comma (usually "Street, City" format)
                // But allow "City, State" format (for US cities)
                let commaCount = title.filter { $0 == "," }.count
                if commaCount > 1 { return false }

                return true
            }.prefix(8)

            // Resolve each to get country codes
            var resolved: [CityResult] = []
            for completion in cityCompletions {
                if let city = await resolve(completion) {
                    // Deduplicate by city name
                    if !resolved.contains(where: { $0.name == city.name }) {
                        resolved.append(city)
                    }
                }
            }

            self.results = resolved
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
        }
    }
}
