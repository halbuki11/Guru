import SwiftUI
import NukeUI
import Nuke

// MARK: - ExploreView (Netflix Cinematic Design v2)
struct ExploreView: View {
    @AppStorage("userName") private var userName: String = ""
    @StateObject private var viewModel = ExploreViewModel()
    @State private var showCreateTrip = false
    @State private var eventHeroIndex = 0
    @State private var eventHeroTimer: Timer?
    @State private var aiPulse = false
    @State private var contentAppeared = false
    @State private var isRefreshing = false
    @State private var prefetcher = ImagePrefetchCoordinator()

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        if viewModel.isLoading && !isRefreshing {
                            cinematicLoadingView
                        } else {
                            // 1) Cinematic Hero
                            cinematicHero

                            // 2) Content
                            cinematicFeed
                                .opacity(contentAppeared ? 1 : 0)
                                .offset(y: contentAppeared ? 0 : 20)
                        }
                    }
                    .frame(width: geo.size.width)
                    .clipped()
                    .padding(.bottom, 40)
                }
                .refreshable {
                    isRefreshing = true
                    stopTimers()
                    await viewModel.refreshData()
                    isRefreshing = false
                    startTimers()
                }
            }
            .background(AppColors.background)
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showCreateTrip) { CreateTripView() }
        }
        .task {
            await viewModel.loadData()
            prefetchImages()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                contentAppeared = true
            }
        }
        .onAppear { startTimers() }
        .onDisappear {
            stopTimers()
            prefetcher.cancelAll()
        }
    }

    // MARK: - Timers
    private func startTimers() {
        eventHeroTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
            let count = viewModel.events.isEmpty
                ? max(viewModel.heroDestinations.count, 1)
                : viewModel.events.count
            guard count > 1 else { return }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                eventHeroIndex = (eventHeroIndex + 1) % count
            }
        }
    }

    private func stopTimers() {
        eventHeroTimer?.invalidate()
        eventHeroTimer = nil
    }

    // MARK: - Image Prefetching
    private func prefetchImages() {
        // Prefetch ALL hero event images (highest priority)
        let eventURLs = viewModel.events.compactMap { $0.imageUrl }
        prefetcher.prefetchURLs(eventURLs, tier: .hero)

        // Prefetch destination cards
        prefetcher.prefetchDestinations(Array(viewModel.allDestinations.prefix(10)), tier: .card)
    }

    // MARK: - Cinematic Loading (Skeleton)
    private var cinematicLoadingView: some View {
        let screenW = UIScreen.main.bounds.width
        return VStack(spacing: 32) {
            // Hero skeleton
            RoundedRectangle(cornerRadius: 0)
                .fill(AppColors.surface)
                .frame(height: 460)
                .shimmer()

            // Row skeletons
            ForEach(0..<3, id: \.self) { i in
                VStack(alignment: .leading, spacing: 14) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.surface)
                        .frame(width: CGFloat(140 + i * 30), height: 20)
                        .shimmer()
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppColors.surface)
                                    .frame(width: screenW * 0.75, height: 200)
                                    .shimmer()
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    // MARK: - Cinematic Hero (Full Bleed, 460pt, Enhanced)
    private var cinematicHero: some View {
        let heroEvents = viewModel.events
        let screenW = UIScreen.main.bounds.width
        let heroH: CGFloat = 460

        if !heroEvents.isEmpty {
            let safeIndex = eventHeroIndex % max(heroEvents.count, 1)
            let event = heroEvents[safeIndex]

            return AnyView(
                ZStack {
                    // Background event images with crossfade (show ALL events)
                    ForEach(Array(heroEvents.enumerated()), id: \.element.id) { i, e in
                        eventHeroImage(e)
                            .frame(width: screenW, height: heroH)
                            .clipped()
                            .opacity(i == safeIndex ? 1 : 0)
                            .scaleEffect(i == safeIndex ? 1.0 : 1.05)
                    }

                    // Multi-layer cinematic gradient
                    VStack(spacing: 0) {
                        // Top: status bar protection
                        LinearGradient(
                            colors: [AppColors.background.opacity(0.6), AppColors.background.opacity(0.2), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 120)

                        Spacer()

                        // Bottom: deep cinematic fade
                        LinearGradient(
                            colors: [
                                .clear,
                                AppColors.background.opacity(0.05),
                                AppColors.background.opacity(0.3),
                                AppColors.background.opacity(0.75),
                                AppColors.background.opacity(0.95),
                                AppColors.background
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 280)
                    }
                    .frame(width: screenW, height: heroH)

                    // Side vignette for cinematic feel
                    HStack(spacing: 0) {
                        LinearGradient(
                            colors: [AppColors.background.opacity(0.3), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 60)
                        Spacer()
                        LinearGradient(
                            colors: [.clear, AppColors.background.opacity(0.3)],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 60)
                    }
                    .frame(width: screenW, height: heroH)

                    // Content overlay
                    VStack {
                        // Top: Greeting — premium split style
                        HStack(spacing: 10) {
                            Image(systemName: greetingIcon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(greetingLine)
                                    .font(.custom("SpaceMono-Regular", size: 11))
                                    .tracking(0.8)
                                    .foregroundStyle(.white.opacity(0.5))
                                Text(greetingName)
                                    .font(.custom("SpaceMono-Bold", size: 17))
                                    .foregroundStyle(.white.opacity(0.95))
                            }
                            Spacer()
                        }
                        .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
                        .padding(.horizontal, 20)
                        .padding(.top, 62)

                        Spacer()

                        // Bottom: Event info (cinematic, enhanced)
                        VStack(alignment: .leading, spacing: 14) {
                            // Category pill + Tour badge
                            HStack(spacing: 6) {
                                HStack(spacing: 5) {
                                    Image(systemName: event.categoryIcon)
                                        .font(.system(size: 10))
                                    Text((event.category ?? "Event").uppercased())
                                        .font(.custom("SpaceMono-Bold", size: 9))
                                        .tracking(1.2)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(event.categoryColor.opacity(0.85)))

                                // Tur etiketi (endDate varsa, eventDate'den farklıysa VE festival değilse)
                                // Festivallerin doğal olarak başlangıç-bitiş tarihi var, tur değiller
                                if let end = event.endDate, let start = event.eventDate, end != start,
                                   (event.category ?? "").lowercased() != "festival" {
                                    HStack(spacing: 3) {
                                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                                            .font(.system(size: 8))
                                        Text("explore.tourLabel".localized)
                                            .font(.custom("SpaceMono-Bold", size: 9))
                                            .tracking(1.0)
                                    }
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(.white.opacity(0.15)))
                                }
                            }

                            // Title (cinematic, larger)
                            Text(event.localizedName)
                                .font(.custom("SpaceMono-Bold", size: 30))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .shadow(color: .black.opacity(0.6), radius: 10, y: 3)
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 1)

                            // Subtitle row
                            HStack(spacing: 16) {
                                HStack(spacing: 5) {
                                    Image(systemName: "mappin")
                                        .font(.system(size: 12))
                                    Text(event.city ?? event.localizedCountry)
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundStyle(.white.opacity(0.85))

                                HStack(spacing: 5) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 12))
                                    Text(event.formattedDateRange)
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundStyle(.white.opacity(0.85))
                            }

                            // CTA buttons (Netflix style, enhanced)
                            HStack(spacing: 12) {
                                if let url = event.ticketUrl, !url.isEmpty {
                                    Button {
                                        if let ticketURL = URL(string: url) {
                                            UIApplication.shared.open(ticketURL)
                                        }
                                    } label: {
                                        HStack(spacing: 7) {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 12))
                                            Text("explore.getTickets".localized)
                                                .font(.custom("SpaceMono-Bold", size: 13))
                                        }
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Capsule().fill(.white))
                                    }
                                }

                                if let dest = viewModel.destinationForEvent(event) {
                                    NavigationLink(destination: DestinationDetailView(destination: dest)) {
                                        HStack(spacing: 7) {
                                            Image(systemName: "info.circle")
                                                .font(.system(size: 13))
                                            Text("explore.moreInfo".localized)
                                                .font(.custom("SpaceMono-Bold", size: 13))
                                        }
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(
                                            Capsule()
                                                .fill(.white.opacity(0.12))
                                                .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
                                        )
                                    }
                                }
                            }

                            // Netflix-style progress bar (all events)
                            heroProgressBar(
                                count: heroEvents.count,
                                current: safeIndex
                            )
                            .padding(.top, 6)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    .frame(width: screenW, height: heroH)
                }
                .frame(width: screenW, height: heroH)
                .clipped()
            )
        } else {
            return AnyView(destinationFallbackHero)
        }
    }

    // Netflix-style thin progress bar
    private func heroProgressBar(count: Int, current: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i == current ? .white : .white.opacity(0.25))
                    .frame(height: 2.5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: current)
            }
        }
    }

    // Event hero image helper (Nuke cached, HD, device-aware)
    // Ticketmaster images: tries optimized URL first, falls back to original URL
    @ViewBuilder
    private func eventHeroImage(_ event: EventDB) -> some View {
        let w = UIScreen.main.bounds.width
        let h: CGFloat = 460
        let scale = UIScreen.main.scale
        let rawUrl = event.imageUrl ?? ""
        let optimizedUrl = ImageURLBuilder.optimizedURL(rawUrl, tier: .hero)
        let processorSize = CGSize(
            width: min(w * scale, ImageURLBuilder.Tier.hero.maxPixelWidth),
            height: h * scale
        )

        if !optimizedUrl.isEmpty, let imageURL = URL(string: optimizedUrl) {
            LazyImage(url: imageURL) { state in
                if let image = state.image {
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: w, height: h)
                        .clipped()
                        .transition(.opacity.animation(.easeIn(duration: 0.3)))
                } else if state.error != nil {
                    // Optimized URL failed — try original URL as fallback
                    if optimizedUrl != rawUrl, let fallbackURL = URL(string: rawUrl) {
                        LazyImage(url: fallbackURL) { fallbackState in
                            if let img = fallbackState.image {
                                img.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: w, height: h)
                                    .clipped()
                            } else {
                                eventImageFallback(event)
                            }
                        }
                        .processors([.resize(size: processorSize, contentMode: .aspectFill)])
                        .priority(.high)
                    } else {
                        eventImageFallback(event)
                    }
                } else {
                    event.categoryColor
                        .shimmer()
                }
            }
            .processors([.resize(size: processorSize, contentMode: .aspectFill)])
            .priority(.veryHigh)
        } else {
            eventImageFallback(event)
        }
    }

    // NOTE: Image URL optimization is now handled by ImageURLBuilder in ImagePipelineConfig.swift

    // Cinematic fallback gradient for event hero images
    @ViewBuilder
    private func eventImageFallback(_ event: EventDB) -> some View {
        ZStack {
            // Multi-layer gradient for cinematic depth
            LinearGradient(
                colors: [
                    event.categoryColor.opacity(0.9),
                    event.categoryColor.opacity(0.6),
                    Color.black.opacity(0.7)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            // Radial glow behind icon
            RadialGradient(
                colors: [event.categoryColor.opacity(0.4), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 200
            )
            // Category icon
            VStack(spacing: 12) {
                Image(systemName: event.categoryIcon)
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(.white.opacity(0.35))
                Text(event.localizedName)
                    .font(.custom("SpaceMono-Bold", size: 14))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }
        }
    }

    // Event card fallback (smaller, same style)
    @ViewBuilder
    private func eventCardFallback(_ event: EventDB) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    event.categoryColor.opacity(0.9),
                    event.categoryColor.opacity(0.5),
                    Color.black.opacity(0.6)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: event.categoryIcon)
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    // Destination fallback hero (when no events — cinematic style)
    private var destinationFallbackHero: some View {
        let heroes = viewModel.heroDestinations
        guard !heroes.isEmpty else { return AnyView(EmptyView()) }
        let safeIndex = eventHeroIndex % max(heroes.count, 1)
        let dest = heroes[safeIndex]
        let screenW = UIScreen.main.bounds.width
        let heroH: CGFloat = 460

        return AnyView(
            ZStack {
                ForEach(Array(heroes.enumerated()), id: \.element.name) { i, d in
                    DestinationImageView(url: d.imageURL, gradient: d.gradient, tier: .hero)
                        .frame(width: screenW, height: heroH)
                        .clipped()
                        .opacity(i == safeIndex ? 1 : 0)
                        .scaleEffect(i == safeIndex ? 1.0 : 1.05)
                }

                // Multi-layer cinematic gradient
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [AppColors.background.opacity(0.6), AppColors.background.opacity(0.2), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 120)

                    Spacer()

                    LinearGradient(
                        colors: [
                            .clear,
                            AppColors.background.opacity(0.05),
                            AppColors.background.opacity(0.3),
                            AppColors.background.opacity(0.75),
                            AppColors.background.opacity(0.95),
                            AppColors.background
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 280)
                }
                .frame(width: screenW, height: heroH)

                // Side vignette
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [AppColors.background.opacity(0.3), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: 60)
                    Spacer()
                    LinearGradient(
                        colors: [.clear, AppColors.background.opacity(0.3)],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: 60)
                }
                .frame(width: screenW, height: heroH)

                // Content overlay
                VStack {
                    // Top: Greeting — premium split style
                    HStack(spacing: 10) {
                        Image(systemName: greetingIcon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(greetingLine)
                                .font(.custom("SpaceMono-Regular", size: 11))
                                .tracking(0.8)
                                .foregroundStyle(.white.opacity(0.5))
                            Text(greetingName)
                                .font(.custom("SpaceMono-Bold", size: 17))
                                .foregroundStyle(.white.opacity(0.95))
                        }
                        Spacer()
                    }
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
                    .padding(.horizontal, 20)
                    .padding(.top, 62)

                    Spacer()

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 5) {
                            Image(systemName: dest.categoryInfo.icon)
                                .font(.system(size: 10))
                            Text(dest.categoryInfo.displayName.uppercased())
                                .font(.custom("SpaceMono-Bold", size: 9))
                                .tracking(1.2)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(dest.categoryInfo.color.opacity(0.85)))

                        Text(dest.localizedName)
                            .font(.custom("SpaceMono-Bold", size: 30))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.6), radius: 10, y: 3)
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 1)

                        HStack(spacing: 16) {
                            Text(dest.localizedCountry)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))

                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppColors.primary)
                                Text(String(format: "%.1f", dest.rating))
                                    .font(.custom("SpaceMono-Bold", size: 13))
                                    .foregroundStyle(.white)
                            }
                        }

                        NavigationLink(destination: DestinationDetailView(destination: dest)) {
                            HStack(spacing: 7) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12))
                                Text("explore.discover".localized)
                                    .font(.custom("SpaceMono-Bold", size: 13))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(.white))
                        }

                        heroProgressBar(count: heroes.count, current: safeIndex)
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .frame(width: screenW, height: heroH)
            }
            .frame(width: screenW, height: heroH)
            .contentShape(Rectangle())
            .clipped()
        )
    }

    // MARK: - Cinematic Feed
    private var cinematicFeed: some View {
        VStack(spacing: 40) {
            // 1) Destinations — tüm şehirler karışık
            if !viewModel.allDestinations.isEmpty {
                cinematicSection(
                    title: "explore.destinations".localized,
                    icon: "globe.europe.africa.fill",
                    iconColor: AppColors.primary
                ) {
                    cinematicDestinationRow(viewModel.allDestinations.shuffled())
                }
            }

            // 2) Upcoming Events
            if !viewModel.events.isEmpty {
                cinematicSection(
                    title: "explore.upcomingEvents".localized,
                    icon: "calendar.badge.clock",
                    iconColor: Color(hex: "E91E63"),
                    showSeeAll: viewModel.events.count > 6,
                    seeAllDestination: AnyView(AllEventsView(events: viewModel.events))
                ) {
                    cinematicEventRow(viewModel.events)
                }
            }

            // 3) AI Banner
            cinematicAIBanner
                .padding(.top, 4)
        }
        .padding(.top, 24)
    }

    // MARK: - Cinematic Section Header (Enhanced with icon)
    private func cinematicSection<Content: View>(
        title: String,
        icon: String? = nil,
        iconColor: Color = AppColors.primary,
        subtitle: String? = nil,
        showSeeAll: Bool = false,
        seeAllDestination: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundStyle(iconColor)
                    }

                    Text(title)
                        .font(.custom("SpaceMono-Bold", size: 18))
                        .foregroundStyle(AppColors.textPrimary)

                    // Subtle accent line
                    Rectangle()
                        .fill(AppColors.primary.opacity(0.15))
                        .frame(height: 1)

                    if showSeeAll, let dest = seeAllDestination {
                        NavigationLink(destination: dest) {
                            HStack(spacing: 4) {
                                Text("explore.seeAll".localized)
                                    .font(.custom("SpaceMono-Bold", size: 12))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(AppColors.primary)
                        }
                    }
                }

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, 20)

            content()
        }
    }

    // MARK: - Trending Row (Netflix Top 10 Style)
    // MARK: - Cinematic Destination Row (Snap Scroll)
    private func cinematicDestinationRow(_ destinations: [DestinationInfo]) -> some View {
        let screenW = UIScreen.main.bounds.width
        let cardW: CGFloat = screenW * 0.75
        let cardH: CGFloat = 200

        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(destinations, id: \.name) { dest in
                    NavigationLink(destination: DestinationDetailView(destination: dest)) {
                        cinematicDestinationCard(dest, width: cardW, height: cardH)
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 20)
        }
        .scrollTargetBehavior(.viewAligned)
    }

    // MARK: - Cinematic Destination Card (Enhanced)
    private func cinematicDestinationCard(_ dest: DestinationInfo, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            DestinationImageView(url: dest.imageURL, gradient: dest.gradient, tier: .card)
                .frame(width: width, height: height)

            LinearGradient(
                colors: [.clear, .black.opacity(0.15), .black.opacity(0.75)],
                startPoint: .top, endPoint: .bottom
            )

            // Category badge top-left
            VStack {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: dest.categoryInfo.icon)
                            .font(.system(size: 9))
                        Text(dest.categoryInfo.displayName)
                            .font(.custom("SpaceMono-Bold", size: 9))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(dest.categoryInfo.color.opacity(0.85)))
                    .padding(14)
                    Spacer()
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(dest.localizedName)
                    .font(.custom("SpaceMono-Bold", size: 22))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.6), radius: 8, y: 2)

                HStack(spacing: 12) {
                    Text(dest.localizedCountry)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))

                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.primary)
                        Text(String(format: "%.1f", dest.rating))
                            .font(.custom("SpaceMono-Bold", size: 12))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(16)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }

    // MARK: - Cinematic Event Row (Snap Scroll)
    private func cinematicEventRow(_ events: [EventDB]) -> some View {
        let screenW = UIScreen.main.bounds.width
        let cardW: CGFloat = screenW * 0.75
        let cardH: CGFloat = 210

        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(events, id: \.id) { event in
                    cinematicEventCard(event, width: cardW, height: cardH)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 20)
        }
        .scrollTargetBehavior(.viewAligned)
    }

    // MARK: - Cinematic Event Card (Enhanced)
    private func cinematicEventCard(_ event: EventDB, width: CGFloat, height: CGFloat) -> some View {
        let daysLeft = viewModel.daysUntilEvent(event)

        let rawUrl = event.imageUrl ?? ""
        let optimizedUrl = ImageURLBuilder.optimizedURL(rawUrl, tier: .card)
        let cardProcessorSize = CGSize(
            width: min(width * UIScreen.main.scale, ImageURLBuilder.Tier.card.maxPixelWidth),
            height: height * UIScreen.main.scale
        )

        return ZStack(alignment: .bottomLeading) {
            // Full image (device-aware quality, fallback to original URL)
            if !optimizedUrl.isEmpty, let imageURL = URL(string: optimizedUrl) {
                LazyImage(url: imageURL) { state in
                    if let image = state.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: width, height: height)
                            .clipped()
                            .transition(.opacity.animation(.easeIn(duration: 0.25)))
                    } else if state.error != nil {
                        // Try original URL if optimized failed
                        if optimizedUrl != rawUrl, let fallbackURL = URL(string: rawUrl) {
                            LazyImage(url: fallbackURL) { fs in
                                if let img = fs.image {
                                    img.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: width, height: height)
                                        .clipped()
                                } else {
                                    eventCardFallback(event)
                                        .frame(width: width, height: height)
                                }
                            }
                            .processors([.resize(size: cardProcessorSize, contentMode: .aspectFill)])
                        } else {
                            eventCardFallback(event)
                                .frame(width: width, height: height)
                        }
                    } else {
                        event.categoryColor.opacity(0.3)
                            .frame(width: width, height: height)
                            .shimmer()
                    }
                }
                .processors([.resize(size: cardProcessorSize, contentMode: .aspectFill)])
                .priority(.high)
            } else {
                eventCardFallback(event)
                    .frame(width: width, height: height)
            }

            // Cinematic gradient
            LinearGradient(
                colors: [.clear, .black.opacity(0.15), .black.opacity(0.8)],
                startPoint: .top, endPoint: .bottom
            )

            // Top badges
            VStack {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: event.categoryIcon)
                            .font(.system(size: 9))
                        Text((event.category ?? "Event").uppercased())
                            .font(.custom("SpaceMono-Bold", size: 8))
                            .tracking(0.8)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(event.categoryColor.opacity(0.85)))

                    Spacer()

                    if let days = daysLeft {
                        Text(days == 0 ? "explore.today".localized :
                             days == 1 ? "explore.tomorrow".localized :
                             String(format: "explore.daysLeft".localized, days))
                            .font(.custom("SpaceMono-Bold", size: 10))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(
                                    days <= 7 ? Color(hex: "E74C3C").opacity(0.9) :
                                    days <= 21 ? Color(hex: "F39C12").opacity(0.9) :
                                    AppColors.primary.opacity(0.9)
                                )
                            )
                    }
                }
                .padding(14)
                Spacer()
            }

            // Bottom: event info
            VStack(alignment: .leading, spacing: 7) {
                Text(event.localizedName)
                    .font(.custom("SpaceMono-Bold", size: 22))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.6), radius: 8, y: 2)

                HStack(spacing: 16) {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin")
                            .font(.system(size: 11))
                        Text(event.city ?? event.localizedCountry)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.85))

                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text(event.formattedDateRange)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }

                if let dest = viewModel.destinationForEvent(event) {
                    NavigationLink(destination: DestinationDetailView(destination: dest)) {
                        HStack(spacing: 4) {
                            Text(String(format: "explore.discoverCountry".localized, dest.localizedCountry))
                                .font(.custom("SpaceMono-Bold", size: 11))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(AppColors.primary)
                    }
                }
            }
            .padding(16)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        .onTapGesture {
            if let url = event.ticketUrl, let ticketURL = URL(string: url) {
                UIApplication.shared.open(ticketURL)
            }
        }
    }

    // MARK: - Category Chips (Enhanced with animation)
    // MARK: - Cinematic AI Banner (Enhanced)
    private var cinematicAIBanner: some View {
        Button { showCreateTrip = true } label: {
            ZStack {
                // Background with richer gradient
                LinearGradient(
                    colors: [
                        AppColors.primary.opacity(0.15),
                        AppColors.primary.opacity(0.05),
                        AppColors.surface
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )

                HStack(spacing: 16) {
                    // AI icon with enhanced pulse
                    ZStack {
                        Circle()
                            .fill(AppColors.primary.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Circle()
                            .fill(AppColors.primary.opacity(aiPulse ? 0.06 : 0))
                            .frame(width: 68, height: 68)
                            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: aiPulse)
                        Image(systemName: "sparkles")
                            .font(.system(size: 22))
                            .foregroundStyle(AppColors.primary)
                            .symbolEffect(.pulse, options: .repeating)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("explore.planWithAITitle".localized)
                            .font(.custom("SpaceMono-Bold", size: 15))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("explore.planWithAIDesc".localized)
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppColors.primary)
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: AppColors.primary.opacity(0.1), radius: 12, y: 4)
        }
        .padding(.horizontal, 20)
        .onAppear { aiPulse = true }
    }

    // MARK: - Greeting
    private var greetingLine: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "explore.greeting.morning".localized
        case 12..<18: return "explore.greeting.afternoon".localized
        case 18..<23: return "explore.greeting.evening".localized
        default:      return "explore.greeting.night".localized
        }
    }

    private var greetingIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "sun.max.fill"
        case 12..<18: return "sun.haze.fill"
        case 18..<23: return "moon.haze.fill"
        default:      return "moon.stars.fill"
        }
    }

    private var greetingName: String {
        userName.isEmpty ? "greeting.traveler".localized : userName
    }
}

