import SwiftUI

// MARK: - Localization Manager

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "AppLanguage")
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            updateBundle()
            objectWillChange.send()
        }
    }

    private(set) var bundle: Bundle

    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage") ?? "tr"
        self.currentLanguage = savedLanguage
        self.bundle = Self.getBundle(for: savedLanguage)
    }

    private func updateBundle() {
        bundle = Self.getBundle(for: currentLanguage)
    }

    private static func getBundle(for language: String) -> Bundle {
        // Try multiple paths to find the language bundle
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        // Try with Localizable.strings directly
        if let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language),
           let bundlePath = (path as NSString).deletingLastPathComponent as String?,
           let bundle = Bundle(path: bundlePath) {
            return bundle
        }

        return Bundle.main
    }

    func localizedString(_ key: String) -> String {
        // First try built-in translations dictionary (most reliable)
        if let translations = Translations.translations[currentLanguage],
           let value = translations[key] {
            return value
        }

        // Fallback: try Turkish as default
        if let turkishValue = Translations.turkishTranslations[key] {
            return turkishValue
        }

        // Try bundle-based localization
        let bundleValue = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        if bundleValue != key {
            return bundleValue
        }

        // Return key if nothing found
        return key
    }

    var currentGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let key: String
        switch hour {
        case 5..<12: key = "greeting.morning"
        case 12..<18: key = "greeting.afternoon"
        case 18..<22: key = "greeting.evening"
        default: key = "greeting.night"
        }
        return localizedString(key)
    }

    var currentSeasonal: String {
        let month = Calendar.current.component(.month, from: Date())
        let key: String
        switch month {
        case 12, 1, 2: key = "seasonal.winter"
        case 3, 4, 5: key = "seasonal.spring"
        case 6, 7, 8: key = "seasonal.summer"
        default: key = "seasonal.fall"
        }
        return localizedString(key)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Format date for display
    func formatted(style: DateStyle) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")

        switch style {
        case .full:
            formatter.dateStyle = .full
        case .long:
            formatter.dateStyle = .long
        case .medium:
            formatter.dateStyle = .medium
        case .short:
            formatter.dateStyle = .short
        case .dayMonth:
            formatter.dateFormat = "d MMMM"
        case .dayMonthYear:
            formatter.dateFormat = "d MMMM yyyy"
        case .weekday:
            formatter.dateFormat = "EEEE"
        case .time:
            formatter.dateFormat = "HH:mm"
        }

        return formatter.string(from: self)
    }

    enum DateStyle {
        case full, long, medium, short
        case dayMonth, dayMonthYear, weekday, time
    }

    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if date is in the past
    var isPast: Bool {
        self < Date()
    }

    /// Check if date is in the future
    var isFuture: Bool {
        self > Date()
    }

    /// Days from now
    var daysFromNow: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: self).day ?? 0
    }
}

// MARK: - String Extensions

extension String {
    /// Trim whitespace and newlines
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if string is valid email
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: self)
    }

    /// Localized string with runtime language support
    var localized: String {
        let result = LocalizationManager.shared.localizedString(self)
        // Debug: uncomment to see which keys aren't found
        // if result == self { print("⚠️ Missing translation for: \(self)") }
        return result
    }

    /// First letter capitalized
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}

// MARK: - View Extensions

extension View {
    /// Hide keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Read size
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometryProxy in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometryProxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

// MARK: - Array Extensions

extension Array {
    /// Safe subscript
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Array where Element: Identifiable {
    /// Update element by ID
    mutating func update(_ element: Element) {
        if let index = firstIndex(where: { $0.id == element.id }) {
            self[index] = element
        }
    }
}

// MARK: - Optional Extensions

extension Optional where Wrapped == String {
    /// Return empty string if nil
    var orEmpty: String {
        self ?? ""
    }

    /// Check if nil or empty
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}

// MARK: - Double Extensions

extension Double {
    /// Format as currency
    func formatted(as currency: String = "TRY") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    /// Format as percentage
    var percentageFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: self / 100)) ?? "\(Int(self))%"
    }
}

// MARK: - Int Extensions

extension Int {
    /// Format with thousand separators
    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - URLSession Extensions

extension URLSession {
    /// Async data with timeout
    func data(from url: URL, timeout: TimeInterval = 30) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        return try await data(for: request)
    }
}

// MARK: - UIApplication Extensions

extension UIApplication {
    /// Get top view controller
    var topViewController: UIViewController? {
        guard let windowScene = connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return nil
        }

        var topController = rootViewController
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        return topController
    }
}

