import SwiftUI

// MARK: - Avatar View
/// Professional avatar component with multiple styles
struct AvatarView: View {
    let name: String
    var imageData: Data? = nil
    var size: AvatarSize = .medium
    var showBorder: Bool = true

    enum AvatarSize {
        case small, medium, large, xlarge

        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 48
            case .large: return 64
            case .xlarge: return 96
            }
        }

        var fontSize: Font {
            switch self {
            case .small: return ThemeManager.Typography.caption1Bold
            case .medium: return ThemeManager.Typography.headline
            case .large: return ThemeManager.Typography.title2
            case .xlarge: return ThemeManager.Typography.title1
            }
        }

        var borderWidth: CGFloat {
            switch self {
            case .small: return 1.5
            case .medium: return 2
            case .large: return 2.5
            case .xlarge: return 3
            }
        }
    }

    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                // Gradient background with initials
                LinearGradient(
                    colors: [AppColors.primary.opacity(0.8), AppColors.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Text(initials)
                    .font(size.fontSize)
                    .foregroundStyle(AppColors.textInverse)
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    showBorder ? AppColors.primary : .clear,
                    lineWidth: size.borderWidth
                )
        )
    }
}

// MARK: - Badge View
/// Status/count badge component
struct BadgeView: View {
    let text: String
    var style: BadgeStyle = .primary
    var size: BadgeSize = .medium

    enum BadgeStyle {
        case primary, success, warning, error, info, neutral

        var backgroundColor: Color {
            switch self {
            case .primary: return AppColors.primary
            case .success: return AppColors.success
            case .warning: return AppColors.warning
            case .error: return AppColors.error
            case .info: return AppColors.info
            case .neutral: return AppColors.surfaceLight
            }
        }

        var textColor: Color {
            switch self {
            case .neutral: return AppColors.textPrimary
            default: return AppColors.textInverse
            }
        }
    }

    enum BadgeSize {
        case small, medium, large

        var font: Font {
            switch self {
            case .small: return ThemeManager.Typography.caption2
            case .medium: return ThemeManager.Typography.caption1Bold
            case .large: return ThemeManager.Typography.footnoteBold
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 10
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return 4
            case .large: return 6
            }
        }
    }

    var body: some View {
        Text(text)
            .font(size.font)
            .foregroundStyle(style.textColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(style.backgroundColor)
            .cornerRadius(ThemeManager.CornerRadius.pill)
    }
}

// MARK: - Icon Badge
/// Circular icon with background
struct IconBadge: View {
    let icon: String
    var color: Color = AppColors.primary
    var size: IconBadgeSize = .medium

    enum IconBadgeSize {
        case small, medium, large

        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 44
            case .large: return 56
            }
        }

        var iconSize: Font {
            switch self {
            case .small: return .system(size: 14)
            case .medium: return .system(size: 18)
            case .large: return .system(size: 24)
            }
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))

            Image(systemName: icon)
                .font(size.iconSize)
                .foregroundStyle(color)
        }
        .frame(width: size.dimension, height: size.dimension)
    }
}

// MARK: - Status Indicator
/// Small status dot indicator
struct StatusIndicator: View {
    let status: Status

    enum Status {
        case online, offline, away, busy

        var color: Color {
            switch self {
            case .online: return AppColors.success
            case .offline: return AppColors.textTertiary
            case .away: return AppColors.warning
            case .busy: return AppColors.error
            }
        }
    }

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(AppColors.background, lineWidth: 2)
            )
    }
}

// MARK: - Progress Ring
/// Circular progress indicator
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 6
    var size: CGFloat = 60
    var showPercentage: Bool = true

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(AppColors.surfaceLight, lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    AppColors.primaryGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(ThemeManager.Animation.spring, value: progress)

            // Percentage text
            if showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(ThemeManager.Typography.caption1Bold)
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Empty State View
/// Professional empty state component
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: ThemeManager.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.surfaceLight)
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(AppColors.textTertiary)
            }

            // Text content
            VStack(spacing: ThemeManager.Spacing.xs) {
                Text(title)
                    .font(ThemeManager.Typography.title3)
                    .foregroundStyle(AppColors.textPrimary)

                Text(message)
                    .font(ThemeManager.Typography.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Action button
            if let buttonTitle = buttonTitle, let action = action {
                Button(action: action) {
                    Text(buttonTitle)
                }
                .primaryButton()
            }
        }
        .padding(ThemeManager.Spacing.xl)
    }
}

