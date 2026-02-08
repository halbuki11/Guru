import SwiftUI

/// Professional Theme Manager for Guroute
/// Provides consistent design tokens, animations, and styling
@MainActor
class ThemeManager: ObservableObject {
    @Published var colorScheme: ColorScheme = .dark

    // MARK: - Font Names (Space Mono)
    private enum FontName {
        static let regular = "SpaceMono-Regular"
        static let bold = "SpaceMono-Bold"
        static let italic = "SpaceMono-Italic"
        static let boldItalic = "SpaceMono-BoldItalic"
    }

    // MARK: - Typography (Flight Board Design System — Space Mono)
    enum Typography {
        // Display - Hero text
        static let displayLarge = Font.custom(FontName.bold, size: 56)
        static let displayMedium = Font.custom(FontName.bold, size: 44)
        static let displaySmall = Font.custom(FontName.bold, size: 36)

        // Titles
        static let largeTitle = Font.custom(FontName.bold, size: 34)
        static let title1 = Font.custom(FontName.bold, size: 28)
        static let title2 = Font.custom(FontName.bold, size: 22)
        static let title3 = Font.custom(FontName.bold, size: 20)

        // Body text
        static let headline = Font.custom(FontName.bold, size: 17)
        static let body = Font.custom(FontName.regular, size: 17)
        static let bodyBold = Font.custom(FontName.bold, size: 17)
        static let callout = Font.custom(FontName.regular, size: 16)
        static let calloutBold = Font.custom(FontName.bold, size: 16)
        static let subheadline = Font.custom(FontName.regular, size: 15)
        static let subheadlineBold = Font.custom(FontName.bold, size: 15)

        // Small text
        static let footnote = Font.custom(FontName.regular, size: 13)
        static let footnoteBold = Font.custom(FontName.bold, size: 13)
        static let caption1 = Font.custom(FontName.regular, size: 12)
        static let caption1Bold = Font.custom(FontName.bold, size: 12)
        static let caption2 = Font.custom(FontName.regular, size: 11)

        // Board — Flight Board specific sizes (bold for emphasis)
        static let boardDisplay = Font.custom(FontName.bold, size: 30)    // countdown values
        static let boardTitle = Font.custom(FontName.bold, size: 28)      // city codes hero
        static let boardCity = Font.custom(FontName.bold, size: 20)       // board row city codes
        static let boardValue = Font.custom(FontName.bold, size: 18)      // stat values, date numbers
        static let boardToolbar = Font.custom(FontName.bold, size: 16)    // toolbar titles
        static let boardLabel = Font.custom(FontName.bold, size: 12)      // badges, filter labels
        static let boardCaption = Font.custom(FontName.bold, size: 11)    // small labels
        static let boardHeader = Font.custom(FontName.bold, size: 10)     // column headers
        static let boardMicro = Font.custom(FontName.bold, size: 9)       // status badges, tiny labels

        // Monospaced aliases (backward compat)
        static let monoLarge = boardTitle
        static let monoMedium = Font.custom(FontName.bold, size: 17)
        static let monoSmall = Font.custom(FontName.regular, size: 13)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
        static let huge: CGFloat = 80
    }

    // MARK: - Corner Radius
    enum CornerRadius {
        static let xs: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let pill: CGFloat = 100
    }

    // MARK: - Shadows
    enum Shadows {
        // Subtle shadows
        static let subtle = Shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        static let small = Shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        static let medium = Shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        static let large = Shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
        static let xl = Shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)

        // Glow effects
        static let glow = Shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 0)
        static let glowStrong = Shadow(color: AppColors.primary.opacity(0.5), radius: 20, x: 0, y: 0)

        // Colored shadows
        static let primaryShadow = Shadow(color: AppColors.primary.opacity(0.25), radius: 8, x: 0, y: 4)
        static let successShadow = Shadow(color: AppColors.success.opacity(0.25), radius: 8, x: 0, y: 4)
    }

    // MARK: - Animation
    enum Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.35)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.75)
        static let springBouncy = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6)
        static let springSmooth = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.85)
    }

    // MARK: - Icon Sizes
    enum IconSize {
        static let xs: CGFloat = 12
        static let small: CGFloat = 16
        static let medium: CGFloat = 20
        static let large: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let huge: CGFloat = 64
    }

    // MARK: - Border Width
    enum BorderWidth {
        static let thin: CGFloat = 0.5
        static let regular: CGFloat = 1
        static let medium: CGFloat = 1.5
        static let thick: CGFloat = 2
        static let heavy: CGFloat = 3
    }
}