// MARK: - Topic Destinations View
struct TopicDestinationsView: View {
    let title: String
    let icon: String
    let color: Color
    let destinations: [DestinationInfo]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(color.opacity(0.15)).frame(width: 60, height: 60)
                        Image(systemName: icon).font(.system(size: 26)).foregroundStyle(color)
                    }
                    Text(title)
                        .font(.custom("SpaceMono-Bold", size: 22))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(destinations.count) " + "magazine.destinations".localized)
                        .font(.custom("SpaceMono-Regular", size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.vertical, 20)

                if destinations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "map")
                            .font(.system(size: 40))
                            .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                        Text("explore.noDestinations".localized)
                            .font(.custom("SpaceMono-Regular", size: 15))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(destinations, id: \.name) { dest in
                            NavigationLink(destination: DestinationDetailView(destination: dest)) {
                                TopicDestinationRow(destination: dest)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 40)
        }
        .background(AppColors.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Topic Destination Row
struct TopicDestinationRow: View {
    let destination: DestinationInfo

    var body: some View {
        HStack(spacing: 12) {
            DestinationImageView(url: destination.imageURL, gradient: destination.gradient, tier: .thumbnail)
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(destination.localizedName)
                        .font(.custom("SpaceMono-Bold", size: 16))
                        .foregroundStyle(AppColors.textPrimary)
                    if destination.isFeatured {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(AppColors.primary)
                    }
                }
                Text(destination.localizedCountry)
                    .font(.custom("SpaceMono-Regular", size: 12))
                    .foregroundStyle(AppColors.textSecondary)
                HStack(spacing: 6) {
                    HStack(spacing: 2) {
                        Image(systemName: destination.categoryInfo.icon)
                            .font(.system(size: 8))
                        Text(destination.categoryInfo.displayName)
                            .font(.custom("SpaceMono-Bold", size: 9))
                    }
                    .foregroundStyle(destination.categoryInfo.color)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(destination.categoryInfo.color.opacity(0.12)))

                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(AppColors.primary)
                        Text(String(format: "%.1f", destination.rating))
                            .font(.custom("SpaceMono-Bold", size: 11))
                    }
                    .foregroundStyle(AppColors.textPrimary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textSecondary.opacity(0.5))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))
        )
    }
}

