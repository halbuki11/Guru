import SwiftUI

// MARK: - Passport View

struct PassportView: View {
    @AppStorage("userName") private var userName: String = ""
    @StateObject private var viewModel = PassportViewModel()
    @State private var selectedTab: PassportTab = .stamps
    @State private var showShareSheet = false
    @State private var selectedStamp: UserStamp? = nil
    @State private var bookPage: Int = 0

    private var stampPages: [[UserStamp]] {
        viewModel.stamps.chunked(into: 4)
    }

    private var totalBookPages: Int {
        stampPages.isEmpty ? 2 : 1 + stampPages.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    passportTabBar

                    if selectedTab == .stamps {
                        passportBookSection
                    } else if selectedTab == .achievements {
                        achievementsSection
                    } else {
                        statsSection
                    }
                }
            }
            .navigationTitle("passport.myPassport".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            viewModel.exportPDF()
                        } label: {
                            Label("passport.downloadPDF".localized, systemImage: "arrow.down.doc")
                        }
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("passport.share".localized, systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(AppColors.primary)
                    }
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
        .sheet(item: $selectedStamp) { stamp in
            StampDetailSheet(stamp: stamp)
        }
    }

    // MARK: - Tab Bar

    private var passportTabBar: some View {
        HStack(spacing: 0) {
            ForEach(PassportTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: ThemeManager.Spacing.xxs) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12))
                            Text(tab.title)
                                .font(ThemeManager.Typography.caption1Bold)
                        }
                        .foregroundStyle(selectedTab == tab ? AppColors.primary : AppColors.textTertiary)
                        .padding(.vertical, 10)

                        Rectangle()
                            .fill(selectedTab == tab ? AppColors.primary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, ThemeManager.Spacing.md)
        .background(
            AppColors.surface.opacity(0.5)
                .overlay(alignment: .bottom) {
                    AppColors.cardBorder.frame(height: 0.5)
                }
        )
    }

    // MARK: - Passport Book (Horizontal Paging)

    private var passportBookSection: some View {
        VStack(spacing: 0) {
            TabView(selection: $bookPage) {
                PassportCoverView(userName: userName, stats: viewModel.stats)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .tag(0)

                if stampPages.isEmpty {
                    emptyStampPage
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .tag(1)
                } else {
                    ForEach(Array(stampPages.enumerated()), id: \.offset) { index, pageStamps in
                        PassportStampPageView(
                            stamps: pageStamps,
                            pageNumber: index + 1,
                            totalPages: stampPages.count,
                            onStampTap: { stamp in selectedStamp = stamp }
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .tag(index + 1)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom gold page dots
            HStack(spacing: 6) {
                ForEach(0..<totalBookPages, id: \.self) { page in
                    Capsule()
                        .fill(page == bookPage ? AppColors.primary : AppColors.textTertiary.opacity(0.2))
                        .frame(width: page == bookPage ? 16 : 6, height: 6)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: bookPage)
            .padding(.bottom, 12)
        }
    }

    private var emptyStampPage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.primary.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)

            Image(systemName: "globe.europe.africa")
                .font(.system(size: 100, weight: .ultraLight))
                .foregroundStyle(AppColors.primary.opacity(0.04))

            VStack(spacing: ThemeManager.Spacing.lg) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 44, weight: .ultraLight))
                    .foregroundStyle(AppColors.primary.opacity(0.4))

                Text("passport.noStampsYet".localized)
                    .font(ThemeManager.Typography.headline)
                    .foregroundStyle(AppColors.textSecondary)

                Text("passport.earnStampsByVisiting".localized)
                    .font(ThemeManager.Typography.caption1)
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ThemeManager.Spacing.xl)
            }
        }
    }

    // MARK: - Achievements Section

    private var achievementsSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ThemeManager.Spacing.md) {
                HStack(spacing: ThemeManager.Spacing.md) {
                    VStack(spacing: 4) {
                        Text("\(viewModel.unlockedAchievementIds.count)")
                            .font(ThemeManager.Typography.title2)
                            .foregroundStyle(AppColors.primary)
                        Text("passport.achievement".localized)
                            .font(ThemeManager.Typography.caption2)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    Text("/")
                        .font(ThemeManager.Typography.title3)
                        .foregroundStyle(AppColors.textDisabled)

                    VStack(spacing: 4) {
                        Text("\(viewModel.achievements.count)")
                            .font(ThemeManager.Typography.title2)
                            .foregroundStyle(AppColors.textSecondary)
                        Text("total")
                            .font(ThemeManager.Typography.caption2)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .padding(.top, ThemeManager.Spacing.sm)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: ThemeManager.Spacing.sm),
                    GridItem(.flexible(), spacing: ThemeManager.Spacing.sm)
                ], spacing: ThemeManager.Spacing.sm) {
                    ForEach(viewModel.achievements) { achievement in
                        AchievementCard(
                            achievement: achievement,
                            isUnlocked: viewModel.unlockedAchievementIds.contains(achievement.id),
                            currentValue: viewModel.currentProgress(for: achievement)
                        )
                    }
                }
            }
            .padding(.horizontal, ThemeManager.Spacing.md)
            .padding(.bottom, ThemeManager.Spacing.lg)
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ThemeManager.Spacing.lg) {
                worldProgressCard

                VStack(spacing: 0) {
                    StatRow(icon: "flag.fill", label: "passport.visitedCountries".localized, value: "\(viewModel.stats.countriesVisited)", tint: AppColors.success)
                    Divider().background(AppColors.cardBorder).padding(.horizontal, ThemeManager.Spacing.md)
                    StatRow(icon: "building.2.fill", label: "passport.visitedCities".localized, value: "\(viewModel.stats.citiesVisited)", tint: AppColors.info)
                    Divider().background(AppColors.cardBorder).padding(.horizontal, ThemeManager.Spacing.md)
                    StatRow(icon: "globe.americas.fill", label: "passport.visitedContinents".localized, value: "\(viewModel.stats.continentsVisited)", tint: AppColors.warning)
                    Divider().background(AppColors.cardBorder).padding(.horizontal, ThemeManager.Spacing.md)
                    StatRow(icon: "stamp.fill", label: "passport.totalStamps".localized, value: "\(viewModel.stats.totalStamps)", tint: AppColors.primary)
                    Divider().background(AppColors.cardBorder).padding(.horizontal, ThemeManager.Spacing.md)
                    StatRow(icon: "trophy.fill", label: "passport.earnedAchievements".localized, value: "\(viewModel.stats.achievementsUnlocked)", tint: AppColors.accent)
                }
                .padding(.vertical, ThemeManager.Spacing.xs)
                .cardStyle()
            }
            .padding(ThemeManager.Spacing.md)
        }
    }

    private var worldProgressCard: some View {
        VStack(spacing: ThemeManager.Spacing.md) {
            Text("passport.worldExplorationRate".localized)
                .font(ThemeManager.Typography.headline)
                .foregroundStyle(AppColors.textPrimary)

            ZStack {
                Circle()
                    .stroke(AppColors.surfaceLighter, lineWidth: 10)
                    .frame(width: 130, height: 130)

                Circle()
                    .trim(from: 0, to: CGFloat(min(viewModel.stats.worldPercentage, 100)) / 100.0)
                    .stroke(
                        AngularGradient(
                            colors: [AppColors.primary, AppColors.accent, AppColors.primary],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(String(format: "%.1f", viewModel.stats.worldPercentage))
                        .font(ThemeManager.Typography.title2)
                        .foregroundStyle(AppColors.primary)
                    Text("%")
                        .font(ThemeManager.Typography.caption1)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .padding(.vertical, ThemeManager.Spacing.xs)
        }
        .padding(ThemeManager.Spacing.lg)
        .cardStyle()
    }
}

// MARK: - Passport Tab

enum PassportTab: String, CaseIterable {
    case stamps
    case achievements
    case stats

    var title: String {
        switch self {
        case .stamps: return "passport.tabStamps".localized
        case .achievements: return "passport.tabAchievements".localized
        case .stats: return "passport.tabStats".localized
        }
    }

    var icon: String {
        switch self {
        case .stamps: return "stamp.fill"
        case .achievements: return "trophy.fill"
        case .stats: return "chart.bar.fill"
        }
    }
}

// MARK: - Passport Cover View

struct PassportCoverView: View {
    let userName: String
    let stats: PassportStats

    var body: some View {
        ZStack {
            // Dark burgundy cover background
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "1C1018"), Color(hex: "120A0E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Gold outer border
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.primary.opacity(0.3), lineWidth: 1.5)

            // Gold inner border
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColors.primary.opacity(0.1), lineWidth: 0.5)
                .padding(6)

            // Content
            VStack(spacing: 0) {
                Spacer()

                // Gold emblem
                ZStack {
                    Circle()
                        .stroke(AppColors.primary.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 72, height: 72)
                    Circle()
                        .stroke(AppColors.primary.opacity(0.15), lineWidth: 0.5)
                        .frame(width: 64, height: 64)

                    Image(systemName: "globe.europe.africa")
                        .font(.system(size: 30, weight: .thin))
                        .foregroundStyle(AppColors.primary.opacity(0.7))
                }

                Spacer().frame(height: 20)

                Text("GUROUTE")
                    .font(.custom("SpaceMono-Bold", size: 20))
                    .tracking(6)
                    .foregroundStyle(AppColors.primary)

                Spacer().frame(height: 6)

                Text("passport.digitalPassport".localized)
                    .font(.custom("SpaceMono-Bold", size: 9))
                    .tracking(3)
                    .foregroundStyle(AppColors.primary.opacity(0.5))

                Spacer().frame(height: 28)

                // Gold divider with plane
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(AppColors.primary.opacity(0.2))
                        .frame(height: 0.5)
                    Image(systemName: "airplane")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.primary.opacity(0.4))
                    Rectangle()
                        .fill(AppColors.primary.opacity(0.2))
                        .frame(height: 0.5)
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 20)

                // User name
                Text(userName.isEmpty ? "passport.traveler".localized : userName.uppercased())
                    .font(.custom("SpaceMono-Bold", size: 13))
                    .tracking(2)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.8))

                Spacer()

                // Mini stats
                HStack(spacing: 0) {
                    coverStat(value: "\(stats.countriesVisited)", label: "passport.country".localized)
                    coverStatDivider
                    coverStat(value: "\(stats.totalStamps)", label: "passport.stamp".localized)
                    coverStatDivider
                    coverStat(value: "\(stats.achievementsUnlocked)", label: "passport.achievement".localized)
                }
                .padding(.horizontal, ThemeManager.Spacing.md)
                .padding(.bottom, ThemeManager.Spacing.sm)

                // Swipe hint
                HStack(spacing: 4) {
                    Text("Swipe")
                        .font(.custom("SpaceMono-Regular", size: 9))
                        .foregroundStyle(AppColors.textTertiary.opacity(0.4))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundStyle(AppColors.textTertiary.opacity(0.3))
                }
                .padding(.bottom, ThemeManager.Spacing.md)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }

    private func coverStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("SpaceMono-Bold", size: 18))
                .foregroundStyle(AppColors.primary)
            Text(label)
                .font(.custom("SpaceMono-Regular", size: 8))
                .foregroundStyle(AppColors.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var coverStatDivider: some View {
        Rectangle()
            .fill(AppColors.primary.opacity(0.15))
            .frame(width: 0.5, height: 30)
    }
}