// MARK: - Shadow Helper
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Glass Material
struct GlassMaterial {
    let blur: CGFloat
    let opacity: Double
    let borderOpacity: Double

    static let thin = GlassMaterial(blur: 10, opacity: 0.1, borderOpacity: 0.2)
    static let regular = GlassMaterial(blur: 20, opacity: 0.15, borderOpacity: 0.25)
    static let thick = GlassMaterial(blur: 30, opacity: 0.2, borderOpacity: 0.3)
}

// MARK: - View Modifiers

/// Card with subtle glass effect
struct GlassCardStyle: ViewModifier {
    var material: GlassMaterial = .regular
    var cornerRadius: CGFloat = ThemeManager.CornerRadius.medium

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base blur
                    AppColors.surface.opacity(0.8)

                    // Glass overlay
                    LinearGradient(
                        colors: [
                            Color.white.opacity(material.opacity),
                            Color.white.opacity(material.opacity * 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(material.borderOpacity),
                                Color.white.opacity(material.borderOpacity * 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: ThemeManager.BorderWidth.thin
                    )
            )
    }
}

/// Standard card style
struct CardStyle: ViewModifier {
    var elevation: CardElevation = .medium

    enum CardElevation {
        case flat, low, medium, high

        var shadow: Shadow {
            switch self {
            case .flat: return ThemeManager.Shadows.subtle
            case .low: return ThemeManager.Shadows.small
            case .medium: return ThemeManager.Shadows.medium
            case .high: return ThemeManager.Shadows.large
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .background(AppColors.cardBackground)
            .cornerRadius(ThemeManager.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                    .stroke(AppColors.cardBorder, lineWidth: ThemeManager.BorderWidth.thin)
            )
            .shadow(
                color: elevation.shadow.color,
                radius: elevation.shadow.radius,
                x: elevation.shadow.x,
                y: elevation.shadow.y
            )
    }
}

/// Premium card with gradient border
struct PremiumCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.surface)
            .cornerRadius(ThemeManager.CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.large)
                    .stroke(AppColors.primaryGradient, lineWidth: ThemeManager.BorderWidth.medium)
            )
            .shadow(
                color: AppColors.primary.opacity(0.15),
                radius: 12,
                x: 0,
                y: 4
            )
    }
}

/// Primary button style with gradient and animation
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ThemeManager.Typography.headline)
            .foregroundColor(AppColors.background)
            .padding(.horizontal, ThemeManager.Spacing.lg)
            .padding(.vertical, ThemeManager.Spacing.sm + 2)
            .background(
                Group {
                    if isEnabled {
                        LinearGradient(
                            colors: configuration.isPressed
                                ? [AppColors.accent, AppColors.primary]
                                : [AppColors.primary, AppColors.accent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        AppColors.textTertiary
                    }
                }
            )
            .cornerRadius(ThemeManager.CornerRadius.medium)
            .shadow(
                color: isEnabled ? AppColors.primary.opacity(configuration.isPressed ? 0.2 : 0.3) : .clear,
                radius: configuration.isPressed ? 4 : 8,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(ThemeManager.Animation.fast, value: configuration.isPressed)
    }
}

/// Secondary button style
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ThemeManager.Typography.headline)
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, ThemeManager.Spacing.lg)
            .padding(.vertical, ThemeManager.Spacing.sm + 2)
            .background(AppColors.surface)
            .cornerRadius(ThemeManager.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                    .stroke(AppColors.primary.opacity(configuration.isPressed ? 0.5 : 1), lineWidth: ThemeManager.BorderWidth.regular)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(ThemeManager.Animation.fast, value: configuration.isPressed)
    }
}

/// Ghost button style (text only)
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ThemeManager.Typography.headline)
            .foregroundColor(configuration.isPressed ? AppColors.primary.opacity(0.7) : AppColors.primary)
            .padding(.horizontal, ThemeManager.Spacing.md)
            .padding(.vertical, ThemeManager.Spacing.xs)
            .background(configuration.isPressed ? AppColors.primary.opacity(0.1) : .clear)
            .cornerRadius(ThemeManager.CornerRadius.small)
            .animation(ThemeManager.Animation.fast, value: configuration.isPressed)
    }
}