// MARK: - Category Filter Pill (compatibility)
struct CategoryFilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .medium))
                Text(title).font(.system(size: 13))
            }
            .foregroundStyle(isSelected ? .white : AppColors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? AppColors.primary : AppColors.surface))
            .overlay(Capsule().stroke(isSelected ? .clear : AppColors.cardBorder, lineWidth: 1))
        }
    }
}

// MARK: - Travel Category
enum TravelCategory: String, CaseIterable {
    case beach, mountain, city, historical, adventure, romantic

    var displayName: String {
        switch self {
        case .beach: return "category.beach".localized
        case .mountain: return "category.mountain".localized
        case .city: return "category.city".localized
        case .historical: return "category.historical".localized
        case .adventure: return "category.adventure".localized
        case .romantic: return "category.romantic".localized
        }
    }

    var emoji: String {
        switch self {
        case .beach: return "\u{1F3D6}\u{FE0F}"
        case .mountain: return "\u{1F3D4}\u{FE0F}"
        case .city: return "\u{1F3D9}\u{FE0F}"
        case .historical: return "\u{1F3DB}\u{FE0F}"
        case .adventure: return "\u{1F392}"
        case .romantic: return "\u{1F495}"
        }
    }

    var iconName: String {
        switch self {
        case .beach: return "sun.horizon.fill"
        case .mountain: return "mountain.2.fill"
        case .city: return "building.2.fill"
        case .historical: return "building.columns.fill"
        case .adventure: return "figure.hiking"
        case .romantic: return "heart.fill"
        }
    }
}