// MARK: - Passport Stamp Page View

struct PassportStampPageView: View {
    let stamps: [UserStamp]
    let pageNumber: Int
    let totalPages: Int
    let onStampTap: (UserStamp) -> Void

    var body: some View {
        ZStack {
            // Page background
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface)

            // Gold border
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.primary.opacity(0.15), lineWidth: 1)

            // Inner border
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColors.primary.opacity(0.06), lineWidth: 0.5)
                .padding(5)

            // Watermark
            Image(systemName: "globe.europe.africa")
                .font(.system(size: 100, weight: .ultraLight))
                .foregroundStyle(AppColors.primary.opacity(0.03))

            // Clean 2x2 grid layout
            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                // Row 1
                HStack(spacing: 12) {
                    if stamps.count > 0 {
                        stampCell(stamps[0], rotation: -1.5)
                    }
                    if stamps.count > 1 {
                        stampCell(stamps[1], rotation: 1.2)
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer()

                // Row 2
                HStack(spacing: 12) {
                    if stamps.count > 2 {
                        stampCell(stamps[2], rotation: 1.0)
                    }
                    if stamps.count > 3 {
                        stampCell(stamps[3], rotation: -1.8)
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer()

                // Page number
                Text("— \(pageNumber) / \(totalPages) —")
                    .font(.custom("SpaceMono-Regular", size: 10))
                    .foregroundStyle(AppColors.textTertiary.opacity(0.4))
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 16)
        }
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }

    private func stampCell(_ stamp: UserStamp, rotation: Double) -> some View {
        let hash = stamp.countryCode.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let extraRotation = Double(hash % 3) - 1.0 // -1 to +1 subtle variation

        return PassportStampView(stamp: stamp)
            .rotationEffect(.degrees(rotation + extraRotation))
            .onTapGesture {
                onStampTap(stamp)
            }
    }
}