// MARK: - Loading State View
/// Full-screen loading state
struct LoadingStateView: View {
    var message: String = "common.loading".localized
    var showSparkles: Bool = true

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: ThemeManager.Spacing.lg) {
            ZStack {
                // Pulsing background
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .opacity(isAnimating ? 0.5 : 1.0)

                // Icon
                if showSparkles {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.primary)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                } else {
                    ProgressView()
                        .tint(AppColors.primary)
                        .scaleEffect(1.5)
                }
            }

            Text(message)
                .font(ThemeManager.Typography.body)
                .foregroundStyle(AppColors.textSecondary)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Section Header
/// Consistent section header with optional action
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: ThemeManager.Spacing.xxxs) {
                Text(title)
                    .font(ThemeManager.Typography.title3)
                    .foregroundStyle(AppColors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(ThemeManager.Typography.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: ThemeManager.Spacing.xxs) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .font(ThemeManager.Typography.subheadline)
                    .foregroundStyle(AppColors.primary)
                }
            }
        }
    }
}

// MARK: - Info Banner
/// Informational banner with icon
struct InfoBanner: View {
    let message: String
    var icon: String = "info.circle.fill"
    var style: BannerStyle = .info

    enum BannerStyle {
        case info, success, warning, error

        var backgroundColor: Color {
            switch self {
            case .info: return AppColors.info.opacity(0.15)
            case .success: return AppColors.success.opacity(0.15)
            case .warning: return AppColors.warning.opacity(0.15)
            case .error: return AppColors.error.opacity(0.15)
            }
        }

        var iconColor: Color {
            switch self {
            case .info: return AppColors.info
            case .success: return AppColors.success
            case .warning: return AppColors.warning
            case .error: return AppColors.error
            }
        }

        var borderColor: Color {
            switch self {
            case .info: return AppColors.info.opacity(0.3)
            case .success: return AppColors.success.opacity(0.3)
            case .warning: return AppColors.warning.opacity(0.3)
            case .error: return AppColors.error.opacity(0.3)
            }
        }
    }

    var body: some View {
        HStack(spacing: ThemeManager.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(style.iconColor)

            Text(message)
                .font(ThemeManager.Typography.subheadline)
                .foregroundStyle(AppColors.textPrimary)

            Spacer()
        }
        .padding(ThemeManager.Spacing.md)
        .background(style.backgroundColor)
        .cornerRadius(ThemeManager.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                .stroke(style.borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Divider with Text
/// Horizontal divider with centered text
struct DividerWithText: View {
    let text: String

    var body: some View {
        HStack(spacing: ThemeManager.Spacing.md) {
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)

            Text(text)
                .font(ThemeManager.Typography.caption1)
                .foregroundStyle(AppColors.textTertiary)

            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)
        }
    }
}

// MARK: - Stat Box
/// Statistical display box
struct StatBox: View {
    let value: String
    let label: String
    var icon: String? = nil
    var trend: Trend? = nil

    enum Trend {
        case up, down, neutral

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }

        var color: Color {
            switch self {
            case .up: return AppColors.success
            case .down: return AppColors.error
            case .neutral: return AppColors.textSecondary
            }
        }
    }

    var body: some View {
        VStack(spacing: ThemeManager.Spacing.xs) {
            // Icon if present
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.primary)
            }

            // Value with optional trend
            HStack(spacing: ThemeManager.Spacing.xxs) {
                Text(value)
                    .font(ThemeManager.Typography.title1)
                    .foregroundStyle(AppColors.textPrimary)

                if let trend = trend {
                    Image(systemName: trend.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(trend.color)
                }
            }

            // Label
            Text(label)
                .font(ThemeManager.Typography.caption1)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(ThemeManager.Spacing.md)
        .cardStyle(elevation: .low)
    }
}

// MARK: - Feature Card
/// Horizontal feature highlight card
struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    var isPremium: Bool = false

