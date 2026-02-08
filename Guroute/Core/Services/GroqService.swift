import Foundation

/// Groq Service for quick city information and suggestions using Llama 3.1
actor GroqService {
    static let shared = GroqService()

    private let apiKey: String
    private let baseURL = "https://api.groq.com/openai/v1"

    private init() {
        apiKey = AppConfig.shared.groqApiKey
    }

    // MARK: - Language Helper
    private var isEnglish: Bool {
        // Use app's selected language, not system language
        let appLanguage = UserDefaults.standard.string(forKey: "AppLanguage") ?? "tr"
        return appLanguage == "en"
    }

    // MARK: - Get City Info

    func getCityInfo(city: String) async throws -> String {
        let prompt: String
        if isEnglish {
            prompt = """
            Give a brief and informative summary about the city of \(city).

            Include:
            - City's highlights
            - Best time to visit
            - 3 must-see places
            - 2 local cuisine recommendations

            Maximum 150 words summary. Respond in English.
            """
        } else {
            prompt = """
            \(city) şehri hakkında kısa ve bilgilendirici bir özet ver.

            Şunları içersin:
            - Şehrin öne çıkan özellikleri
            - En iyi ziyaret zamanı
            - Mutlaka görülmesi gereken 3 yer
            - Yerel mutfaktan 2 öneri

            Maksimum 150 kelime ile özet yap. Türkçe yanıt ver.
            """
        }

        return try await callGroq(prompt: prompt, maxTokens: 512)
    }

    // MARK: - Get Country Info

    func getCountryInfo(country: String) async throws -> String {
        let prompt: String
        if isEnglish {
            prompt = """
            Give travel information about \(country).

            Include:
            - General introduction (1-2 sentences)
            - Capital and major cities
            - Best time/season to visit
            - Visa requirements (general)
            - Currency
            - 3 must-see places
            - 2 local cuisine recommendations
            - Practical travel tip

            Maximum 200 words summary. Respond in English.
            """
        } else {
            prompt = """
            \(country) ülkesi hakkında seyahat bilgisi ver.

            Şunları içersin:
            - Ülkenin genel tanıtımı (1-2 cümle)
            - Başkent ve önemli şehirler
            - En iyi ziyaret zamanı/mevsimi
            - Vize durumu (Türk vatandaşları için)
            - Para birimi
            - Mutlaka görülmesi gereken 3 yer
            - Yerel mutfaktan 2 öneri
            - Pratik seyahat ipucu

            Maksimum 200 kelime ile özet yap. Türkçe yanıt ver.
            """
        }

        return try await callGroq(prompt: prompt, maxTokens: 600)
    }

    // MARK: - Get Destination Comparison

    func compareDestinations(destinations: [String]) async throws -> String {
        let destList = destinations.joined(separator: ", ")
        let prompt: String
        if isEnglish {
            prompt = """
            Compare these destinations: \(destList)

            For each briefly:
            - Best time to travel
            - Average budget level (€)
            - Main highlight

            Then indicate which is suitable for which type of traveler.
            Maximum 150 words. Respond in English.
            """
        } else {
            prompt = """
            Şu destinasyonları karşılaştır: \(destList)

            Her biri için kısaca:
            - En uygun seyahat zamanı
            - Ortalama bütçe seviyesi (€)
            - Öne çıkan özelliği

            Sonra hangisinin hangi tip gezgin için uygun olduğunu belirt.
            Maksimum 150 kelime. Türkçe yanıt ver.
            """
        }

        return try await callGroq(prompt: prompt, maxTokens: 512)
    }

    // MARK: - Quick Suggestion

    func getQuickSuggestion(destination: String, query: String) async throws -> String {
        let prompt: String
        if isEnglish {
            prompt = """
            User wants information about \(destination).
            Question: \(query)

            Give a short and concise answer (maximum 2-3 sentences). Respond in English.
            """
        } else {
            prompt = """
            Kullanıcı \(destination) hakkında bilgi istiyor.
            Soru: \(query)

            Kısa ve öz bir cevap ver (maksimum 2-3 cümle). Türkçe yanıt ver.
            """
        }

        return try await callGroq(prompt: prompt, maxTokens: 256)
    }

    // MARK: - Get Popular Places

    func getPopularPlaces(city: String, category: String? = nil) async throws -> String {
        let prompt: String
        if isEnglish {
            var categoryText = ""
            if let cat = category {
                categoryText = " Category: \(cat)."
            }
            prompt = """
            List popular places in \(city).\(categoryText)

            For each place:
            - Name
            - Short description (1 sentence)
            - Estimated visit duration

            Maximum 5 places. Respond in English.
            """
        } else {
            var categoryText = ""
            if let cat = category {
                categoryText = " Kategori: \(cat)."
            }
            prompt = """
            \(city) şehrindeki popüler yerleri listele.\(categoryText)

            Her yer için:
            - İsim
            - Kısa açıklama (1 cümle)
            - Tahmini ziyaret süresi

            En fazla 5 yer öner. Türkçe yanıt ver.
            """
        }

        return try await callGroq(prompt: prompt, maxTokens: 512)
    }

    // MARK: - Get Local Tips

    func getLocalTips(city: String) async throws -> String {
        let prompt: String
        if isEnglish {
            prompt = """
            Give local tips for \(city).

            Include:
            - Transportation tips (public transport, taxi, etc.)
            - Currency and payment methods
            - Safety recommendations
            - Local etiquette

            Give short and practical information. Respond in English.
            """
        } else {
            prompt = """
            \(city) şehri için yerel ipuçları ver.

            Şunları içersin:
            - Ulaşım ipuçları (toplu taşıma, taksi vs.)
            - Para birimi ve ödeme yöntemleri
            - Güvenlik önerileri
            - Yerel görgü kuralları

            Kısa ve pratik bilgiler ver. Türkçe yanıt ver.
            """
        }

        return try await callGroq(prompt: prompt, maxTokens: 400)
    }

    // MARK: - Groq API Call

    private func callGroq(prompt: String, maxTokens: Int) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GroqError.missingAPIKey
        }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "llama-3.1-8b-instant",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": maxTokens,
            "temperature": 0.7
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GroqError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw GroqError.parsingError
        }

        return content
    }
}

// MARK: - Groq Errors

enum GroqError: LocalizedError {
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
            return isEnglish ? "Groq API key not found" : "Groq API anahtarı bulunamadı"
        case .invalidResponse:
            return isEnglish ? "Invalid response" : "Geçersiz yanıt"
        case .apiError(let code, let message):
            return isEnglish ? "Groq API error (\(code)): \(message)" : "Groq API hatası (\(code)): \(message)"
        case .parsingError:
            return isEnglish ? "Could not process response" : "Yanıt işlenemedi"
        case .networkError:
            return isEnglish ? "Connection error" : "Bağlantı hatası"
        }
    }
}