// MARK: - Passport Stamp View (on page)

struct PassportStampView: View {
    let stamp: UserStamp

    private var countryData: CountryData? {
        CountryUtils.getCountryData(code: stamp.countryCode)
    }

    private var stampImageName: String? {
        let allImages = StampImageMapping.allStampImageNames(for: stamp.countryCode)
        guard !allImages.isEmpty else { return nil }
        if allImages.count == 1 { return allImages[0] }
        let hash = stamp.countryCode.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return allImages[hash % allImages.count]
    }

    var body: some View {
        VStack(spacing: 6) {
            // Stamp image
            ZStack {
                if let imageName = stampImageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.primary.opacity(0.35), lineWidth: 1.5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.primary.opacity(0.04), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                } else {
                    // Flag fallback
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.surfaceLight)
                        .frame(width: 140, height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        )
                        .overlay(
                            Text(countryData?.flag ?? "🏳️")
                                .font(.system(size: 40))
                        )
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

            // Country name with flag
            HStack(spacing: 4) {
                Text(countryData?.flag ?? "")
                    .font(.system(size: 14))
                Text(countryData?.localizedName ?? stamp.countryCode)
                    .font(.custom("SpaceMono-Bold", size: 11))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
            }

            // Visit date
            Text(stamp.stampDate.formatted(date: .abbreviated, time: .omitted))
                .font(.custom("SpaceMono-Regular", size: 10))
                .foregroundStyle(AppColors.primary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stamp Detail Sheet

struct StampDetailSheet: View {
    let stamp: UserStamp
    @Environment(\.dismiss) private var dismiss
    @State private var currentImageIndex: Int = 0

    private var allImages: [String] {
        StampImageMapping.allStampImageNames(for: stamp.countryCode)
    }

    private var countryData: CountryData? {
        CountryUtils.getCountryData(code: stamp.countryCode)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: ThemeManager.Spacing.lg) {
                    // Image carousel or single image
                    if allImages.count > 1 {
                        TabView(selection: $currentImageIndex) {
                            ForEach(Array(allImages.enumerated()), id: \.offset) { index, imageName in
                                Image(imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 260)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .automatic))
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                        )

                        Text(landmarkDisplayName(allImages[currentImageIndex]))
                            .font(ThemeManager.Typography.caption1)
                            .foregroundStyle(AppColors.textTertiary)

                    } else if let imageName = allImages.first {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 260)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                            )

                        Text(landmarkDisplayName(imageName))
                            .font(ThemeManager.Typography.caption1)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    // Country info
                    VStack(spacing: ThemeManager.Spacing.sm) {
                        Text(countryData?.flag ?? "🏳️")
                            .font(.system(size: 56))

                        Text(countryData?.localizedName ?? stamp.countryCode)
                            .font(ThemeManager.Typography.title2)
                            .foregroundStyle(AppColors.textPrimary)

                        Text(stamp.countryCode)
                            .font(ThemeManager.Typography.caption1Bold)
                            .foregroundStyle(AppColors.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(AppColors.primary.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    // Details card
                    VStack(spacing: 0) {
                        detailRow(
                            icon: "calendar",
                            label: LocalizationManager.shared.currentLanguage == "tr" ? "Ziyaret Tarihi" : "Visit Date",
                            value: stamp.stampDate.formatted(date: .long, time: .omitted)
                        )

                        if allImages.count > 1 {
                            Divider().background(AppColors.cardBorder).padding(.horizontal)
                            detailRow(
                                icon: "photo.stack",
                                label: LocalizationManager.shared.currentLanguage == "tr" ? "Görsel Sayısı" : "Landmarks",
                                value: "\(allImages.count)"
                            )
                        }
                    }
                    .cardStyle()
                }
                .padding(ThemeManager.Spacing.lg)
            }
            .background(AppColors.background)
            .navigationTitle(countryData?.localizedName ?? stamp.countryCode)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(AppColors.primary)
                .frame(width: 24)
            Text(label)
                .font(ThemeManager.Typography.subheadline)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(ThemeManager.Typography.subheadlineBold)
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(ThemeManager.Spacing.md)
    }

    private func landmarkDisplayName(_ imagePath: String) -> String {
        imagePath.replacingOccurrences(of: "Stamps/", with: "")
    }
}

// MARK: - Achievement Card (with Progress Bar)

struct AchievementCard: View {
    let achievement: AchievementStamp
    let isUnlocked: Bool
    let currentValue: Int

    private var progress: Double {
        guard achievement.threshold > 0 else { return 0 }
        return min(Double(currentValue) / Double(achievement.threshold), 1.0)
    }

    private var achievementIcon: String {
        switch achievement.requirement {
        case .countriesVisited: return isUnlocked ? "flag.fill" : "flag"
        case .citiesVisited: return isUnlocked ? "building.2.fill" : "building.2"
        case .tripsCompleted: return isUnlocked ? "airplane.circle.fill" : "airplane.circle"
        case .continentsVisited: return isUnlocked ? "globe.americas.fill" : "globe.americas"
        case .worldExplorer: return isUnlocked ? "sparkles" : "sparkle"
        }
    }

    private var achievementColor: Color {
        guard isUnlocked else { return AppColors.textTertiary }
        switch achievement.requirement {
        case .countriesVisited: return AppColors.success
        case .citiesVisited: return AppColors.info
        case .tripsCompleted: return AppColors.warning
        case .continentsVisited: return AppColors.primary
        case .worldExplorer: return AppColors.accent
        }
    }

    var body: some View {
        VStack(spacing: ThemeManager.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(achievementColor.opacity(isUnlocked ? 0.15 : 0.05))
                    .frame(width: 50, height: 50)

                if isUnlocked {
                    Circle()
                        .stroke(achievementColor.opacity(0.3), lineWidth: 1)
                        .frame(width: 50, height: 50)
                }

                Image(systemName: achievementIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(achievementColor)
            }

            Text(achievement.localizedName)
                .font(ThemeManager.Typography.caption1Bold)
                .foregroundStyle(isUnlocked ? AppColors.textPrimary : AppColors.textTertiary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 30)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.surfaceLighter)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(achievementColor)
                        .frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, ThemeManager.Spacing.xs)

            Text("\(min(currentValue, achievement.threshold))/\(achievement.threshold)")
                .font(ThemeManager.Typography.caption2)
                .foregroundStyle(isUnlocked ? achievementColor : AppColors.textDisabled)

            if let desc = achievement.localizedDescription {
                Text(desc)
                    .font(.custom("SpaceMono-Regular", size: 9))
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ThemeManager.Spacing.sm)
        .background(AppColors.surface)
        .cornerRadius(ThemeManager.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                .stroke(
                    isUnlocked ? achievementColor.opacity(0.3) : AppColors.cardBorder,
                    lineWidth: isUnlocked ? 1 : 0.5
                )
        )
        .shadow(
            color: isUnlocked ? achievementColor.opacity(0.1) : .clear,
            radius: isUnlocked ? 6 : 0,
            y: isUnlocked ? 3 : 0
        )
        .opacity(isUnlocked ? 1 : 0.7)
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    var tint: Color = AppColors.primary

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 28)

            Text(label)
                .font(ThemeManager.Typography.subheadline)
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            Text(value)
                .font(ThemeManager.Typography.headline)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, ThemeManager.Spacing.md)
        .padding(.vertical, ThemeManager.Spacing.sm)
    }
}