// MARK: - Destination Info Model
struct DestinationInfo {
    let name: String
    let country: String
    let emoji: String
    let description: String
    let rating: Double
    let trendPercentage: Int
    let seasonalTag: String
    let primaryColor: Color
    let secondaryColor: Color
    let imageURL: String
    let category: String
    let isFeatured: Bool
    // Localization fields (Turkish)
    let nameTr: String?
    let descriptionTr: String?
    let countryTr: String?
    let seasonalTagTr: String?
    var gradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var isTurkish: Bool {
        LocalizationManager.shared.currentLanguage == "tr"
    }

    var localizedName: String {
        if isTurkish, let tr = nameTr, !tr.isEmpty { return tr }
        return GeoLocalizer.localizeCity(name)
    }
    var localizedCountry: String {
        if isTurkish, let tr = countryTr, !tr.isEmpty { return tr }
        return GeoLocalizer.localizeCountry(country)
    }
    var localizedDescription: String {
        if isTurkish, let tr = descriptionTr, !tr.isEmpty { return tr }
        return description
    }
    var localizedSeasonalTag: String {
        if isTurkish, let tr = seasonalTagTr, !tr.isEmpty { return tr }
        let localized = seasonalTag.localized
        return localized != seasonalTag ? localized : seasonalTag
    }