    var body: some View {
        HStack(spacing: ThemeManager.Spacing.md) {
            // Icon
            IconBadge(
                icon: icon,
                color: isPremium ? AppColors.primary : AppColors.info,
                size: .large
            )

            // Content
            VStack(alignment: .leading, spacing: ThemeManager.Spacing.xxs) {
                HStack {
                    Text(title)
                        .font(ThemeManager.Typography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    if isPremium {
                        BadgeView(text: "PRO", style: .primary, size: .small)
                    }
                }

                Text(description)
                    .font(ThemeManager.Typography.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(ThemeManager.Spacing.md)
        .background(isPremium ? AppColors.primary.opacity(0.08) : AppColors.surface)
        .cornerRadius(ThemeManager.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                .stroke(isPremium ? AppColors.primary.opacity(0.3) : AppColors.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Animated Check Mark
struct AnimatedCheckmark: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.success.opacity(0.15))
                .frame(width: 80, height: 80)

            Circle()
                .fill(AppColors.success)
                .frame(width: 60, height: 60)
                .scaleEffect(isAnimating ? 1 : 0)

            Image(systemName: "checkmark")
                .font(.system(size: 30))
                .foregroundStyle(.white)
                .scaleEffect(isAnimating ? 1 : 0)
        }
        .onAppear {
            withAnimation(ThemeManager.Animation.springBouncy) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AppColors.primaryGradient)
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: AppColors.primary.opacity(0.4),
                        radius: 12,
                        x: 0,
                        y: 6
                    )

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(AppColors.textInverse)
            }
        }
    }
}

// MARK: - Pull to Refresh Indicator
struct CustomRefreshIndicator: View {
    @Binding var isRefreshing: Bool

    var body: some View {
        HStack(spacing: ThemeManager.Spacing.sm) {
            if isRefreshing {
                ProgressView()
                    .tint(AppColors.primary)
            }

            Text(isRefreshing ? "common.updating".localized : "common.pullToRefresh".localized)
                .font(ThemeManager.Typography.caption1)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.vertical, ThemeManager.Spacing.sm)
    }
}

// MARK: - Previews
#Preview("Components") {
    ScrollView {
        VStack(spacing: 24) {
            // Avatars
            HStack(spacing: 16) {
                AvatarView(name: "John Doe", size: .small)
                AvatarView(name: "Jane Smith", size: .medium)
                AvatarView(name: "Bob", size: .large)
            }

            // Badges
            HStack(spacing: 8) {
                BadgeView(text: "New", style: .primary)
                BadgeView(text: "5", style: .success)
                BadgeView(text: "Warning", style: .warning)
                BadgeView(text: "Error", style: .error)
            }

            // Progress Ring
            ProgressRing(progress: 0.75)

            // Stat Boxes
            HStack {
                StatBox(value: "12", label: "Ülke", icon: "flag.fill", trend: .up)
                StatBox(value: "48", label: "Şehir", icon: "building.2.fill")
            }

            // Empty State
            EmptyStateView(
                icon: "airplane",
                title: "Henüz gezi yok",
                message: "İlk seyahatinizi planlamaya başlayın",
                buttonTitle: "Gezi Oluştur"
            ) {}

            // Info Banner
            InfoBanner(
                message: "AI asistanımız rotanızı oluşturuyor",
                style: .info
            )

            // Feature Card
            FeatureCard(
                icon: "sparkles",
                title: "AI Rota Oluşturucu",
                description: "Kişiselleştirilmiş seyahat planları",
                isPremium: true
            )
        }
        .padding()
    }
    .background(AppColors.background)
}