// MARK: - View Model

@MainActor
class PassportViewModel: ObservableObject {
    @Published var stamps: [UserStamp] = []
    @Published var achievements: [AchievementStamp] = []
    @Published var unlockedAchievementIds: Set<String> = []
    @Published var stats = PassportStats.empty
    @Published var isLoading = false

    private var userId: String {
        if let id = UserDefaults.standard.string(forKey: "localUserId") {
            return id
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "localUserId")
        return newId
    }

    // MARK: - Predefined Achievements

    static let predefinedAchievements: [AchievementStamp] = [
        AchievementStamp(id: "ach_first_country", name: "First Steps", nameTr: "İlk Adımlar",
                         description: "Visit your first country", descriptionTr: "İlk ülkeni ziyaret et",
                         imageUrl: "", requirement: .countriesVisited, threshold: 1,
                         isPremium: false, isActive: true, createdAt: Date()),
        AchievementStamp(id: "ach_5_countries", name: "Explorer", nameTr: "Kaşif",
                         description: "Visit 5 countries", descriptionTr: "5 ülke ziyaret et",
                         imageUrl: "", requirement: .countriesVisited, threshold: 5,
                         isPremium: false, isActive: true, createdAt: Date()),
        AchievementStamp(id: "ach_10_countries", name: "Globetrotter", nameTr: "Dünya Gezgini",
                         description: "Visit 10 countries", descriptionTr: "10 ülke ziyaret et",
                         imageUrl: "", requirement: .countriesVisited, threshold: 10,
                         isPremium: false, isActive: true, createdAt: Date()),
        AchievementStamp(id: "ach_25_countries", name: "World Traveler", nameTr: "Dünya Yolcusu",
                         description: "Visit 25 countries", descriptionTr: "25 ülke ziyaret et",
                         imageUrl: "", requirement: .countriesVisited, threshold: 25,
                         isPremium: false, isActive: true, createdAt: Date()),
        AchievementStamp(id: "ach_50_countries", name: "Passport Master", nameTr: "Pasaport Ustası",
                         description: "Visit 50 countries", descriptionTr: "50 ülke ziyaret et",
                         imageUrl: "", requirement: .countriesVisited, threshold: 50,
                         isPremium: false, isActive: true, createdAt: Date()),

        AchievementStamp(id: "ach_first_city", name: "City Starter", nameTr: "Şehir Kaşifi",
                         description: "Visit your first city", descriptionTr: "İlk şehrini ziyaret et",
                         imageUrl: "", requirement: .citiesVisited, threshold: 1,
                         isPremium: false, isActive: true, createdAt: Date()),
        AchievementStamp(id: "ach_10_cities", name: "Urban Explorer", nameTr: "Şehir Gezgini",
                         description: "Visit 10 cities", descriptionTr: "10 şehir ziyaret et",
                         imageUrl: "", requirement: .citiesVisited, threshold: 10,
                         isPremium: false, isActive: true, createdAt: Date()),
        AchievementStamp(id: "ach_25_cities", name: "City Hopper", nameTr: "Şehir Kurdu",
                         description: "Visit 25 cities", descriptionTr: "25 şehir ziyaret et",
                         imageUrl: "", requirement: .citiesVisited, threshold: 25,
                         isPremium: false, isActive: true, createdAt: Date()),
        AchievementStamp(id: "ach_50_cities", name: "Metropolis", nameTr: "Metropol Avcısı",
                         description: "Visit 50 cities", descriptionTr: "50 şehir ziyaret et",
                         imageUrl: "", requirement: .citiesVisited, threshold: 50,
                         isPremium: false, isActive: true, createdAt: Date()),

        AchievementStamp(id: "ach_2_continents", name: "Continental", nameTr: "Kıtalar Arası",
                         description: "Visit 2 continents", descriptionTr: "2 kıta ziyaret et",
                         imageUrl: "", requirement: .continentsVisited, threshold: 2,
                         isPremium: false, isActive: true, createdAt: Date()),
        AchievementStamp(id: "ach_3_continents", name: "Three Worlds", nameTr: "Üç Dünya",
                         description: "Visit 3 continents", descriptionTr: "3 kıta ziyaret et",
                         imageUrl: "", requirement: .continentsVisited, threshold: 3,
                         isPremium: false, isActive: true, createdAt: Date()),
        AchievementStamp(id: "ach_5_continents", name: "World Citizen", nameTr: "Dünya Vatandaşı",
                         description: "Visit all 5 continents", descriptionTr: "5 kıtayı da ziyaret et",
                         imageUrl: "", requirement: .continentsVisited, threshold: 5,
                         isPremium: false, isActive: true, createdAt: Date()),

        AchievementStamp(id: "ach_5_percent", name: "Getting Started", nameTr: "Yolun Başı",
                         description: "Explore 5% of the world", descriptionTr: "Dünyanın %5'ini keşfet",
                         imageUrl: "", requirement: .worldExplorer, threshold: 5,
                         isPremium: false, isActive: true, createdAt: Date()),
        AchievementStamp(id: "ach_10_percent", name: "World Explorer", nameTr: "Dünya Kaşifi",
                         description: "Explore 10% of the world", descriptionTr: "Dünyanın %10'unu keşfet",
                         imageUrl: "", requirement: .worldExplorer, threshold: 10,
                         isPremium: false, isActive: true, createdAt: Date()),
        AchievementStamp(id: "ach_25_percent", name: "Quarter Globe", nameTr: "Çeyrek Dünya",
                         description: "Explore 25% of the world", descriptionTr: "Dünyanın %25'ini keşfet",
                         imageUrl: "", requirement: .worldExplorer, threshold: 25,
                         isPremium: true, isActive: true, createdAt: Date()),
    ]