    var categoryInfo: DestinationCategoryInfo {
        DestinationCategoryInfo.from(category)
    }

    func matchesCategory(_ category: TravelCategory) -> Bool {
        let tag = seasonalTag.lowercased()
        switch category {
        case .beach: return tag.contains("beach") || tag.contains("coast") || self.category == "beach"
        case .mountain: return tag.contains("mountain") || tag.contains("nature")
        case .city: return tag.contains("city") || tag.contains("urban")
        case .historical: return tag.contains("history") || tag.contains("culture") || self.category == "cultural"
        case .adventure: return tag.contains("adventure") || tag.contains("sport") || self.category == "adventure"
        case .romantic: return tag.contains("romantic") || tag.contains("honeymoon") || self.category == "romantic"
        }
    }
}

// MARK: - ImageURLProvider conformance
extension DestinationInfo: ImageURLProvider {
    var imageURLString: String { imageURL }
}

// MARK: - Category Info Helper
struct DestinationCategoryInfo {
    let key: String
    let icon: String
    let color: Color
    let displayName: String

    static func from(_ category: String) -> DestinationCategoryInfo {
        switch category.lowercased() {
        case "trending":
            return DestinationCategoryInfo(key: "trending", icon: "flame.fill", color: Color(hex: "FF6B35"), displayName: "explore.cat.trending".localized)
        case "cultural":
            return DestinationCategoryInfo(key: "cultural", icon: "theatermasks.fill", color: Color(hex: "9B59B6"), displayName: "explore.cat.cultural".localized)
        case "beach":
            return DestinationCategoryInfo(key: "beach", icon: "beach.umbrella.fill", color: Color(hex: "00B4D8"), displayName: "explore.cat.beach".localized)
        case "mountain":
            return DestinationCategoryInfo(key: "mountain", icon: "mountain.2.fill", color: Color(hex: "2D6A4F"), displayName: "explore.cat.mountain".localized)
        case "city":
            return DestinationCategoryInfo(key: "city", icon: "building.2.fill", color: Color(hex: "495057"), displayName: "explore.cat.city".localized)
        case "adventure":
            return DestinationCategoryInfo(key: "adventure", icon: "figure.hiking", color: Color(hex: "2ECC71"), displayName: "explore.cat.adventure".localized)
        case "wellness":
            return DestinationCategoryInfo(key: "wellness", icon: "heart.text.square.fill", color: Color(hex: "A8DADC"), displayName: "explore.cat.wellness".localized)
        case "island":
            return DestinationCategoryInfo(key: "island", icon: "water.waves", color: Color(hex: "0077B6"), displayName: "explore.cat.island".localized)
        case "nature":
            return DestinationCategoryInfo(key: "nature", icon: "leaf.fill", color: Color(hex: "52B788"), displayName: "explore.cat.nature".localized)
        case "historic":
            return DestinationCategoryInfo(key: "historic", icon: "building.columns.fill", color: Color(hex: "BC6C25"), displayName: "explore.cat.historic".localized)
        case "nightlife":
            return DestinationCategoryInfo(key: "nightlife", icon: "sparkles", color: Color(hex: "8E44AD"), displayName: "explore.cat.nightlife".localized)
        case "food":
            return DestinationCategoryInfo(key: "food", icon: "wineglass.fill", color: Color(hex: "E67E22"), displayName: "explore.cat.food".localized)
        case "winter":
            return DestinationCategoryInfo(key: "winter", icon: "snowflake", color: Color(hex: "48CAE4"), displayName: "explore.cat.winter".localized)
        case "romantic":
            return DestinationCategoryInfo(key: "romantic", icon: "heart.circle.fill", color: Color(hex: "E91E63"), displayName: "explore.cat.romantic".localized)
        case "hidden_gem":
            return DestinationCategoryInfo(key: "hidden_gem", icon: "diamond.fill", color: Color(hex: "5DADE2"), displayName: "explore.cat.hiddenGem".localized)
        case "luxury":
            return DestinationCategoryInfo(key: "luxury", icon: "star.circle.fill", color: Color(hex: "C9A96E"), displayName: "explore.cat.luxury".localized)
        case "family":
            return DestinationCategoryInfo(key: "family", icon: "figure.and.child.holdinghands", color: Color(hex: "3498DB"), displayName: "explore.cat.family".localized)
        case "historical":
            return DestinationCategoryInfo(key: "historical", icon: "clock.arrow.circlepath", color: Color(hex: "7F8C8D"), displayName: "explore.cat.historical".localized)
        case "spiritual":
            return DestinationCategoryInfo(key: "spiritual", icon: "sun.haze.fill", color: Color(hex: "1ABC9C"), displayName: "explore.cat.spiritual".localized)
        default:
            let locKey = "explore.cat.\(category)"
            let localized = locKey.localized
            let display = localized != locKey ? localized : category.replacingOccurrences(of: "_", with: " ").capitalized
            return DestinationCategoryInfo(key: category, icon: "globe.europe.africa.fill", color: AppColors.primary, displayName: display)
        }
    }
}

// MARK: - Destination Image View (Device-Aware, Progressive)
struct DestinationImageView: View {
    let url: String
    let gradient: LinearGradient
    var tier: ImageURLBuilder.Tier = .card