/// Icon button style
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(configuration.isPressed ? AppColors.primary.opacity(0.2) : AppColors.surface)
            .cornerRadius(size / 2)
            .overlay(
                Circle()
                    .stroke(AppColors.cardBorder, lineWidth: ThemeManager.BorderWidth.thin)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(ThemeManager.Animation.fast, value: configuration.isPressed)
    }
}

/// Selection card style (for options)
struct SelectionCardStyle: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background(isSelected ? AppColors.primary.opacity(0.12) : AppColors.surface)
            .cornerRadius(ThemeManager.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                    .stroke(
                        isSelected ? AppColors.primary : AppColors.cardBorder,
                        lineWidth: isSelected ? ThemeManager.BorderWidth.medium : ThemeManager.BorderWidth.thin
                    )
            )
            .shadow(
                color: isSelected ? AppColors.primary.opacity(0.15) : .clear,
                radius: isSelected ? 8 : 0,
                x: 0,
                y: isSelected ? 4 : 0
            )
    }
}

/// Chip/Tag style
struct ChipStyle: ViewModifier {
    let isSelected: Bool
    let size: ChipSize

    enum ChipSize {
        case small, medium, large

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return ThemeManager.Spacing.xs
            case .medium: return ThemeManager.Spacing.sm
            case .large: return ThemeManager.Spacing.md
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return ThemeManager.Spacing.xxs
            case .medium: return ThemeManager.Spacing.xs
            case .large: return ThemeManager.Spacing.sm
            }
        }

        var font: Font {
            switch self {
            case .small: return ThemeManager.Typography.caption1Bold
            case .medium: return ThemeManager.Typography.subheadline
            case .large: return ThemeManager.Typography.body
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .font(size.font)
            .foregroundStyle(isSelected ? AppColors.background : AppColors.textSecondary)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(isSelected ? AppColors.primary : AppColors.surface)
            .cornerRadius(ThemeManager.CornerRadius.pill)
            .overlay(
                Capsule()
                    .stroke(isSelected ? AppColors.primary : AppColors.cardBorder, lineWidth: ThemeManager.BorderWidth.thin)
            )
    }
}

// MARK: - Input Styles

struct TextFieldStyle: ViewModifier {
    var isFocused: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(ThemeManager.Spacing.sm)
            .background(AppColors.surface)
            .cornerRadius(ThemeManager.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.small)
                    .stroke(
                        isFocused ? AppColors.primary : AppColors.cardBorder,
                        lineWidth: isFocused ? ThemeManager.BorderWidth.medium : ThemeManager.BorderWidth.thin
                    )
            )
    }
}

// MARK: - View Extensions
extension View {
    // Card styles
    func cardStyle(elevation: CardStyle.CardElevation = .medium) -> some View {
        modifier(CardStyle(elevation: elevation))
    }

    func glassCard(material: GlassMaterial = .regular, cornerRadius: CGFloat = ThemeManager.CornerRadius.medium) -> some View {
        modifier(GlassCardStyle(material: material, cornerRadius: cornerRadius))
    }

    func premiumCard() -> some View {
        modifier(PremiumCardStyle())
    }

    func selectionCard(isSelected: Bool) -> some View {
        modifier(SelectionCardStyle(isSelected: isSelected))
    }

    // Button styles
    func primaryButton() -> some View {
        buttonStyle(PrimaryButtonStyle())
    }

    func secondaryButton() -> some View {
        buttonStyle(SecondaryButtonStyle())
    }

    func ghostButton() -> some View {
        buttonStyle(GhostButtonStyle())
    }

    func iconButton(size: CGFloat = 44) -> some View {
        buttonStyle(IconButtonStyle(size: size))
    }

    // Chip style
    func chipStyle(isSelected: Bool, size: ChipStyle.ChipSize = .medium) -> some View {
        modifier(ChipStyle(isSelected: isSelected, size: size))
    }

    // Text field style
    func customTextFieldStyle(isFocused: Bool = false) -> some View {
        modifier(TextFieldStyle(isFocused: isFocused))
    }

    // Shadow helpers
    func applyShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    // Glow effect
    func glow(color: Color = AppColors.primary, radius: CGFloat = 10) -> some View {
        self.shadow(color: color.opacity(0.4), radius: radius, x: 0, y: 0)
    }
}

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.white.opacity(0.3), location: 0.5),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Loading Skeleton
struct SkeletonView: View {
    var width: CGFloat? = nil
    var height: CGFloat = 20
    var cornerRadius: CGFloat = ThemeManager.CornerRadius.small

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppColors.surfaceLight)
            .frame(width: width, height: height)
            .shimmer()
    }
}