    // MARK: - Current Progress for Achievement

    func currentProgress(for achievement: AchievementStamp) -> Int {
        switch achievement.requirement {
        case .countriesVisited: return stats.countriesVisited
        case .citiesVisited: return stats.citiesVisited
        case .tripsCompleted: return UserDefaults.standard.integer(forKey: "tripsCount")
        case .continentsVisited: return stats.continentsVisited
        case .worldExplorer: return Int(stats.worldPercentage)
        }
    }

    // MARK: - Load Data

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        var allRegions: [VisitedRegion] = []
        var allCities: [VisitedCity] = []

        // Giriş yapılmışsa Supabase'den çek, yoksa UserDefaults'tan oku
        if UserManager.shared.isSignedIn, let signedInUserId = UserManager.shared.userId {
            // Supabase'den çek
            do {
                let supabaseRegions = try await SupabaseService.shared.fetchVisitedRegions(userId: signedInUserId)
                allRegions = supabaseRegions

                // Yerel depolamayı güncelle (offline erişim için)
                if let data = try? JSONEncoder().encode(supabaseRegions) {
                    UserDefaults.standard.set(data, forKey: "visitedRegions")
                }
            } catch {
                allRegions = loadLocalRegions()
            }

            // Yerel şehirleri oku (şehirler henüz Supabase'de sync edilmiyor)
            allCities = loadLocalCities()
        } else {
            // Giriş yapılmamış — sadece yerel veri
            allRegions = loadLocalRegions()
            allCities = loadLocalCities()
        }