// MARK: - Bundle Extensions

extension Bundle {
    /// App version
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Build number
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Binding Extensions

extension Binding {
    /// Transform binding
    func map<T>(get: @escaping (Value) -> T, set: @escaping (T) -> Value) -> Binding<T> {
        Binding<T>(
            get: { get(wrappedValue) },
            set: { wrappedValue = set($0) }
        )
    }
}

// MARK: - Task Extensions

extension Task where Success == Never, Failure == Never {
    /// Sleep for seconds
    static func sleep(seconds: Double) async throws {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try await sleep(nanoseconds: nanoseconds)
    }
}

// MARK: - Geographic Localization

enum GeoLocalizer {
    // City name mapping (English key -> localization key)
    private static let cityKeys: [String: String] = [
        "Paris": "city.paris",
        "Tokyo": "city.tokyo",
        "Rome": "city.rome",
        "Roma": "city.rome",
        "Istanbul": "city.istanbul",
        "İstanbul": "city.istanbul",
        "New York": "city.newyork",
        "London": "city.london",
        "Londra": "city.london",
        "Barcelona": "city.barcelona",
        "Barselona": "city.barcelona",
        "Dubai": "city.dubai",
        "Bali": "city.bali",
        "Santorini": "city.santorini",
        "Kyoto": "city.kyoto",
        "Marrakech": "city.marrakech",
        "Marakeş": "city.marrakech",
        "Alps": "city.alps",
        "Alpler": "city.alps",
        "Lapland": "city.lapland",
        "Laponya": "city.lapland",
        "Maldives": "city.maldives",
        "Maldivler": "city.maldives",
        "Ibiza": "city.ibiza",
        "İbiza": "city.ibiza",
        "Prague": "city.prague",
        "Prag": "city.prague",
        "Amsterdam": "city.amsterdam",
        "Sydney": "city.sydney",
        "Sidney": "city.sydney",
        "Singapore": "city.singapore",
        "Singapur": "city.singapore"
    ]

    // Country name mapping
    private static let countryKeys: [String: String] = [
        "France": "country.france",
        "Fransa": "country.france",
        "Japan": "country.japan",
        "Japonya": "country.japan",
        "Italy": "country.italy",
        "İtalya": "country.italy",
        "Turkey": "country.turkey",
        "Türkiye": "country.turkey",
        "USA": "country.usa",
        "ABD": "country.usa",
        "United States": "country.usa",
        "UK": "country.uk",
        "United Kingdom": "country.uk",
        "İngiltere": "country.uk",
        "England": "country.uk",
        "Spain": "country.spain",
        "İspanya": "country.spain",
        "UAE": "country.uae",
        "BAE": "country.uae",
        "Indonesia": "country.indonesia",
        "Endonezya": "country.indonesia",
        "Greece": "country.greece",
        "Yunanistan": "country.greece",
        "Morocco": "country.morocco",
        "Fas": "country.morocco",
        "Switzerland": "country.switzerland",
        "İsviçre": "country.switzerland",
        "Finland": "country.finland",
        "Finlandiya": "country.finland",
        "Netherlands": "country.netherlands",
        "Hollanda": "country.netherlands",
        "Australia": "country.australia",
        "Avustralya": "country.australia",
        "Czech Republic": "country.czechia",
        "Czechia": "country.czechia",
        "Çekya": "country.czechia",
        "Singapore": "country.singapore",
        "Singapur": "country.singapore",
        "Maldives": "country.maldives",
        "Maldivler": "country.maldives"
    ]

    /// Localize a city name
    static func localizeCity(_ name: String) -> String {
        if let key = cityKeys[name] {
            let result = key.localized
            return result
        }
        return name
    }

    /// Localize a country name
    static func localizeCountry(_ name: String) -> String {
        if let key = countryKeys[name] {
            return key.localized
        }
        return name
    }

    /// Get localized city description
    static func cityDescription(_ cityName: String) -> String {
        let normalizedName = cityName.lowercased()
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: "ş", with: "s")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ç", with: "c")
            .replacingOccurrences(of: "ğ", with: "g")
            .replacingOccurrences(of: " ", with: "")

        let key = "cityDesc.\(normalizedName)"
        let result = key.localized
        return result != key ? result : ""
    }

    /// Get localized seasonal tag
    static func seasonalTag(_ tag: String) -> String {
        let normalized = tag.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "&", with: "")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ö", with: "o")

        let key = "seasonalTag.\(normalized)"
        let result = key.localized
        return result != key ? result : tag
    }
}
