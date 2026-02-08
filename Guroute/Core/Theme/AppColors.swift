import SwiftUI

/// Professional App Color Palette
/// Premium dark theme with gold/bronze accent
enum AppColors {
    // MARK: - Brand Colors
    /// Primary brand color - Rich Gold
    static let primary = Color(hex: "D4A574")
    /// Secondary brand color - Warm Bronze
    static let secondary = Color(hex: "A67C52")
    /// Accent color - Light Gold
    static let accent = Color(hex: "E8C89E")
    /// Tertiary - Deep Bronze
    static let tertiary = Color(hex: "8B6914")

    // MARK: - Background Colors
    /// Main background - Deep dark
    static let background = Color(hex: "0A0E14")
    /// Alternative background - Slightly lighter
    static let backgroundAlt = Color(hex: "0D1117")
    /// Surface - Card/Container background
    static let surface = Color(hex: "161B22")
    /// Surface Light - Elevated elements
    static let surfaceLight = Color(hex: "21262D")
    /// Surface Lighter - Hover states
    static let surfaceLighter = Color(hex: "2D333B")

    // MARK: - Text Colors
    /// Primary text - High contrast
    static let textPrimary = Color(hex: "F0F6FC")
    /// Secondary text - Medium contrast
    static let textSecondary = Color(hex: "8B949E")
    /// Tertiary text - Low contrast/hints
    static let textTertiary = Color(hex: "6E7681")
    /// Disabled text
    static let textDisabled = Color(hex: "484F58")
    /// Inverse text (on light backgrounds)
    static let textInverse = Color(hex: "0D1117")

    // MARK: - Semantic Colors
    /// Success - Green
    static let success = Color(hex: "3FB950")
    /// Success Light
    static let successLight = Color(hex: "56D364")
    /// Success Dark
    static let successDark = Color(hex: "238636")

    /// Warning - Orange/Amber
    static let warning = Color(hex: "D29922")
    /// Warning Light
    static let warningLight = Color(hex: "E3B341")
    /// Warning Dark
    static let warningDark = Color(hex: "9E6A03")

    /// Error - Red
    static let error = Color(hex: "F85149")
    /// Error Light
    static let errorLight = Color(hex: "FF7B72")
    /// Error Dark
    static let errorDark = Color(hex: "DA3633")

    /// Info - Blue
    static let info = Color(hex: "58A6FF")
    /// Info Light
    static let infoLight = Color(hex: "79C0FF")
    /// Info Dark
    static let infoDark = Color(hex: "388BFD")

    // MARK: - Map Colors
    /// Visited country fill
    static let visitedCountry = Color(hex: "3FB950").opacity(0.5)
    /// Wishlist country fill
    static let wishlistCountry = Color(hex: "D4A574").opacity(0.5)
    /// Default country fill
    static let defaultCountry = Color(hex: "21262D")
    /// Country border
    static let countryBorder = Color(hex: "30363D")
    /// Highlighted country
    static let highlightedCountry = Color(hex: "58A6FF").opacity(0.5)

    // MARK: - Card & Border Colors
    /// Card background
    static let cardBackground = surface
    /// Card border
    static let cardBorder = Color(hex: "30363D")
    /// Card border hover
    static let cardBorderHover = Color(hex: "484F58")
    /// Divider
    static let divider = Color(hex: "21262D")

    // MARK: - Interactive States
    /// Hover state overlay
    static let hoverOverlay = Color.white.opacity(0.05)
    /// Active/Pressed state overlay
    static let activeOverlay = Color.white.opacity(0.1)
    /// Selected state background
    static let selectedBackground = primary.opacity(0.12)
    /// Focus ring
    static let focusRing = primary.opacity(0.5)

    // MARK: - Gradients

    /// Primary brand gradient
    static let primaryGradient = LinearGradient(
        colors: [primary, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Premium gold gradient
    static let premiumGradient = LinearGradient(
        colors: [
            Color(hex: "E8C89E"),
            Color(hex: "D4A574"),
            Color(hex: "A67C52")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Background gradient
    static let backgroundGradient = LinearGradient(
        colors: [background, backgroundAlt],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Dark fade gradient (for overlays)
    static let darkFadeGradient = LinearGradient(
        colors: [.clear, background.opacity(0.8), background],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Card gradient
    static let cardGradient = LinearGradient(
        colors: [surfaceLight, surface],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Success gradient
    static let successGradient = LinearGradient(
        colors: [successLight, success],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Mesh gradient for hero sections
    static var heroMeshGradient: some View {
        ZStack {
            background
            RadialGradient(
                colors: [primary.opacity(0.15), .clear],
                center: .topTrailing,
                startRadius: 100,
                endRadius: 400
            )
            RadialGradient(
                colors: [info.opacity(0.1), .clear],
                center: .bottomLeading,
                startRadius: 50,
                endRadius: 350
            )
        }
    }

    // MARK: - Special Purpose Colors

    /// Tab bar background
    static let tabBarBackground = surface.opacity(0.95)
    /// Navigation bar background
    static let navBarBackground = background.opacity(0.9)
    /// Sheet background
    static let sheetBackground = surface
    /// Modal overlay
    static let modalOverlay = Color.black.opacity(0.6)

    // MARK: - Status Colors

    /// Draft status
    static let statusDraft = textSecondary
    /// Generating status
    static let statusGenerating = warning
    /// Completed status
    static let statusCompleted = success
    /// Failed status
    static let statusFailed = error

    // MARK: - Weather Icon Colors

    static let weatherSunny = Color(hex: "FFD93D")
    static let weatherCloudy = Color(hex: "8B949E")
    static let weatherRainy = Color(hex: "58A6FF")
    static let weatherSnowy = Color(hex: "E6EDF3")
    static let weatherStormy = Color(hex: "6E7681")
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Lighten a color by a percentage
    func lighter(by percentage: Double = 0.1) -> Color {
        return self.opacity(1 - percentage)
    }

    /// Darken a color by adding black overlay
    func darker(by percentage: Double = 0.1) -> Color {
        return self.opacity(1 + percentage)
    }
}

// MARK: - Color Scheme Extension
extension ColorScheme {
    var isDark: Bool {
        self == .dark
    }
}