        let visitedRegions = allRegions.filter { $0.status == .visited }
        let visitedCityList = allCities.filter { $0.status == .visited }

        stamps = visitedRegions.map { region in
            UserStamp(
                id: "stamp_\(region.countryCode)",
                userId: userId,
                countryCode: region.countryCode,
                stampDate: region.visitedAt ?? region.createdAt,
                tripId: nil,
                stampVariantId: nil,
                displayVariantId: nil,
                usedVariantIds: [],
                createdAt: region.createdAt
            )
        }.sorted { $0.stampDate > $1.stampDate }

        let continentsVisited = calculateContinents(from: visitedRegions)
        let worldPercentage = Double(visitedRegions.count) / 195.0 * 100

        achievements = Self.predefinedAchievements

        var unlocked = Set<String>()
        for achievement in achievements {
            let currentValue: Int
            switch achievement.requirement {
            case .countriesVisited:
                currentValue = visitedRegions.count
            case .citiesVisited:
                currentValue = visitedCityList.count
            case .tripsCompleted:
                currentValue = UserDefaults.standard.integer(forKey: "tripsCount")
            case .continentsVisited:
                currentValue = continentsVisited
            case .worldExplorer:
                currentValue = Int(worldPercentage)
            }
            if currentValue >= achievement.threshold {
                unlocked.insert(achievement.id)
            }
        }
        unlockedAchievementIds = unlocked

        stats = PassportStats(
            countriesVisited: visitedRegions.count,
            citiesVisited: visitedCityList.count,
            continentsVisited: continentsVisited,
            totalStamps: stamps.count,
            achievementsUnlocked: unlocked.count,
            worldPercentage: worldPercentage
        )
    }

    // MARK: - Local Data Access

    private func loadLocalRegions() -> [VisitedRegion] {
        guard let data = UserDefaults.standard.data(forKey: "visitedRegions"),
              let regions = try? JSONDecoder().decode([VisitedRegion].self, from: data) else { return [] }
        return regions
    }

    private func loadLocalCities() -> [VisitedCity] {
        guard let data = UserDefaults.standard.data(forKey: "visitedCities"),
              let cities = try? JSONDecoder().decode([VisitedCity].self, from: data) else { return [] }
        return cities
    }

    private func calculateContinents(from regions: [VisitedRegion]) -> Int {
        let continents = Set(regions.compactMap { CountryUtils.getContinent(code: $0.countryCode) })
        return continents.count
    }

    func exportPDF() {
    }
}

// MARK: - Array Chunking Helper

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#Preview {
    PassportView()
}