    var body: some View {
        let scale = UIScreen.main.scale
        GeometryReader { geo in
            let optimizedUrl = ImageURLBuilder.optimizedURL(url, tier: tier)
            if !optimizedUrl.isEmpty, let imageURL = URL(string: optimizedUrl) {
                LazyImage(url: imageURL) { state in
                    if let image = state.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .transition(.opacity.animation(.easeIn(duration: 0.25)))
                    } else if state.error != nil {
                        gradient
                            .frame(width: geo.size.width, height: geo.size.height)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.15))
                            )
                    } else {
                        // Loading: show gradient with subtle shimmer
                        gradient
                            .frame(width: geo.size.width, height: geo.size.height)
                            .shimmer()
                    }
                }
                .processors([
                    .resize(size: CGSize(
                        width: min(geo.size.width * scale, tier.maxPixelWidth),
                        height: geo.size.height * scale
                    ), contentMode: .aspectFill)
                ])
                .priority(tier == .hero ? .veryHigh : (tier == .card ? .high : .normal))
            } else {
                gradient
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

// MARK: - View Model
@MainActor
class ExploreViewModel: ObservableObject {
    @Published var destinations: [DestinationInfo] = []
    @Published var events: [EventDB] = []
    @Published var featuredDestination: DestinationInfo?
    @Published var currentQuote: String = ""
    @Published var currentAuthor: String = ""
    @Published var isLoading = false

    // Hero destinations: featured + top rated
    var heroDestinations: [DestinationInfo] {
        var heroes: [DestinationInfo] = []
        var seen = Set<String>()

        let featured = allDestinations.filter { $0.isFeatured }
        for d in featured {
            if !seen.contains(d.name) {
                seen.insert(d.name)
                heroes.append(d)
            }
        }

        let topRated = allDestinations.sorted { $0.rating > $1.rating }
        for d in topRated {
            if !seen.contains(d.name) && heroes.count < 5 {
                seen.insert(d.name)
                heroes.append(d)
            }
        }

        if heroes.isEmpty, let featured = featuredDestination {
            return [featured]
        }
        return heroes
    }

    var allDestinations: [DestinationInfo] {
        var seen = Set<String>()
        return destinations.filter { seen.insert($0.name).inserted }
    }

    func destinationsForCategory(_ cat: String) -> [DestinationInfo] {
        allDestinations.filter { $0.category == cat }
    }

    var currentSeason: String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 12, 1, 2: return "winter"
        case 3, 4, 5: return "spring"
        case 6, 7, 8: return "summer"
        default: return "fall"
        }
    }

    var seasonEmoji: String {
        switch currentSeason {
        case "winter": return "\u{2744}\u{FE0F}"
        case "spring": return "\u{1F338}"
        case "summer": return "\u{2600}\u{FE0F}"
        default: return "\u{1F342}"
        }
    }

    var seasonDisplayName: String {
        switch currentSeason {
        case "winter": return "explore.seasonWinter".localized
        case "spring": return "explore.seasonSpring".localized
        case "summer": return "explore.seasonSummer".localized
        default: return "explore.seasonFall".localized
        }
    }

    func daysUntilEvent(_ event: EventDB) -> Int? {
        guard let dateStr = event.eventDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day
        return days != nil && days! >= 0 ? days : nil
    }

    // Events for a given country (case-insensitive match)
    func eventsForCountry(_ country: String) -> [EventDB] {
        events.filter { ($0.country ?? "").lowercased() == country.lowercased() }
    }

    // Destination matching an event's country
    func destinationForEvent(_ event: EventDB) -> DestinationInfo? {
        guard let eventCountry = event.country?.lowercased() else { return nil }
        return allDestinations.first { $0.country.lowercased() == eventCountry }
    }

    // Region groupings: returns [(regionName, destinations, events)]
    var regionGroups: [(region: String, destinations: [DestinationInfo], events: [EventDB])] {
        let regionMap: [String: [String]] = [
            "explore.region.europe": ["France", "Germany", "Spain", "Netherlands", "Belgium", "Sweden", "Finland", "Denmark", "Norway", "Italy", "Austria", "Hungary", "Czech Republic", "Poland", "Portugal", "United Kingdom", "Great Britain", "Ireland", "Switzerland", "Greece", "Croatia", "Romania", "Turkey"],
            "explore.region.americas": ["United States", "USA", "Canada", "Brazil", "Mexico", "Argentina", "Colombia", "Chile", "Peru"],
            "explore.region.asiaPacific": ["Japan", "South Korea", "Australia", "New Zealand", "Singapore", "Thailand", "India", "Indonesia", "China", "Vietnam", "Philippines", "Malaysia"],
            "explore.region.middleEast": ["United Arab Emirates", "Saudi Arabia", "Qatar", "Israel", "Egypt", "Morocco", "South Africa", "Nigeria", "Kenya"]
        ]

        var results: [(region: String, destinations: [DestinationInfo], events: [EventDB])] = []
        for (regionKey, countries) in regionMap {
            let countriesLower = Set(countries.map { $0.lowercased() })
            let regionDests = allDestinations.filter { countriesLower.contains($0.country.lowercased()) }
            let regionEvents = events.filter { countriesLower.contains(($0.country ?? "").lowercased()) }
            if !regionDests.isEmpty || !regionEvents.isEmpty {
                results.append((region: regionKey, destinations: regionDests, events: regionEvents))
            }
        }
        return results.sorted { ($0.events.count + $0.destinations.count) > ($1.events.count + $1.destinations.count) }
    }

    private var fallbackQuotes: [(quote: String, author: String)] {
        [
            ("quote.1".localized, "Mark Twain"),
            ("quote.2".localized, "Saint Augustine"),
            ("quote.3".localized, "Ralph Waldo Emerson"),
            ("quote.4".localized, "Hans Christian Andersen"),
            ("quote.5".localized, "Ibn Battuta"),
            ("quote.6".localized, "Marcel Proust"),
            ("quote.7".localized, "Lao Tzu"),
            ("quote.8".localized, "J.R.R. Tolkien"),
            ("quote.9".localized, "Susan Sontag"),
            ("quote.10".localized, "Anthony Bourdain")
        ]
    }

    private var quoteIndex = 0

    func nextQuote() {
        let quotes = fallbackQuotes
        guard quotes.count > 1 else { return }
        var newIndex: Int
        repeat {
            newIndex = Int.random(in: 0..<quotes.count)
        } while newIndex == quoteIndex
        quoteIndex = newIndex
        currentQuote = quotes[newIndex].quote
        currentAuthor = quotes[newIndex].author
    }

    /// Aynı sanatçı/etkinliğin birden fazla tarihini tek karta grupla
    /// "Coldplay", "Coldplay: World Tour", "Coldplay - Istanbul" hepsini yakalar
    static func groupTourEvents(_ events: [EventDB]) -> [EventDB] {
        // Her etkinlik için "base name" çıkar (sanatçı adı)
        // "Coldplay: Music of the Spheres" → "coldplay"
        // "Ed Sheeran - Istanbul" → "ed sheeran"
        // "Tomorrowland 2026" → "tomorrowland 2026"
        func baseName(_ name: String) -> String {
            let lowered = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // ":" veya " - " öncesini al (tur alt başlığını kes)
            let separators = [":", " - ", " – ", " — ", " | ", " ("]
            for sep in separators {
                if let range = lowered.range(of: sep) {
                    let candidate = String(lowered[lowered.startIndex..<range.lowerBound])
                        .trimmingCharacters(in: .whitespaces)
                    // Çok kısa kalıyorsa (2 harften az) muhtemelen yanlış kesim
                    if candidate.count >= 3 { return candidate }
                }
            }
            return lowered
        }

        // 1) Base name'e göre grupla
        var grouped: [String: [EventDB]] = [:]
        for event in events {
            let key = baseName(event.name)
            grouped[key, default: []].append(event)
        }

        var result: [EventDB] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for (_, group) in grouped {
            if group.count == 1 {
                // Tek etkinlik — olduğu gibi bırak
                result.append(group[0])
            } else {
                // Birden fazla etkinlik — tarih aralığı ile birleştir
                let sorted = group.compactMap { event -> (EventDB, Date)? in
                    guard let dateStr = event.eventDate,
                          let date = formatter.date(from: dateStr) else { return nil }
                    return (event, date)
                }.sorted { $0.1 < $1.1 }

                guard let first = sorted.first, let last = sorted.last else {
                    result.append(contentsOf: group)
                    continue
                }

                let startDate = formatter.string(from: first.1)
                let endDate = formatter.string(from: last.1)

                // En erken tarihteki etkinliği temel al (görsel, isim vb.)
                let base = first.0

                // Şehir bilgisi: tek şehir mi, çoklu mu?
                let uniqueCities = Set(group.compactMap { $0.city })
                let cityText: String? = {
                    if uniqueCities.count <= 1 { return uniqueCities.first }
                    return "\(uniqueCities.count) " + "explore.cities".localized
                }()

                // Ülke bilgisi: farklı ülkelerde de olabilir
                let uniqueCountries = Set(group.compactMap { $0.country })
                let countryText = uniqueCountries.count <= 1 ? base.country : nil

                let merged = EventDB(
                    id: base.id,
                    name: base.name,
                    nameTr: base.nameTr,
                    description: base.description,
                    descriptionTr: base.descriptionTr,
                    city: cityText,
                    country: countryText,
                    countryTr: uniqueCountries.count <= 1 ? base.countryTr : nil,
                    venue: nil,
                    eventDate: startDate,
                    endDate: startDate == endDate ? nil : endDate,
                    category: base.category,
                    imageUrl: base.imageUrl,
                    ticketUrl: base.ticketUrl,
                    ticketmasterId: base.ticketmasterId,
                    isActive: base.isActive,
                    createdAt: base.createdAt
                )
                result.append(merged)
            }
        }

        return result
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        await fetchAndApplyData(shuffle: true)
    }

    /// Pull-to-refresh: veriyi yeniler ama sırayı bozmaz, skeleton göstermez
    func refreshData() async {
        await fetchAndApplyData(shuffle: false)
    }

    private func fetchAndApplyData(shuffle: Bool) async {
        do {
            async let allTask = SupabaseService.shared.fetchAllDestinations()
            async let featuredTask = SupabaseService.shared.fetchFeaturedDestination()
            async let quotesTask = SupabaseService.shared.fetchTravelQuotes()
            async let eventsTask = SupabaseService.shared.fetchEvents()

            let (grouped, featuredDB, quotesDB, eventsDB) = try await (allTask, featuredTask, quotesTask, eventsTask)

            // Etkinlikleri filtrele, turları grupla
            let filtered = eventsDB.filter { $0.isUpcoming && $0.isAllowedCategory }
            let grouped_events = Self.groupTourEvents(filtered)
            events = shuffle ? grouped_events.shuffled() : grouped_events

            var allInfos: [DestinationInfo] = []
            for (_, dests) in grouped {
                allInfos.append(contentsOf: dests.map { $0.toDestinationInfo() })
            }

            destinations = allInfos

            if let featured = featuredDB {
                featuredDestination = featured.toDestinationInfo()
            } else {
                featuredDestination = allInfos.first(where: { $0.isFeatured }) ?? allInfos.first
            }

            if let randomQuote = quotesDB.randomElement() {
                currentQuote = randomQuote.quote
                currentAuthor = randomQuote.author ?? "quote.author.unknown".localized
            } else {
                let randomIndex = Int.random(in: 0..<fallbackQuotes.count)
                currentQuote = fallbackQuotes[randomIndex].quote
                currentAuthor = fallbackQuotes[randomIndex].author
            }

            let cats = Set(allInfos.map { $0.category })
        } catch {
            if !shuffle {
                // Refresh sırasında hata olursa mevcut veriyi koru
                return
            }
            // İlk yüklemede hata → boş state
            destinations = []
            featuredDestination = nil
        }
    }
}

// MARK: - DestinationDB Extension
extension DestinationDB {
    func toDestinationInfo() -> DestinationInfo {
        DestinationInfo(
            name: name, country: country,
            emoji: "\u{1F30D}",
            description: description ?? "",
            rating: rating, trendPercentage: trendPercentage,
            seasonalTag: seasonalTag ?? "",
            primaryColor: Color(hex: primaryColor),
            secondaryColor: Color(hex: secondaryColor),
            imageURL: imageUrl,
            category: category,
            isFeatured: isFeatured ?? false,
            nameTr: nameTr,
            descriptionTr: descriptionTr,
            countryTr: countryTr,
            seasonalTagTr: seasonalTagTr
        )
    }
}

// MARK: - All Events View
struct AllEventsView: View {
    let events: [EventDB]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color(hex: "E91E63").opacity(0.15)).frame(width: 60, height: 60)
                        Image(systemName: "calendar.badge.clock").font(.system(size: 26)).foregroundStyle(Color(hex: "E91E63"))
                    }
                    Text("explore.upcomingEvents".localized)
                        .font(.custom("SpaceMono-Bold", size: 22))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(events.count) " + "explore.events".localized)
                        .font(.custom("SpaceMono-Regular", size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.vertical, 20)

                LazyVStack(spacing: 12) {
                    ForEach(events, id: \.id) { event in
                        eventListRow(event)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 40)
        }
        .background(AppColors.background)
        .navigationTitle("explore.upcomingEvents".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func eventListRow(_ event: EventDB) -> some View {
        HStack(spacing: 12) {
            ZStack {
                let thumbUrl = ImageURLBuilder.optimizedURL(event.imageUrl ?? "", tier: .thumbnail)
                if !thumbUrl.isEmpty, let imageURL = URL(string: thumbUrl) {
                    LazyImage(url: imageURL) { state in
                        if let image = state.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if state.error != nil {
                            event.categoryColor.opacity(0.6)
                                .overlay(
                                    Image(systemName: event.categoryIcon)
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white.opacity(0.6))
                                )
                        } else {
                            event.categoryColor.opacity(0.6)
                                .shimmer()
                        }
                    }
                    .processors([.resize(size: CGSize(width: 70 * UIScreen.main.scale, height: 70 * UIScreen.main.scale))])
                } else {
                    event.categoryColor.opacity(0.6)
                        .overlay(
                            Image(systemName: event.categoryIcon)
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.6))
                        )
                }
            }
            .frame(width: 70, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(event.localizedName)
                    .font(.custom("SpaceMono-Bold", size: 15))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                if let city = event.city, !city.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(AppColors.primary)
                        Text("\(city), \(event.localizedCountry)")
                            .font(.custom("SpaceMono-Regular", size: 11))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: event.categoryIcon)
                            .font(.system(size: 8))
                        Text(event.category ?? "")
                            .font(.custom("SpaceMono-Bold", size: 9))
                    }
                    .foregroundStyle(event.categoryColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(event.categoryColor.opacity(0.12)))

                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                            .font(.system(size: 8))
                        Text(event.formattedDateRange)
                            .font(.custom("SpaceMono-Bold", size: 10))
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer(minLength: 0)

            if event.ticketUrl != nil {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.primary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
        )
        .onTapGesture {
            if let url = event.ticketUrl, let ticketURL = URL(string: url) {
                UIApplication.shared.open(ticketURL)
            }
        }
    }
}

// MARK: - Supporting Views
struct AllDestinationsView: View {
    var body: some View {
        Text("explore.allDestinations".localized)
            .navigationTitle("explore.destinations".localized)
    }
}

struct ProfileView: View {
    @AppStorage("userName") private var userName: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: ThemeManager.Spacing.xl) {
                AvatarView(
                    name: userName.isEmpty ? "greeting.traveler".localized : userName,
                    imageData: UserDefaults.standard.data(forKey: "userAvatarData"),
                    size: .xlarge
                )
                .padding(.top, ThemeManager.Spacing.xl)

                Text(userName.isEmpty ? "greeting.traveler".localized : userName)
                    .font(ThemeManager.Typography.title1)
                    .foregroundStyle(AppColors.textPrimary)

                EmptyStateView(
                    icon: "person.crop.circle.badge.checkmark",
                    title: "profile.settings".localized,
                    message: "profile.settingsComingSoon".localized
                )
            }
            .padding()
        }
        .background(AppColors.background)
        .navigationTitle("profile.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DestinationDetailView: View {
    let destination: DestinationInfo
    @StateObject private var viewModel = DestinationDetailViewModel()

    init(name: String) {
        self.destination = DestinationInfo(
            name: name, country: "", emoji: "\u{1F30D}", description: "",
            rating: 0, trendPercentage: 0, seasonalTag: "",
            primaryColor: AppColors.primary, secondaryColor: AppColors.secondary,
            imageURL: "", category: "", isFeatured: false,
            nameTr: nil, descriptionTr: nil, countryTr: nil, seasonalTagTr: nil
        )
    }

    init(destination: DestinationInfo) {
        self.destination = destination
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ThemeManager.Spacing.lg) {
                ZStack(alignment: .bottomLeading) {
                    DestinationImageView(url: destination.imageURL, gradient: destination.gradient, tier: .hero)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()

                    LinearGradient(colors: [.black.opacity(0.7), .black.opacity(0.3), .clear], startPoint: .bottom, endPoint: .top)
                        .frame(height: 220)

                    VStack(alignment: .leading, spacing: ThemeManager.Spacing.xs) {
                        HStack(spacing: 4) {
                            Image(systemName: destination.categoryInfo.icon)
                                .font(.system(size: 10))
                            Text(destination.categoryInfo.displayName)
                                .font(.custom("SpaceMono-Bold", size: 10))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(destination.categoryInfo.color.opacity(0.8)))

                        Text(destination.localizedName)
                            .font(.custom("SpaceMono-Bold", size: 32))
                            .foregroundStyle(.white)

                        HStack(spacing: 10) {
                            Text(destination.localizedCountry)
                                .font(ThemeManager.Typography.subheadline)
                                .foregroundStyle(.white.opacity(0.8))

                            if destination.rating > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(AppColors.primary)
                                    Text(String(format: "%.1f", destination.rating))
                                        .font(.custom("SpaceMono-Bold", size: 12))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    .padding(ThemeManager.Spacing.lg)
                }

                VStack(spacing: ThemeManager.Spacing.md) {
                    if !destination.localizedDescription.isEmpty {
                        Text(destination.localizedDescription)
                            .font(ThemeManager.Typography.body)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, ThemeManager.Spacing.md)
                    }

                    if viewModel.isLoading {
                        LoadingStateView(message: "destination.loadingInfo".localized)
                    } else if let info = viewModel.cityInfo {
                        Text(info)
                            .font(ThemeManager.Typography.body)
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, ThemeManager.Spacing.md)
                    }

                    // Events in this country
                    if !viewModel.countryEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "ticket.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppColors.primary)
                                Text(String(format: "explore.eventsInRegion".localized, destination.localizedCountry))
                                    .font(.custom("SpaceMono-Bold", size: 17))
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                            .padding(.horizontal, ThemeManager.Spacing.md)

                            ForEach(viewModel.countryEvents, id: \.id) { event in
                                destinationEventRow(event)
                                    .padding(.horizontal, ThemeManager.Spacing.md)
                            }
                        }
                    }

                    NavigationLink(destination: CreateTripView()) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("destination.planTrip".localized)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .primaryButton()
                    .padding(.horizontal, ThemeManager.Spacing.md)
                }
            }
        }
        .background(AppColors.background)
        .navigationTitle(destination.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadCityInfo(city: destination.name)
            await viewModel.loadCountryEvents(country: destination.country)
        }
    }

    private func destinationEventRow(_ event: EventDB) -> some View {
        HStack(spacing: 12) {
            // Category color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(event.categoryColor)
                .frame(width: 4, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.localizedName)
                    .font(.custom("SpaceMono-Bold", size: 14))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: event.categoryIcon)
                            .font(.system(size: 9))
                        Text(event.category ?? "")
                            .font(.custom("SpaceMono-Bold", size: 10))
                    }
                    .foregroundStyle(event.categoryColor)

                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text(event.formattedDateRange)
                            .font(.custom("SpaceMono-Regular", size: 10))
                    }
                    .foregroundStyle(AppColors.textSecondary)

                    if event.city != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .font(.system(size: 9))
                            Text(event.city!)
                                .font(.custom("SpaceMono-Regular", size: 10))
                        }
                        .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }

            Spacer()

            if event.ticketUrl != nil {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.primary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))
        )
        .onTapGesture {
            if let url = event.ticketUrl, let ticketURL = URL(string: url) {
                UIApplication.shared.open(ticketURL)
            }
        }
    }
}

@MainActor
class DestinationDetailViewModel: ObservableObject {
    @Published var cityInfo: String?
    @Published var isLoading = false
    @Published var countryEvents: [EventDB] = []

    func loadCityInfo(city: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            cityInfo = try await GroqService.shared.getCityInfo(city: city)
        } catch {
            cityInfo = String(format: "destination.infoError".localized, city)
        }
    }

    func loadCountryEvents(country: String) async {
        do {
            let allEvents = try await SupabaseService.shared.fetchEvents()
            countryEvents = allEvents.filter {
                $0.isUpcoming && $0.isAllowedCategory &&
                ($0.country ?? "").lowercased() == country.lowercased()
            }
        } catch {
        }
    }
}

#Preview {
    ExploreView()
        .preferredColorScheme(.dark)
}
