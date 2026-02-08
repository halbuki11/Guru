import SwiftUI
import MapKit

// MARK: - Enums

enum MapStyleOption: CaseIterable {
    case standard, satellite, hybrid

    var displayName: String {
        switch self {
        case .standard: return "map.standard".localized
        case .satellite: return "map.satellite".localized
        case .hybrid: return "map.hybrid".localized
        }
    }

    var icon: String {
        switch self {
        case .standard: return "map"
        case .satellite: return "globe.americas"
        case .hybrid: return "square.on.square"
        }
    }
}

enum MapViewMode: CaseIterable {
    case countries, cities

    var displayName: String {
        switch self {
        case .countries: return "map.countries".localized
        case .cities: return "map.cities".localized
        }
    }

    var icon: String {
        switch self {
        case .countries: return "flag.fill"
        case .cities: return "building.2.fill"
        }
    }
}

// MARK: - Continent

enum Continent: String, CaseIterable {
    case europe, asia, americas, africa, oceania

    var displayName: String {
        "map.continent.\(rawValue)".localized
    }

    var icon: String {
        switch self {
        case .europe: return "🌍"
        case .asia: return "🌏"
        case .americas: return "🌎"
        case .africa: return "🌍"
        case .oceania: return "🌏"
        }
    }
}

// MARK: - WorldMapView (Flight Radar / ATC Dashboard)

struct WorldMapView: View {
    @StateObject private var viewModel = WorldMapViewModel()
    @State private var selectedCountry: CountryData?
    @State private var showCountrySheet = false
    @State private var showAddCountrySheet = false
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 30, longitude: 20),
            span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 180)
        )
    )
    @State private var mapStyleOption: MapStyleOption = .standard
    @State private var mapViewMode: MapViewMode = .countries
    @State private var selectedCity: CityData?
    @State private var showCitySheet = false
    @State private var showAddCitySheet = false
    @State private var tappedCoordinate: CLLocationCoordinate2D?
    @State private var appeared = false
    @State private var showSearchOverlay = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                // Scan-line texture
                radarScanLines

                VStack(spacing: 0) {
                    // Mode toggle
                    radarModeToggle
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -10)

                    // Continent filter bar
                    continentFilterBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .opacity(appeared ? 1 : 0)

                    // Map + overlays (her zaman göster)
                    ZStack {
                        radarMapView

                        // Overlays
                        VStack {
                            if hasAnyPins {
                                // Search overlay
                                if showSearchOverlay {
                                    mapSearchOverlay
                                        .padding(.horizontal, 16)
                                        .padding(.top, 12)
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                } else {
                                    radarStatsHUD
                                        .padding(.horizontal, 16)
                                        .padding(.top, 12)
                                        .opacity(appeared ? 1 : 0)
                                        .offset(y: appeared ? 0 : -15)
                                }
                            }

                            Spacer()

                            if hasAnyPins {
                                radarLegendBar
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 16)
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 15)
                            }
                        }

                        // Empty overlay (harita üstünde göster)
                        if !hasAnyPins {
                            emptyMapState
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "airplane.arrival")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.primary)
                        Text("map.worldMap".localized)
                            .font(ThemeManager.Typography.boardToolbar)
                            .foregroundStyle(AppColors.textPrimary)
                            .tracking(2)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if mapViewMode == .countries {
                            showAddCountrySheet = true
                        } else {
                            showAddCitySheet = true
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(AppColors.primary.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "plus")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.primary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        // Search toggle
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showSearchOverlay.toggle()
                                if !showSearchOverlay { viewModel.mapSearchText = "" }
                            }
                        } label: {
                            Image(systemName: showSearchOverlay ? "xmark" : "magnifyingglass")
                                .font(.system(size: 14))
                                .foregroundStyle(showSearchOverlay ? AppColors.error : AppColors.primary)
                        }

                        // Filter
                        Menu {
                            Button { viewModel.filterMode = .all } label: {
                                Label("map.filterAll".localized, systemImage: "globe")
                            }
                            Button { viewModel.filterMode = .visited } label: {
                                Label("map.filterVisited".localized, systemImage: "checkmark.circle")
                            }
                            Button { viewModel.filterMode = .wishlist } label: {
                                Label("map.filterWishlist".localized, systemImage: "heart")
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.primary)
                        }

                        // Map style
                        Menu {
                            ForEach(MapStyleOption.allCases, id: \.self) { style in
                                Button {
                                    mapStyleOption = style
                                } label: {
                                    Label(style.displayName, systemImage: mapStyleOption == style ? "checkmark" : style.icon)
                                }
                            }
                        } label: {
                            Image(systemName: mapStyleOption.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.primary)
                        }
                    }
                }
            }
            // Sheets
            .sheet(isPresented: $showCountrySheet) {
                if let country = selectedCountry {
                    CountryDetailSheet(
                        country: country,
                        visitStatus: viewModel.getVisitStatus(for: country.code),
                        visitDate: viewModel.getCountryVisitDate(for: country.code),
                        notes: viewModel.getCountryNotes(for: country.code),
                        onStatusChange: { status in
                            Task {
                                await viewModel.updateVisitStatus(countryCode: country.code, status: status)
                                updateUserStats()
                            }
                        },
                        onDetailsUpdate: { notes, date in
                            Task {
                                await viewModel.updateCountryDetails(countryCode: country.code, notes: notes, visitDate: date)
                            }
                        }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showAddCountrySheet) {
                AddCountrySheet(
                    visitedCountryCodes: Set(viewModel.visitedCountries.map { $0.code }),
                    wishlistCountryCodes: Set(viewModel.wishlistCountries.map { $0.code }),
                    onCountrySelected: { country, status in
                        Task {
                            await viewModel.updateVisitStatus(countryCode: country.code, status: status)
                            updateUserStats()
                        }
                        showAddCountrySheet = false
                    }
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showCitySheet) {
                if let city = selectedCity {
                    CityDetailSheet(
                        city: city,
                        visitStatus: viewModel.getCityVisitStatus(for: city.id),
                        visitDate: viewModel.getCityVisitDate(for: city.id),
                        notes: viewModel.getCityNotes(for: city.id),
                        onStatusChange: { status in
                            Task {
                                await viewModel.updateCityVisitStatus(cityId: city.id, status: status)
                                updateUserStats()
                            }
                        },
                        onDetailsUpdate: { notes, date in
                            Task {
                                await viewModel.updateCityDetails(cityId: city.id, notes: notes, visitDate: date)
                            }
                        }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showAddCitySheet) {
                AddCitySheet(
                    visitedCityIds: Set(viewModel.visitedCities.map { $0.id }),
                    wishlistCityIds: Set(viewModel.wishlistCities.map { $0.id }),
                    tappedCoordinate: tappedCoordinate,
                    onCitySelected: { city, status in
                        Task {
                            await viewModel.updateCityVisitStatus(cityId: city.id, status: status)
                            updateUserStats()
                        }
                        showAddCitySheet = false
                        tappedCoordinate = nil
                    },
                    onCustomCityAdded: { city, status in
                        Task {
                            await viewModel.addCustomCity(city, status: status)
                            updateUserStats()
                        }
                        showAddCitySheet = false
                        tappedCoordinate = nil
                    }
                )
                .presentationDetents([.large])
            }
        }
        .task {
            await viewModel.loadData()
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) {
                appeared = true
            }
        }
    }

    private func updateUserStats() {
        UserDefaults.standard.set(viewModel.visitedCountries.count, forKey: "countriesVisited")
        let tripsCount = UserDefaults.standard.integer(forKey: "tripsCount")
        UserDefaults.standard.set(tripsCount, forKey: "tripsCount")
    }

    // MARK: - Scan Lines

    private var radarScanLines: some View {
        Canvas { context, size in
            for y in stride(from: 0, through: size.height, by: 3) {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(.white.opacity(0.008)))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Mode Toggle

    private var radarModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(MapViewMode.allCases, id: \.self) { mode in
                let isActive = mapViewMode == mode
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        mapViewMode = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isActive ? AppColors.primary : AppColors.textTertiary.opacity(0.4))
                            .frame(width: 6, height: 6)
                        Text(mode.displayName)
                            .font(ThemeManager.Typography.boardLabel)
                            .tracking(1)
                    }
                    .foregroundStyle(isActive ? AppColors.textPrimary : AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isActive ? AppColors.surfaceLight : .clear)
                    )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.cardBorder, lineWidth: 0.5)
                )
        )
    }

    // MARK: - Map View

    private var radarMapView: some View {
        MapReader { proxy in
            Map(position: $mapCameraPosition) {
                if mapViewMode == .countries {
                    ForEach(filteredCountries, id: \.code) { country in
                        if let coordinate = country.coordinate {
                            Annotation(country.localizedName, coordinate: coordinate) {
                                RadarCountryPin(
                                    status: viewModel.getVisitStatus(for: country.code) ?? .visited,
                                    onTap: {
                                        selectedCountry = country
                                        showCountrySheet = true
                                    }
                                )
                            }
                        }
                    }
                } else {
                    ForEach(filteredCities, id: \.id) { city in
                        Annotation(city.name, coordinate: city.coordinate) {
                            RadarCityPin(
                                status: viewModel.getCityVisitStatus(for: city.id) ?? .visited,
                                onTap: {
                                    selectedCity = city
                                    showCitySheet = true
                                }
                            )
                        }
                    }
                }
            }
            .mapStyle(currentMapStyle)
            .onTapGesture { position in
                if mapViewMode == .cities {
                    if let coordinate = proxy.convert(position, from: .local) {
                        tappedCoordinate = coordinate
                        showAddCitySheet = true
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var hasAnyPins: Bool {
        !viewModel.visitedCountries.isEmpty || !viewModel.wishlistCountries.isEmpty ||
        !viewModel.visitedCities.isEmpty || !viewModel.wishlistCities.isEmpty
    }

    private var filteredCountries: [CountryData] {
        var result: [CountryData]
        switch viewModel.filterMode {
        case .all: result = viewModel.visitedCountries + viewModel.wishlistCountries
        case .visited: result = viewModel.visitedCountries
        case .wishlist: result = viewModel.wishlistCountries
        }
        if let continent = viewModel.selectedContinent {
            result = result.filter { CountryUtils.getContinent(code: $0.code) == continent }
        }
        return result
    }

    private var filteredCities: [CityData] {
        var result: [CityData]
        switch viewModel.filterMode {
        case .all: result = viewModel.visitedCities + viewModel.wishlistCities
        case .visited: result = viewModel.visitedCities
        case .wishlist: result = viewModel.wishlistCities
        }
        if let continent = viewModel.selectedContinent {
            result = result.filter { CountryUtils.getContinent(code: $0.countryCode) == continent }
        }
        return result
    }

    private var currentMapStyle: MapStyle {
        switch mapStyleOption {
        case .standard: return .standard(elevation: .realistic)
        case .satellite: return .imagery(elevation: .realistic)
        case .hybrid: return .hybrid(elevation: .realistic)
        }
    }

    // MARK: - Stats HUD

    private var radarStatsHUD: some View {
        HStack(spacing: 0) {
            if mapViewMode == .countries {
                radarStatItem(icon: "checkmark.circle.fill", value: viewModel.visitedCountries.count, label: "map.visited".localized, color: AppColors.success)
                radarStatSeparator
                radarStatItem(icon: "heart.fill", value: viewModel.wishlistCountries.count, label: "map.wish".localized, color: AppColors.primary)
                radarStatSeparator
                radarStatItem(icon: "percent", value: viewModel.worldPercentage, label: "map.world".localized, color: AppColors.info)
            } else {
                radarStatItem(icon: "checkmark.circle.fill", value: viewModel.visitedCities.count, label: "map.city".localized, color: AppColors.success)
                radarStatSeparator
                radarStatItem(icon: "heart.fill", value: viewModel.wishlistCities.count, label: "map.wish".localized, color: AppColors.primary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.cardBorder.opacity(0.5), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }

    private func radarStatItem(icon: String, value: Int, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(ThemeManager.Typography.boardValue)
                    .foregroundStyle(AppColors.textPrimary)
                Text(label)
                    .font(ThemeManager.Typography.boardMicro)
                    .foregroundStyle(AppColors.textTertiary)
                    .tracking(0.5)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var radarStatSeparator: some View {
        Divider()
            .frame(height: 24)
            .background(AppColors.cardBorder)
    }

    // MARK: - Legend Bar

    private var radarLegendBar: some View {
        HStack(spacing: 0) {
            radarLegendItem(color: AppColors.success, icon: "checkmark", label: "map.visitedLabel".localized)
            Divider()
                .frame(height: 16)
                .background(AppColors.cardBorder)
            radarLegendItem(color: AppColors.primary, icon: "heart.fill", label: "map.wantToVisit".localized)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.surface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.cardBorder.opacity(0.5), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    private func radarLegendItem(color: Color, icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                Image(systemName: icon)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(ThemeManager.Typography.boardMicro)
                .foregroundStyle(AppColors.textSecondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Continent Filter Bar

    private var continentFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Continent.allCases, id: \.self) { continent in
                    let isActive = viewModel.selectedContinent == continent
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.selectedContinent = isActive ? nil : continent
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(continent.icon)
                                .font(.system(size: 10))
                            Text(continent.displayName)
                                .font(ThemeManager.Typography.boardMicro)
                                .tracking(0.5)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(isActive ? AppColors.primary : AppColors.textSecondary)
                        .background(
                            Capsule()
                                .fill(isActive ? AppColors.primary.opacity(0.15) : AppColors.surface)
                                .overlay(
                                    Capsule()
                                        .stroke(isActive ? AppColors.primary.opacity(0.4) : AppColors.cardBorder, lineWidth: 0.5)
                                )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Map Search Overlay

    private var mapSearchOverlay: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(isSearchFocused ? AppColors.primary : AppColors.textTertiary)

                TextField("map.search.placeholder".localized, text: $viewModel.mapSearchText)
                    .font(ThemeManager.Typography.boardCaption)
                    .foregroundStyle(AppColors.textPrimary)
                    .focused($isSearchFocused)

                if !viewModel.mapSearchText.isEmpty {
                    Button {
                        viewModel.mapSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSearchFocused ? AppColors.primary : AppColors.cardBorder, lineWidth: isSearchFocused ? 1 : 0.5)
                    )
            )

            // Search results
            if viewModel.mapSearchText.count >= 2 {
                let results = searchResults
                if results.isEmpty {
                    Text("map.search.noResults".localized)
                        .font(ThemeManager.Typography.boardMicro)
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 2) {
                        ForEach(results.prefix(5), id: \.id) { result in
                            Button {
                                zoomToResult(result)
                                withAnimation { showSearchOverlay = false }
                                viewModel.mapSearchText = ""
                            } label: {
                                HStack(spacing: 10) {
                                    Text(result.flag)
                                        .font(.system(size: 16))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(result.name)
                                            .font(ThemeManager.Typography.boardCaption)
                                            .foregroundStyle(AppColors.textPrimary)
                                        Text(result.subtitle)
                                            .font(ThemeManager.Typography.boardMicro)
                                            .foregroundStyle(AppColors.textTertiary)
                                    }
                                    Spacer()
                                    Image(systemName: "location.circle")
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppColors.primary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppColors.cardBorder.opacity(0.5), lineWidth: 0.5)
                            )
                    )
                }
            }
        }
    }

    private struct SearchResult: Identifiable {
        let id: String
        let name: String
        let subtitle: String
        let flag: String
        let coordinate: CLLocationCoordinate2D
        let zoom: Double
    }

    private var searchResults: [SearchResult] {
        let query = viewModel.mapSearchText.lowercased()
        var results: [SearchResult] = []

        // Search countries
        for country in CountryUtils.allCountries where
            country.name.localizedCaseInsensitiveContains(query) ||
            country.localizedName.localizedCaseInsensitiveContains(query) ||
            country.code.localizedCaseInsensitiveContains(query) {
            if let coord = country.coordinate {
                results.append(SearchResult(id: "c_\(country.code)", name: country.localizedName, subtitle: country.code, flag: country.flag, coordinate: coord, zoom: country.radiusKm * 3000))
            }
        }

        // Search cities
        for city in CityUtils.popularCities where
            city.name.localizedCaseInsensitiveContains(query) ||
            city.countryName.localizedCaseInsensitiveContains(query) {
            results.append(SearchResult(id: "ci_\(city.id)", name: city.name, subtitle: city.localizedCountryName, flag: city.countryFlag, coordinate: city.coordinate, zoom: 50000))
        }

        return results
    }

    private func zoomToResult(_ result: SearchResult) {
        withAnimation(.easeInOut(duration: 0.8)) {
            mapCameraPosition = .region(MKCoordinateRegion(
                center: result.coordinate,
                latitudinalMeters: result.zoom,
                longitudinalMeters: result.zoom
            ))
        }
    }

    // MARK: - Empty Map State

    private var emptyMapState: some View {
        VStack(spacing: 28) {
            Spacer()

            // Animated compass
            ZStack {
                Circle()
                    .stroke(AppColors.primary.opacity(0.1), lineWidth: 1)
                    .frame(width: 100, height: 100)

                Circle()
                    .stroke(AppColors.primary.opacity(0.05), lineWidth: 1)
                    .frame(width: 130, height: 130)

                Image(systemName: "safari")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.primary.opacity(0.6))
                    .rotationEffect(.degrees(appeared ? 360 : 0))
                    .animation(.linear(duration: 12).repeatForever(autoreverses: false), value: appeared)
            }
            .frame(height: 140)

            VStack(spacing: 10) {
                Text("map.empty.title".localized)
                    .font(ThemeManager.Typography.boardCity)
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(1)

                Text("map.empty.subtitle".localized)
                    .font(ThemeManager.Typography.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                showAddCountrySheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("map.empty.cta".localized)
                        .font(ThemeManager.Typography.boardLabel)
                        .tracking(0.5)
                }
                .foregroundStyle(AppColors.background)
                .frame(width: 220, height: 48)
                .background(
                    Capsule()
                        .fill(AppColors.primaryGradient)
                )
                .shadow(color: AppColors.primary.opacity(0.3), radius: 16, y: 8)
            }

            Spacer()
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }
}

// MARK: - Radar Country Pin

struct RadarCountryPin: View {
    let status: VisitStatus
    let onTap: () -> Void

    @State private var pulsing = false

    private var pinColor: Color {
        status == .visited ? AppColors.success : AppColors.primary
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(pinColor.opacity(0.3), lineWidth: 1)
                    .frame(width: 40, height: 40)
                    .opacity(pulsing ? 0 : 1)
                    .scaleEffect(pulsing ? 2 : 1)

                // Middle ring
                Circle()
                    .stroke(pinColor.opacity(0.4), lineWidth: 1)
                    .frame(width: 28, height: 28)

                // Center blip
                ZStack {
                    Circle()
                        .fill(pinColor)
                        .frame(width: 16, height: 16)
                    Image(systemName: status == .visited ? "checkmark" : "heart.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
                .shadow(color: pinColor.opacity(0.5), radius: 4, y: 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}

// MARK: - Radar City Pin

struct RadarCityPin: View {
    let status: VisitStatus
    let onTap: () -> Void

    @State private var pulsing = false

    private var pinColor: Color {
        status == .visited ? AppColors.success : AppColors.primary
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(pinColor.opacity(0.3), lineWidth: 1)
                    .frame(width: 28, height: 28)
                    .opacity(pulsing ? 0 : 1)
                    .scaleEffect(pulsing ? 1.8 : 1)

                // Middle ring
                Circle()
                    .stroke(pinColor.opacity(0.4), lineWidth: 0.5)
                    .frame(width: 18, height: 18)

                // Center blip
                ZStack {
                    Circle()
                        .fill(pinColor)
                        .frame(width: 12, height: 12)
                    Image(systemName: status == .visited ? "checkmark" : "heart.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.white)
                }
                .shadow(color: pinColor.opacity(0.4), radius: 3, y: 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}

// MARK: - Country Detail Sheet (Flight Info Display)

struct CountryDetailSheet: View {
    let country: CountryData
    let visitStatus: VisitStatus?
    let visitDate: Date?
    let notes: String?
    let onStatusChange: (VisitStatus?) -> Void
    let onDetailsUpdate: (String?, Date?) -> Void
    @State private var appeared = false
    @State private var showEditSheet = false
    @State private var editNotes: String = ""
    @State private var editDate: Date = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Text(country.flag)
                        .font(.system(size: 48))

                    Text(country.code)
                        .font(ThemeManager.Typography.boardTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .tracking(3)

                    Text(country.localizedName)
                        .font(ThemeManager.Typography.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Visit details
                if visitStatus != nil {
                    visitDetailsSection
                }

                // Divider
                Rectangle()
                    .fill(AppColors.cardBorder)
                    .frame(height: 0.5)
                    .padding(.horizontal, 24)

                // Action buttons
                VStack(spacing: 10) {
                    flightInfoButton(
                        icon: visitStatus == .visited ? "checkmark.circle.fill" : "checkmark.circle",
                        text: "map.iVisited".localized,
                        isActive: visitStatus == .visited,
                        color: AppColors.success
                    ) {
                        onStatusChange(.visited)
                    }

                    flightInfoButton(
                        icon: visitStatus == .wishlist ? "heart.fill" : "heart",
                        text: "map.wantToVisit".localized,
                        isActive: visitStatus == .wishlist,
                        color: AppColors.primary
                    ) {
                        onStatusChange(.wishlist)
                    }

                    if visitStatus != nil {
                        flightInfoButton(
                            icon: "xmark.circle",
                            text: "map.remove".localized,
                            isActive: false,
                            color: AppColors.error
                        ) {
                            onStatusChange(nil)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
            }
            .padding(.top, 28)
        }
        .background(AppColors.background)
        .onAppear {
            editNotes = notes ?? ""
            editDate = visitDate ?? Date()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditVisitSheet(notes: $editNotes, visitDate: $editDate) {
                onDetailsUpdate(editNotes.isEmpty ? nil : editNotes, editDate)
                showEditSheet = false
            }
            .presentationDetents([.medium])
        }
    }

    private var visitDetailsSection: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.primary)
                    if let date = visitDate {
                        Text(date, style: .date)
                            .font(ThemeManager.Typography.boardCaption)
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        Text("map.addDate".localized)
                            .font(ThemeManager.Typography.boardCaption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }

                Spacer()

                Button { showEditSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                        Text("map.editVisit".localized)
                            .font(ThemeManager.Typography.boardMicro)
                    }
                    .foregroundStyle(AppColors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppColors.primary.opacity(0.1))
                    )
                }
            }

            if let notes = notes, !notes.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.primary)
                    Text(notes)
                        .font(ThemeManager.Typography.boardMicro)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(2)
                    Spacer()
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textTertiary.opacity(0.5))
                    Text("map.addNote".localized)
                        .font(ThemeManager.Typography.boardMicro)
                        .foregroundStyle(AppColors.textTertiary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.cardBorder, lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 20)
    }

    private func flightInfoButton(icon: String, text: String, isActive: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(text)
                    .font(ThemeManager.Typography.boardLabel)
                    .tracking(0.5)
                Spacer()
            }
            .foregroundStyle(isActive ? color : AppColors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? color.opacity(0.12) : AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isActive ? color.opacity(0.3) : AppColors.cardBorder, lineWidth: 0.5)
                    )
            )
        }
    }
}

// MARK: - Country Data

struct CountryData: Equatable {
    let code: String
    let name: String
    let flag: String
    let latitude: Double
    let longitude: Double
    let radiusKm: Double

    var coordinate: CLLocationCoordinate2D? {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var approximateRadius: CLLocationDistance {
        radiusKm * 1000
    }

    var localizedName: String {
        let key = "country.code.\(code)"
        let localized = key.localized
        return localized != key ? localized : name
    }
}

// MARK: - City Data

struct CityData: Equatable, Codable, Identifiable {
    let id: String
    let name: String
    let countryCode: String
    let countryName: String
    let latitude: Double
    let longitude: Double
    var isCustom: Bool = false

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var countryFlag: String {
        CountryUtils.getCountryData(code: countryCode)?.flag ?? "🏳️"
    }

    var localizedCountryName: String {
        let key = "country.code.\(countryCode)"
        let localized = key.localized
        return localized != key ? localized : countryName
    }
}

// MARK: - City Detail Sheet (Flight Info Display)

struct CityDetailSheet: View {
    let city: CityData
    let visitStatus: VisitStatus?
    let visitDate: Date?
    let notes: String?
    let onStatusChange: (VisitStatus?) -> Void
    let onDetailsUpdate: (String?, Date?) -> Void
    @State private var appeared = false
    @State private var showEditSheet = false
    @State private var editNotes: String = ""
    @State private var editDate: Date = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Text(city.countryFlag)
                        .font(.system(size: 40))

                    Text(city.name)
                        .font(ThemeManager.Typography.boardCity)
                        .foregroundStyle(AppColors.textPrimary)
                        .tracking(1)

                    Text(city.localizedCountryName)
                        .font(ThemeManager.Typography.boardCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Visit details
                if visitStatus != nil {
                    cityVisitDetailsSection
                }

                Rectangle()
                    .fill(AppColors.cardBorder)
                    .frame(height: 0.5)
                    .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    cityInfoButton(
                        icon: visitStatus == .visited ? "checkmark.circle.fill" : "checkmark.circle",
                        text: "map.iVisited".localized,
                        isActive: visitStatus == .visited,
                        color: AppColors.success
                    ) {
                        onStatusChange(.visited)
                    }

                    cityInfoButton(
                        icon: visitStatus == .wishlist ? "heart.fill" : "heart",
                        text: "map.wantToVisit".localized,
                        isActive: visitStatus == .wishlist,
                        color: AppColors.primary
                    ) {
                        onStatusChange(.wishlist)
                    }

                    if visitStatus != nil {
                        cityInfoButton(
                            icon: "xmark.circle",
                            text: "map.remove".localized,
                            isActive: false,
                            color: AppColors.error
                        ) {
                            onStatusChange(nil)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
            }
            .padding(.top, 28)
        }
        .background(AppColors.background)
        .onAppear {
            editNotes = notes ?? ""
            editDate = visitDate ?? Date()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditVisitSheet(notes: $editNotes, visitDate: $editDate) {
                onDetailsUpdate(editNotes.isEmpty ? nil : editNotes, editDate)
                showEditSheet = false
            }
            .presentationDetents([.medium])
        }
    }

    private var cityVisitDetailsSection: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.primary)
                    if let date = visitDate {
                        Text(date, style: .date)
                            .font(ThemeManager.Typography.boardCaption)
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        Text("map.addDate".localized)
                            .font(ThemeManager.Typography.boardCaption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                Spacer()
                Button { showEditSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                        Text("map.editVisit".localized)
                            .font(ThemeManager.Typography.boardMicro)
                    }
                    .foregroundStyle(AppColors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppColors.primary.opacity(0.1)))
                }
            }

            if let notes = notes, !notes.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.primary)
                    Text(notes)
                        .font(ThemeManager.Typography.boardMicro)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(2)
                    Spacer()
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textTertiary.opacity(0.5))
                    Text("map.addNote".localized)
                        .font(ThemeManager.Typography.boardMicro)
                        .foregroundStyle(AppColors.textTertiary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.cardBorder, lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 20)
    }

    private func cityInfoButton(icon: String, text: String, isActive: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(text)
                    .font(ThemeManager.Typography.boardLabel)
                    .tracking(0.5)
                Spacer()
            }
            .foregroundStyle(isActive ? color : AppColors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? color.opacity(0.12) : AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isActive ? color.opacity(0.3) : AppColors.cardBorder, lineWidth: 0.5)
                    )
            )
        }
    }
}

// MARK: - Edit Visit Sheet

struct EditVisitSheet: View {
    @Binding var notes: String
    @Binding var visitDate: Date
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Date picker
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.primary)
                        Text("map.visitDate".localized)
                            .font(ThemeManager.Typography.boardLabel)
                            .foregroundStyle(AppColors.textPrimary)
                            .tracking(0.5)
                    }

                    DatePicker("", selection: $visitDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(AppColors.primary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.cardBorder, lineWidth: 0.5)
                        )
                )

                // Notes field
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.primary)
                        Text("map.notes".localized)
                            .font(ThemeManager.Typography.boardLabel)
                            .foregroundStyle(AppColors.textPrimary)
                            .tracking(0.5)
                    }

                    TextEditor(text: $notes)
                        .font(ThemeManager.Typography.boardCaption)
                        .foregroundStyle(AppColors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80, maxHeight: 120)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.surfaceLight)
                        )
                        .overlay(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("map.notesPlaceholder".localized)
                                    .font(ThemeManager.Typography.boardCaption)
                                    .foregroundStyle(AppColors.textTertiary)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 18)
                                    .allowsHitTesting(false)
                            }
                        }

                    Text("\(notes.count)/200")
                        .font(ThemeManager.Typography.boardMicro)
                        .foregroundStyle(notes.count > 200 ? AppColors.error : AppColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.cardBorder, lineWidth: 0.5)
                        )
                )

                // Save button
                Button {
                    onSave()
                } label: {
                    Text("map.saveVisit".localized)
                        .font(ThemeManager.Typography.boardLabel)
                        .tracking(0.5)
                        .foregroundStyle(AppColors.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppColors.primary)
                        )
                }

                Spacer()
            }
            .padding(20)
            .background(AppColors.background)
            .navigationTitle("map.editVisit".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("map.close".localized) { dismiss() }
                        .font(ThemeManager.Typography.boardLabel)
                }
            }
        }
    }
}

// MARK: - Add City Sheet

struct AddCitySheet: View {
    let visitedCityIds: Set<String>
    let wishlistCityIds: Set<String>
    let tappedCoordinate: CLLocationCoordinate2D?
    let onCitySelected: (CityData, VisitStatus) -> Void
    let onCustomCityAdded: (CityData, VisitStatus) -> Void

    @State private var searchText = ""
    @State private var customCityName = ""
    @State private var selectedContinent: Continent? = nil
    @Environment(\.dismiss) private var dismiss

    private var filteredCities: [CityData] {
        var result = CityUtils.popularCities
        if let continent = selectedContinent {
            result = result.filter { CountryUtils.getContinent(code: $0.countryCode) == continent }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.countryName.localizedCaseInsensitiveContains(searchText) ||
                $0.localizedCountryName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Continent filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Continent.allCases, id: \.self) { continent in
                            let isActive = selectedContinent == continent
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedContinent = isActive ? nil : continent
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Text(continent.icon)
                                        .font(.system(size: 10))
                                    Text(continent.displayName)
                                        .font(ThemeManager.Typography.boardMicro)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .foregroundStyle(isActive ? AppColors.primary : AppColors.textSecondary)
                                .background(
                                    Capsule()
                                        .fill(isActive ? AppColors.primary.opacity(0.15) : AppColors.surface)
                                        .overlay(
                                            Capsule()
                                                .stroke(isActive ? AppColors.primary.opacity(0.4) : AppColors.cardBorder, lineWidth: 0.5)
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 10)

                // Haritada seçilen konum
                if let coordinate = tappedCoordinate {
                    VStack(spacing: 10) {
                        Text("map.selectedOnMap".localized)
                            .font(ThemeManager.Typography.boardCaption)
                            .foregroundStyle(AppColors.textSecondary)

                        TextField("map.enterCityName".localized, text: $customCityName)
                            .font(ThemeManager.Typography.body)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)

                        if !customCityName.isEmpty {
                            HStack(spacing: 12) {
                                Button {
                                    let city = CityData(id: UUID().uuidString, name: customCityName, countryCode: "XX", countryName: "map.customLocation".localized, latitude: coordinate.latitude, longitude: coordinate.longitude, isCustom: true)
                                    onCustomCityAdded(city, .visited)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                        Text("map.iVisited".localized)
                                            .font(ThemeManager.Typography.boardLabel)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(AppColors.success)
                                    .foregroundStyle(.white)
                                    .cornerRadius(6)
                                }

                                Button {
                                    let city = CityData(id: UUID().uuidString, name: customCityName, countryCode: "XX", countryName: "map.customLocation".localized, latitude: coordinate.latitude, longitude: coordinate.longitude, isCustom: true)
                                    onCustomCityAdded(city, .wishlist)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 12))
                                        Text("map.wishlistButton".localized)
                                            .font(ThemeManager.Typography.boardLabel)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(AppColors.primary)
                                    .foregroundStyle(.white)
                                    .cornerRadius(6)
                                }
                            }
                        }

                        Rectangle()
                            .fill(AppColors.cardBorder)
                            .frame(height: 0.5)
                            .padding(.top, 8)
                    }
                    .padding(.vertical, 14)
                    .background(AppColors.surface)
                }

                // Şehir listesi
                List {
                    ForEach(filteredCities) { city in
                        CityRow(
                            city: city,
                            isVisited: visitedCityIds.contains(city.id),
                            isWishlist: wishlistCityIds.contains(city.id),
                            onVisited: { onCitySelected(city, .visited) },
                            onWishlist: { onCitySelected(city, .wishlist) }
                        )
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "map.searchCity".localized)
            .navigationTitle("map.addCity".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("map.close".localized) { dismiss() }
                        .font(ThemeManager.Typography.boardLabel)
                }
            }
        }
    }
}

// MARK: - City Row

struct CityRow: View {
    let city: CityData
    let isVisited: Bool
    let isWishlist: Bool
    let onVisited: () -> Void
    let onWishlist: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(city.countryFlag)
                .font(.title2)

            VStack(alignment: .leading, spacing: 3) {
                Text(city.name)
                    .font(ThemeManager.Typography.boardCaption)
                    .foregroundStyle(AppColors.textPrimary)

                Text(city.localizedCountryName)
                    .font(ThemeManager.Typography.boardMicro)
                    .foregroundStyle(AppColors.textTertiary)

                if isVisited {
                    Text("map.alreadyVisited".localized)
                        .font(ThemeManager.Typography.boardMicro)
                        .foregroundStyle(AppColors.success)
                } else if isWishlist {
                    Text("map.inWishlist".localized)
                        .font(ThemeManager.Typography.boardMicro)
                        .foregroundStyle(AppColors.primary)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Button(action: onVisited) {
                    Image(systemName: isVisited ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundStyle(isVisited ? AppColors.success : AppColors.textTertiary)
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Button(action: onWishlist) {
                    Image(systemName: isWishlist ? "heart.fill" : "heart")
                        .foregroundStyle(isWishlist ? AppColors.primary : AppColors.textTertiary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Model

@MainActor
class WorldMapViewModel: ObservableObject {
    @Published var visitedCountries: [CountryData] = []
    @Published var wishlistCountries: [CountryData] = []
    @Published var visitedCities: [CityData] = []
    @Published var wishlistCities: [CityData] = []
    @Published var filterMode: FilterMode = .all
    @Published var selectedContinent: Continent? = nil
    @Published var mapSearchText: String = ""
    @Published var isLoading = false

    private var userId: String {
        if let id = UserDefaults.standard.string(forKey: "localUserId") { return id }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "localUserId")
        return newId
    }

    enum FilterMode {
        case all, visited, wishlist
    }

    var worldPercentage: Int {
        let totalCountries = 195
        return Int((Double(visitedCountries.count) / Double(totalCountries)) * 100)
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        var regions: [VisitedRegion] = []

        // Giriş yapılmışsa Supabase'den çek
        if UserManager.shared.isSignedIn, let signedInUserId = UserManager.shared.userId {
            do {
                let supabaseRegions = try await SupabaseService.shared.fetchVisitedRegions(userId: signedInUserId)
                regions = supabaseRegions
                // Yerel depolamayı güncelle
                if let data = try? JSONEncoder().encode(supabaseRegions) {
                    UserDefaults.standard.set(data, forKey: "visitedRegions")
                }
            } catch {
                regions = loadLocalRegions()
            }
        } else {
            regions = loadLocalRegions()
        }

        visitedCountries = regions
            .filter { $0.status == .visited }
            .compactMap { CountryUtils.getCountryData(code: $0.countryCode) }
        wishlistCountries = regions
            .filter { $0.status == .wishlist }
            .compactMap { CountryUtils.getCountryData(code: $0.countryCode) }

        if let data = UserDefaults.standard.data(forKey: "visitedCities"),
           let cities = try? JSONDecoder().decode([VisitedCity].self, from: data) {
            visitedCities = cities.filter { $0.status == .visited }.map { $0.city }
            wishlistCities = cities.filter { $0.status == .wishlist }.map { $0.city }
        }
    }

    func getVisitStatus(for countryCode: String) -> VisitStatus? {
        if visitedCountries.contains(where: { $0.code == countryCode }) { return .visited }
        if wishlistCountries.contains(where: { $0.code == countryCode }) { return .wishlist }
        return nil
    }

    func updateVisitStatus(countryCode: String, status: VisitStatus?) async {
        var regions = loadLocalRegions()

        // Eski kaydı bul (Supabase'de silmek için ID lazım)
        let existingRegion = regions.first { $0.countryCode == countryCode }
        regions.removeAll { $0.countryCode == countryCode }

        if let status = status {
            let newRegion = VisitedRegion(id: UUID().uuidString, userId: userId, countryCode: countryCode, regionCode: nil, cityId: nil, visitedAt: Date(), status: status, createdAt: Date())
            regions.append(newRegion)
        }
        saveLocalRegions(regions)

        // Supabase'e de yaz (giriş yapılmışsa)
        if UserManager.shared.isSignedIn, let signedInUserId = UserManager.shared.userId {
            do {
                // Önce eskiyi sil
                if let existing = existingRegion {
                    try await SupabaseService.shared.deleteVisitedRegion(id: existing.id)
                }
                // Yeni durumu ekle
                if let status = status {
                    _ = try await SupabaseService.shared.addVisitedRegion(userId: signedInUserId, countryCode: countryCode, status: status)
                }
            } catch {
            }
        }

        await loadData()
    }

    private func loadLocalRegions() -> [VisitedRegion] {
        guard let data = UserDefaults.standard.data(forKey: "visitedRegions"),
              let regions = try? JSONDecoder().decode([VisitedRegion].self, from: data) else { return [] }
        return regions
    }

    private func saveLocalRegions(_ regions: [VisitedRegion]) {
        if let data = try? JSONEncoder().encode(regions) {
            UserDefaults.standard.set(data, forKey: "visitedRegions")
        }
    }

    func getCityVisitStatus(for cityId: String) -> VisitStatus? {
        if visitedCities.contains(where: { $0.id == cityId }) { return .visited }
        if wishlistCities.contains(where: { $0.id == cityId }) { return .wishlist }
        return nil
    }

    func updateCityVisitStatus(cityId: String, status: VisitStatus?) async {
        var cities = loadLocalCities()
        cities.removeAll { $0.city.id == cityId }
        if let status = status {
            if let city = CityUtils.popularCities.first(where: { $0.id == cityId }) ??
                          visitedCities.first(where: { $0.id == cityId }) ??
                          wishlistCities.first(where: { $0.id == cityId }) {
                cities.append(VisitedCity(id: UUID().uuidString, userId: userId, city: city, visitedAt: Date(), status: status, createdAt: Date()))
            }
        }
        saveLocalCities(cities)
        await loadData()
    }

    func addCustomCity(_ city: CityData, status: VisitStatus) async {
        var cities = loadLocalCities()
        cities.append(VisitedCity(id: UUID().uuidString, userId: userId, city: city, visitedAt: Date(), status: status, createdAt: Date()))
        saveLocalCities(cities)
        await loadData()
    }

    private func loadLocalCities() -> [VisitedCity] {
        guard let data = UserDefaults.standard.data(forKey: "visitedCities"),
              let cities = try? JSONDecoder().decode([VisitedCity].self, from: data) else { return [] }
        return cities
    }

    private func saveLocalCities(_ cities: [VisitedCity]) {
        if let data = try? JSONEncoder().encode(cities) {
            UserDefaults.standard.set(data, forKey: "visitedCities")
        }
    }

    // MARK: - Notes & Date

    func getCountryNotes(for countryCode: String) -> String? {
        loadLocalRegions().first { $0.countryCode == countryCode }?.notes
    }

    func getCountryVisitDate(for countryCode: String) -> Date? {
        loadLocalRegions().first { $0.countryCode == countryCode }?.visitedAt
    }

    func updateCountryDetails(countryCode: String, notes: String?, visitDate: Date?) async {
        var regions = loadLocalRegions()
        if let index = regions.firstIndex(where: { $0.countryCode == countryCode }) {
            regions[index].notes = notes
            regions[index].visitedAt = visitDate
            saveLocalRegions(regions)

            // Supabase sync
            if UserManager.shared.isSignedIn {
                let region = regions[index]
                do {
                    try await SupabaseService.shared.updateVisitedRegion(id: region.id, status: region.status)
                } catch {
                }
            }
        }
    }

    func getCityNotes(for cityId: String) -> String? {
        loadLocalCities().first { $0.city.id == cityId }?.notes
    }

    func getCityVisitDate(for cityId: String) -> Date? {
        loadLocalCities().first { $0.city.id == cityId }?.visitedAt
    }

    func updateCityDetails(cityId: String, notes: String?, visitDate: Date?) async {
        var cities = loadLocalCities()
        if let index = cities.firstIndex(where: { $0.city.id == cityId }) {
            cities[index].notes = notes
            // visitedAt is let, so we need to recreate
            let old = cities[index]
            cities[index] = VisitedCity(id: old.id, userId: old.userId, city: old.city, visitedAt: visitDate ?? old.visitedAt, status: old.status, createdAt: old.createdAt, notes: notes)
            saveLocalCities(cities)
        }
    }
}

// MARK: - Visited City Model

struct VisitedCity: Codable {
    let id: String
    let userId: String
    let city: CityData
    let visitedAt: Date
    let status: VisitStatus
    let createdAt: Date
    var notes: String?
}

// MARK: - Add Country Sheet

struct AddCountrySheet: View {
    let visitedCountryCodes: Set<String>
    let wishlistCountryCodes: Set<String>
    let onCountrySelected: (CountryData, VisitStatus) -> Void

    @State private var searchText = ""
    @State private var selectedContinent: Continent? = nil
    @Environment(\.dismiss) private var dismiss

    private var allCountries: [CountryData] { CountryUtils.allCountries }

    private var filteredCountries: [CountryData] {
        var result = allCountries
        if let continent = selectedContinent {
            result = result.filter { CountryUtils.getContinent(code: $0.code) == continent }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.localizedName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Continent filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Continent.allCases, id: \.self) { continent in
                            let isActive = selectedContinent == continent
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedContinent = isActive ? nil : continent
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Text(continent.icon)
                                        .font(.system(size: 10))
                                    Text(continent.displayName)
                                        .font(ThemeManager.Typography.boardMicro)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .foregroundStyle(isActive ? AppColors.primary : AppColors.textSecondary)
                                .background(
                                    Capsule()
                                        .fill(isActive ? AppColors.primary.opacity(0.15) : AppColors.surface)
                                        .overlay(
                                            Capsule()
                                                .stroke(isActive ? AppColors.primary.opacity(0.4) : AppColors.cardBorder, lineWidth: 0.5)
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 10)

                List {
                    ForEach(filteredCountries, id: \.code) { country in
                        CountryRow(
                            country: country,
                            isVisited: visitedCountryCodes.contains(country.code),
                            isWishlist: wishlistCountryCodes.contains(country.code),
                            onVisited: { onCountrySelected(country, .visited) },
                            onWishlist: { onCountrySelected(country, .wishlist) }
                        )
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "map.searchCountry".localized)
            .navigationTitle("map.addCountry".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("map.close".localized) { dismiss() }
                        .font(ThemeManager.Typography.boardLabel)
                }
            }
        }
    }
}

// MARK: - Country Row

struct CountryRow: View {
    let country: CountryData
    let isVisited: Bool
    let isWishlist: Bool
    let onVisited: () -> Void
    let onWishlist: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(country.flag)
                .font(.largeTitle)

            VStack(alignment: .leading, spacing: 3) {
                Text(country.localizedName)
                    .font(ThemeManager.Typography.boardCaption)
                    .foregroundStyle(AppColors.textPrimary)

                if isVisited {
                    Text("map.alreadyVisited".localized)
                        .font(ThemeManager.Typography.boardMicro)
                        .foregroundStyle(AppColors.success)
                } else if isWishlist {
                    Text("map.inWishlist".localized)
                        .font(ThemeManager.Typography.boardMicro)
                        .foregroundStyle(AppColors.primary)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Button(action: onVisited) {
                    Image(systemName: isVisited ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundStyle(isVisited ? AppColors.success : AppColors.textTertiary)
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Button(action: onWishlist) {
                    Image(systemName: isWishlist ? "heart.fill" : "heart")
                        .foregroundStyle(isWishlist ? AppColors.primary : AppColors.textTertiary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Country Utils

enum CountryUtils {
    static let allCountries: [CountryData] = {
        // 195 ülkenin tamamı - code, name, flag, lat, lng, radiusKm
        let countries: [(code: String, name: String, flag: String, lat: Double, lng: Double, radius: Double)] = [
            // A
            ("AF", "Afganistan", "🇦🇫", 33.9, 67.7, 350),
            ("AL", "Arnavutluk", "🇦🇱", 41.0, 20.0, 70),
            ("DZ", "Cezayir", "🇩🇿", 28.0, 3.0, 800),
            ("AD", "Andorra", "🇦🇩", 42.5, 1.5, 15),
            ("AO", "Angola", "🇦🇴", -12.5, 18.5, 500),
            ("AG", "Antigua ve Barbuda", "🇦🇬", 17.1, -61.8, 20),
            ("AR", "Arjantin", "🇦🇷", -34.0, -64.0, 800),
            ("AM", "Ermenistan", "🇦🇲", 40.0, 45.0, 80),
            ("AU", "Avustralya", "🇦🇺", -25.0, 134.0, 1500),
            ("AT", "Avusturya", "🇦🇹", 47.5, 14.5, 150),
            ("AZ", "Azerbaycan", "🇦🇿", 40.5, 47.5, 150),
            // B
            ("BS", "Bahamalar", "🇧🇸", 25.0, -77.5, 80),
            ("BH", "Bahreyn", "🇧🇭", 26.0, 50.5, 20),
            ("BD", "Bangladeş", "🇧🇩", 24.0, 90.0, 150),
            ("BB", "Barbados", "🇧🇧", 13.2, -59.5, 15),
            ("BY", "Belarus", "🇧🇾", 53.0, 28.0, 200),
            ("BE", "Belçika", "🇧🇪", 50.5, 4.5, 80),
            ("BZ", "Belize", "🇧🇿", 17.2, -88.7, 60),
            ("BJ", "Benin", "🇧🇯", 9.3, 2.3, 100),
            ("BT", "Bhutan", "🇧🇹", 27.5, 90.5, 60),
            ("BO", "Bolivya", "🇧🇴", -17.0, -65.0, 400),
            ("BA", "Bosna Hersek", "🇧🇦", 44.0, 18.0, 80),
            ("BW", "Botsvana", "🇧🇼", -22.0, 24.0, 350),
            ("BR", "Brezilya", "🇧🇷", -14.0, -51.0, 1200),
            ("BN", "Brunei", "🇧🇳", 4.5, 114.7, 30),
            ("BG", "Bulgaristan", "🇧🇬", 43.0, 25.0, 150),
            ("BF", "Burkina Faso", "🇧🇫", 12.2, -1.5, 200),
            ("BI", "Burundi", "🇧🇮", -3.4, 29.9, 50),
            // C
            ("CV", "Cabo Verde", "🇨🇻", 15.1, -23.6, 40),
            ("KH", "Kamboçya", "🇰🇭", 13.0, 105.0, 150),
            ("CM", "Kamerun", "🇨🇲", 6.0, 12.5, 300),
            ("CA", "Kanada", "🇨🇦", 56.0, -106.0, 1500),
            ("CF", "Orta Afrika Cumhuriyeti", "🇨🇫", 6.6, 20.9, 350),
            ("TD", "Çad", "🇹🇩", 15.5, 19.0, 500),
            ("CL", "Şili", "🇨🇱", -35.0, -71.0, 600),
            ("CN", "Çin", "🇨🇳", 35.0, 105.0, 1500),
            ("CO", "Kolombiya", "🇨🇴", 4.0, -72.0, 400),
            ("KM", "Komorlar", "🇰🇲", -12.2, 44.2, 30),
            ("CG", "Kongo Cumhuriyeti", "🇨🇬", -0.2, 15.8, 250),
            ("CD", "Kongo Demokratik Cumhuriyeti", "🇨🇩", -4.0, 21.8, 600),
            ("CR", "Kosta Rika", "🇨🇷", 10.0, -84.0, 80),
            ("CI", "Fildişi Sahili", "🇨🇮", 7.5, -5.5, 200),
            ("HR", "Hırvatistan", "🇭🇷", 45.0, 16.0, 150),
            ("CU", "Küba", "🇨🇺", 22.0, -79.5, 200),
            ("CY", "Kıbrıs", "🇨🇾", 35.0, 33.0, 60),
            ("CZ", "Çekya", "🇨🇿", 50.0, 15.0, 120),
            // D
            ("DK", "Danimarka", "🇩🇰", 56.0, 10.0, 100),
            ("DJ", "Cibuti", "🇩🇯", 11.6, 43.1, 50),
            ("DM", "Dominika", "🇩🇲", 15.4, -61.4, 20),
            ("DO", "Dominik Cumhuriyeti", "🇩🇴", 19.0, -70.0, 80),
            // E
            ("EC", "Ekvador", "🇪🇨", -2.0, -77.5, 200),
            ("EG", "Mısır", "🇪🇬", 26.0, 30.0, 500),
            ("SV", "El Salvador", "🇸🇻", 13.8, -88.9, 50),
            ("GQ", "Ekvator Ginesi", "🇬🇶", 1.6, 10.3, 50),
            ("ER", "Eritre", "🇪🇷", 15.2, 39.8, 100),
            ("EE", "Estonya", "🇪🇪", 58.6, 25.0, 80),
            ("SZ", "Eswatini", "🇸🇿", -26.5, 31.5, 40),
            ("ET", "Etiyopya", "🇪🇹", 9.0, 38.7, 450),
            // F
            ("FJ", "Fiji", "🇫🇯", -18.0, 179.0, 80),
            ("FI", "Finlandiya", "🇫🇮", 64.0, 26.0, 350),
            ("FR", "Fransa", "🇫🇷", 46.0, 2.0, 350),
            // G
            ("GA", "Gabon", "🇬🇦", -0.8, 11.6, 200),
            ("GM", "Gambiya", "🇬🇲", 13.5, -15.5, 40),
            ("GE", "Gürcistan", "🇬🇪", 42.0, 43.5, 120),
            ("DE", "Almanya", "🇩🇪", 51.0, 10.0, 300),
            ("GH", "Gana", "🇬🇭", 8.0, -2.0, 150),
            ("GR", "Yunanistan", "🇬🇷", 39.0, 22.0, 200),
            ("GD", "Grenada", "🇬🇩", 12.1, -61.7, 15),
            ("GT", "Guatemala", "🇬🇹", 15.5, -90.3, 100),
            ("GN", "Gine", "🇬🇳", 10.0, -10.0, 150),
            ("GW", "Gine-Bissau", "🇬🇼", 12.0, -15.0, 50),
            ("GY", "Guyana", "🇬🇾", 5.0, -59.0, 150),
            // H
            ("HT", "Haiti", "🇭🇹", 19.0, -72.3, 80),
            ("HN", "Honduras", "🇭🇳", 15.0, -86.5, 100),
            ("HU", "Macaristan", "🇭🇺", 47.0, 20.0, 150),
            // I
            ("IS", "İzlanda", "🇮🇸", 65.0, -18.0, 200),
            ("IN", "Hindistan", "🇮🇳", 21.0, 78.0, 800),
            ("ID", "Endonezya", "🇮🇩", -5.0, 120.0, 800),
            ("IR", "İran", "🇮🇷", 32.0, 53.0, 600),
            ("IQ", "Irak", "🇮🇶", 33.0, 44.0, 300),
            ("IE", "İrlanda", "🇮🇪", 53.0, -8.0, 150),
            ("IL", "İsrail", "🇮🇱", 31.0, 35.0, 80),
            ("IT", "İtalya", "🇮🇹", 42.0, 12.0, 350),
            // J
            ("JM", "Jamaika", "🇯🇲", 18.0, -77.5, 60),
            ("JP", "Japonya", "🇯🇵", 36.0, 138.0, 400),
            ("JO", "Ürdün", "🇯🇴", 31.0, 36.0, 100),
            // K
            ("KZ", "Kazakistan", "🇰🇿", 48.0, 68.0, 800),
            ("KE", "Kenya", "🇰🇪", 1.0, 38.0, 350),
            ("KI", "Kiribati", "🇰🇮", 1.4, 173.0, 40),
            ("KP", "Kuzey Kore", "🇰🇵", 40.0, 127.0, 150),
            ("KR", "Güney Kore", "🇰🇷", 36.0, 128.0, 150),
            ("KW", "Kuveyt", "🇰🇼", 29.5, 47.5, 60),
            ("KG", "Kırgızistan", "🇰🇬", 41.0, 75.0, 200),
            // L
            ("LA", "Laos", "🇱🇦", 18.0, 105.0, 200),
            ("LV", "Letonya", "🇱🇻", 57.0, 25.0, 100),
            ("LB", "Lübnan", "🇱🇧", 33.9, 35.5, 50),
            ("LS", "Lesotho", "🇱🇸", -29.5, 28.5, 50),
            ("LR", "Liberya", "🇱🇷", 6.5, -9.5, 100),
            ("LY", "Libya", "🇱🇾", 27.0, 17.0, 600),
            ("LI", "Liechtenstein", "🇱🇮", 47.2, 9.5, 10),
            ("LT", "Litvanya", "🇱🇹", 55.0, 24.0, 100),
            ("LU", "Lüksemburg", "🇱🇺", 49.7, 6.1, 25),
            // M
            ("MG", "Madagaskar", "🇲🇬", -20.0, 47.0, 400),
            ("MW", "Malavi", "🇲🇼", -13.5, 34.0, 100),
            ("MY", "Malezya", "🇲🇾", 4.0, 109.0, 400),
            ("MV", "Maldivler", "🇲🇻", 3.2, 73.2, 50),
            ("ML", "Mali", "🇲🇱", 17.5, -4.0, 500),
            ("MT", "Malta", "🇲🇹", 35.9, 14.4, 15),
            ("MH", "Marshall Adaları", "🇲🇭", 7.1, 171.2, 30),
            ("MR", "Moritanya", "🇲🇷", 20.0, -10.0, 500),
            ("MU", "Mauritius", "🇲🇺", -20.3, 57.6, 30),
            ("MX", "Meksika", "🇲🇽", 23.0, -102.0, 600),
            ("FM", "Mikronezya", "🇫🇲", 6.9, 158.2, 40),
            ("MD", "Moldova", "🇲🇩", 47.0, 29.0, 80),
            ("MC", "Monako", "🇲🇨", 43.7, 7.4, 5),
            ("MN", "Moğolistan", "🇲🇳", 46.0, 105.0, 600),
            ("ME", "Karadağ", "🇲🇪", 42.5, 19.3, 50),
            ("MA", "Fas", "🇲🇦", 32.0, -5.0, 350),
            ("MZ", "Mozambik", "🇲🇿", -18.0, 35.0, 400),
            ("MM", "Myanmar", "🇲🇲", 22.0, 96.0, 350),
            // N
            ("NA", "Namibya", "🇳🇦", -22.0, 17.0, 400),
            ("NR", "Nauru", "🇳🇷", -0.5, 166.9, 10),
            ("NP", "Nepal", "🇳🇵", 28.0, 84.0, 150),
            ("NL", "Hollanda", "🇳🇱", 52.0, 5.0, 100),
            ("NZ", "Yeni Zelanda", "🇳🇿", -41.0, 174.0, 400),
            ("NI", "Nikaragua", "🇳🇮", 13.0, -85.0, 100),
            ("NE", "Nijer", "🇳🇪", 16.0, 8.0, 500),
            ("NG", "Nijerya", "🇳🇬", 10.0, 8.0, 400),
            ("MK", "Kuzey Makedonya", "🇲🇰", 41.5, 21.7, 60),
            ("NO", "Norveç", "🇳🇴", 62.0, 10.0, 400),
            // O
            ("OM", "Umman", "🇴🇲", 21.0, 57.0, 250),
            // P
            ("PK", "Pakistan", "🇵🇰", 30.0, 70.0, 450),
            ("PW", "Palau", "🇵🇼", 7.5, 134.6, 20),
            ("PS", "Filistin", "🇵🇸", 31.9, 35.2, 30),
            ("PA", "Panama", "🇵🇦", 9.0, -80.0, 100),
            ("PG", "Papua Yeni Gine", "🇵🇬", -6.0, 147.0, 300),
            ("PY", "Paraguay", "🇵🇾", -23.0, -58.0, 250),
            ("PE", "Peru", "🇵🇪", -10.0, -76.0, 450),
            ("PH", "Filipinler", "🇵🇭", 13.0, 122.0, 350),
            ("PL", "Polonya", "🇵🇱", 52.0, 20.0, 250),
            ("PT", "Portekiz", "🇵🇹", 39.5, -8.0, 150),
            // Q
            ("QA", "Katar", "🇶🇦", 25.5, 51.2, 50),
            // R
            ("RO", "Romanya", "🇷🇴", 46.0, 25.0, 200),
            ("RU", "Rusya", "🇷🇺", 61.0, 105.0, 2000),
            ("RW", "Ruanda", "🇷🇼", -2.0, 30.0, 50),
            // S
            ("KN", "Saint Kitts ve Nevis", "🇰🇳", 17.3, -62.7, 15),
            ("LC", "Saint Lucia", "🇱🇨", 13.9, -61.0, 15),
            ("VC", "Saint Vincent ve Grenadinler", "🇻🇨", 13.2, -61.2, 15),
            ("WS", "Samoa", "🇼🇸", -13.8, -172.0, 30),
            ("SM", "San Marino", "🇸🇲", 43.9, 12.5, 10),
            ("ST", "São Tomé ve Príncipe", "🇸🇹", 0.2, 6.6, 20),
            ("SA", "Suudi Arabistan", "🇸🇦", 24.0, 45.0, 700),
            ("SN", "Senegal", "🇸🇳", 14.5, -14.5, 150),
            ("RS", "Sırbistan", "🇷🇸", 44.0, 21.0, 120),
            ("SC", "Seyşeller", "🇸🇨", -4.7, 55.5, 30),
            ("SL", "Sierra Leone", "🇸🇱", 8.5, -11.8, 80),
            ("SG", "Singapur", "🇸🇬", 1.3, 103.8, 20),
            ("SK", "Slovakya", "🇸🇰", 48.7, 19.7, 100),
            ("SI", "Slovenya", "🇸🇮", 46.0, 15.0, 60),
            ("SB", "Solomon Adaları", "🇸🇧", -8.0, 159.0, 80),
            ("SO", "Somali", "🇸🇴", 5.0, 46.0, 350),
            ("ZA", "Güney Afrika", "🇿🇦", -29.0, 24.0, 500),
            ("SS", "Güney Sudan", "🇸🇸", 7.0, 30.0, 350),
            ("ES", "İspanya", "🇪🇸", 40.0, -4.0, 350),
            ("LK", "Sri Lanka", "🇱🇰", 7.0, 81.0, 120),
            ("SD", "Sudan", "🇸🇩", 15.0, 30.0, 600),
            ("SR", "Surinam", "🇸🇷", 4.0, -56.0, 100),
            ("SE", "İsveç", "🇸🇪", 62.0, 15.0, 400),
            ("CH", "İsviçre", "🇨🇭", 47.0, 8.0, 100),
            ("SY", "Suriye", "🇸🇾", 35.0, 38.0, 150),
            // T
            ("TW", "Tayvan", "🇹🇼", 23.7, 121.0, 100),
            ("TJ", "Tacikistan", "🇹🇯", 38.9, 71.3, 150),
            ("TZ", "Tanzanya", "🇹🇿", -6.0, 35.0, 400),
            ("TH", "Tayland", "🇹🇭", 15.0, 101.0, 350),
            ("TL", "Doğu Timor", "🇹🇱", -8.9, 126.0, 40),
            ("TG", "Togo", "🇹🇬", 8.6, 1.0, 60),
            ("TO", "Tonga", "🇹🇴", -21.2, -175.2, 20),
            ("TT", "Trinidad ve Tobago", "🇹🇹", 10.5, -61.3, 30),
            ("TN", "Tunus", "🇹🇳", 34.0, 9.0, 150),
            ("TR", "Türkiye", "🇹🇷", 39.0, 35.0, 400),
            ("TM", "Türkmenistan", "🇹🇲", 39.0, 59.6, 300),
            ("TV", "Tuvalu", "🇹🇻", -8.0, 178.0, 10),
            // U
            ("UG", "Uganda", "🇺🇬", 1.4, 32.3, 200),
            ("UA", "Ukrayna", "🇺🇦", 49.0, 32.0, 400),
            ("AE", "Birleşik Arap Emirlikleri", "🇦🇪", 24.0, 54.0, 150),
            ("GB", "Birleşik Krallık", "🇬🇧", 54.0, -2.0, 250),
            ("US", "Amerika Birleşik Devletleri", "🇺🇸", 37.0, -95.0, 1500),
            ("UY", "Uruguay", "🇺🇾", -33.0, -56.0, 150),
            ("UZ", "Özbekistan", "🇺🇿", 41.0, 64.0, 300),
            // V
            ("VU", "Vanuatu", "🇻🇺", -16.0, 167.0, 60),
            ("VA", "Vatikan", "🇻🇦", 41.9, 12.5, 1),
            ("VE", "Venezuela", "🇻🇪", 8.0, -66.0, 400),
            ("VN", "Vietnam", "🇻🇳", 16.0, 108.0, 350),
            // Y
            ("YE", "Yemen", "🇾🇪", 15.5, 48.5, 300),
            // Z
            ("ZM", "Zambiya", "🇿🇲", -15.0, 30.0, 400),
            ("ZW", "Zimbabve", "🇿🇼", -19.0, 29.0, 250),
            // Ekstra bölgeler
            ("HK", "Hong Kong", "🇭🇰", 22.3, 114.2, 20),
            ("MO", "Makao", "🇲🇴", 22.2, 113.5, 10),
            ("XK", "Kosova", "🇽🇰", 42.6, 21.0, 50)
        ]

        return countries.map { country in
            CountryData(
                code: country.code,
                name: country.name,
                flag: country.flag,
                latitude: country.lat,
                longitude: country.lng,
                radiusKm: country.radius
            )
        }.sorted { $0.name < $1.name }
    }()

    static func getCountryData(code: String) -> CountryData? {
        allCountries.first { $0.code == code }
    }

    static func getContinent(code: String) -> Continent? {
        continentMapping[code]
    }

    static let continentMapping: [String: Continent] = [
        // Europe
        "AL": .europe, "AD": .europe, "AT": .europe, "BY": .europe, "BE": .europe,
        "BA": .europe, "BG": .europe, "HR": .europe, "CY": .europe, "CZ": .europe,
        "DK": .europe, "EE": .europe, "FI": .europe, "FR": .europe, "DE": .europe,
        "GR": .europe, "HU": .europe, "IS": .europe, "IE": .europe, "IT": .europe,
        "XK": .europe, "LV": .europe, "LI": .europe, "LT": .europe, "LU": .europe,
        "MT": .europe, "MD": .europe, "MC": .europe, "ME": .europe, "NL": .europe,
        "MK": .europe, "NO": .europe, "PL": .europe, "PT": .europe, "RO": .europe,
        "RU": .europe, "SM": .europe, "RS": .europe, "SK": .europe, "SI": .europe,
        "ES": .europe, "SE": .europe, "CH": .europe, "UA": .europe, "GB": .europe,
        "VA": .europe, "TR": .europe,
        // Asia
        "AF": .asia, "AM": .asia, "AZ": .asia, "BH": .asia, "BD": .asia,
        "BT": .asia, "BN": .asia, "KH": .asia, "CN": .asia, "GE": .asia,
        "IN": .asia, "ID": .asia, "IR": .asia, "IQ": .asia, "IL": .asia,
        "JP": .asia, "JO": .asia, "KZ": .asia, "KW": .asia, "KG": .asia,
        "LA": .asia, "LB": .asia, "MY": .asia, "MV": .asia, "MN": .asia,
        "MM": .asia, "NP": .asia, "KP": .asia, "KR": .asia, "OM": .asia,
        "PK": .asia, "PS": .asia, "PH": .asia, "QA": .asia, "SA": .asia,
        "SG": .asia, "LK": .asia, "SY": .asia, "TW": .asia, "TJ": .asia,
        "TH": .asia, "TL": .asia, "TM": .asia, "AE": .asia, "UZ": .asia,
        "VN": .asia, "YE": .asia, "HK": .asia, "MO": .asia,
        // Americas
        "AG": .americas, "AR": .americas, "BS": .americas, "BB": .americas,
        "BZ": .americas, "BO": .americas, "BR": .americas, "CA": .americas,
        "CL": .americas, "CO": .americas, "CR": .americas, "CU": .americas,
        "DM": .americas, "DO": .americas, "EC": .americas, "SV": .americas,
        "GD": .americas, "GT": .americas, "GY": .americas, "HT": .americas,
        "HN": .americas, "JM": .americas, "MX": .americas, "NI": .americas,
        "PA": .americas, "PY": .americas, "PE": .americas, "KN": .americas,
        "LC": .americas, "VC": .americas, "SR": .americas, "TT": .americas,
        "US": .americas, "UY": .americas, "VE": .americas,
        // Africa
        "DZ": .africa, "AO": .africa, "BJ": .africa, "BW": .africa, "BF": .africa,
        "BI": .africa, "CV": .africa, "CM": .africa, "CF": .africa, "TD": .africa,
        "KM": .africa, "CG": .africa, "CD": .africa, "CI": .africa, "DJ": .africa,
        "EG": .africa, "GQ": .africa, "ER": .africa, "SZ": .africa, "ET": .africa,
        "GA": .africa, "GM": .africa, "GH": .africa, "GN": .africa, "GW": .africa,
        "KE": .africa, "LS": .africa, "LR": .africa, "LY": .africa, "MG": .africa,
        "MW": .africa, "ML": .africa, "MR": .africa, "MU": .africa, "MA": .africa,
        "MZ": .africa, "NA": .africa, "NE": .africa, "NG": .africa, "RW": .africa,
        "ST": .africa, "SN": .africa, "SC": .africa, "SL": .africa, "SO": .africa,
        "ZA": .africa, "SS": .africa, "SD": .africa, "TZ": .africa, "TG": .africa,
        "TN": .africa, "UG": .africa, "ZM": .africa, "ZW": .africa,
        // Oceania
        "AU": .oceania, "FJ": .oceania, "KI": .oceania, "MH": .oceania,
        "FM": .oceania, "NR": .oceania, "NZ": .oceania, "PW": .oceania,
        "PG": .oceania, "WS": .oceania, "SB": .oceania, "TO": .oceania,
        "TV": .oceania, "VU": .oceania
    ]
}

// MARK: - City Utils

enum CityUtils {
    static let popularCities: [CityData] = {
        let cities: [(id: String, name: String, countryCode: String, countryName: String, lat: Double, lng: Double)] = [
            // Türkiye - Büyükşehirler ve Popüler Şehirler
            ("istanbul", "İstanbul", "TR", "Türkiye", 41.0082, 28.9784),
            ("ankara", "Ankara", "TR", "Türkiye", 39.9334, 32.8597),
            ("izmir", "İzmir", "TR", "Türkiye", 38.4237, 27.1428),
            ("antalya", "Antalya", "TR", "Türkiye", 36.8969, 30.7133),
            ("bursa", "Bursa", "TR", "Türkiye", 40.1885, 29.0610),
            ("adana", "Adana", "TR", "Türkiye", 37.0000, 35.3213),
            ("konya", "Konya", "TR", "Türkiye", 37.8746, 32.4932),
            ("gaziantep", "Gaziantep", "TR", "Türkiye", 37.0662, 37.3833),
            ("mersin", "Mersin", "TR", "Türkiye", 36.8121, 34.6415),
            ("diyarbakir", "Diyarbakır", "TR", "Türkiye", 37.9144, 40.2306),
            ("kayseri", "Kayseri", "TR", "Türkiye", 38.7312, 35.4787),
            ("eskisehir", "Eskişehir", "TR", "Türkiye", 39.7667, 30.5256),
            ("trabzon", "Trabzon", "TR", "Türkiye", 41.0027, 39.7168),
            ("samsun", "Samsun", "TR", "Türkiye", 41.2867, 36.33),
            ("denizli", "Denizli", "TR", "Türkiye", 37.7765, 29.0864),
            ("malatya", "Malatya", "TR", "Türkiye", 38.3552, 38.3095),
            ("erzurum", "Erzurum", "TR", "Türkiye", 39.9043, 41.2679),
            ("sanliurfa", "Şanlıurfa", "TR", "Türkiye", 37.1591, 38.7969),
            ("mugla", "Muğla", "TR", "Türkiye", 37.2153, 28.3636),
            ("bodrum", "Bodrum", "TR", "Türkiye", 37.0343, 27.4305),
            ("fethiye", "Fethiye", "TR", "Türkiye", 36.6518, 29.1168),
            ("marmaris", "Marmaris", "TR", "Türkiye", 36.8550, 28.2741),
            ("kusadasi", "Kuşadası", "TR", "Türkiye", 37.8579, 27.2610),
            ("cesme", "Çeşme", "TR", "Türkiye", 38.3236, 26.3031),
            ("alanya", "Alanya", "TR", "Türkiye", 36.5436, 31.9994),
            ("side", "Side", "TR", "Türkiye", 36.7667, 31.3897),
            ("kapadokya", "Kapadokya", "TR", "Türkiye", 38.6431, 34.8289),
            ("pamukkale", "Pamukkale", "TR", "Türkiye", 37.9204, 29.1186),
            ("canakkale", "Çanakkale", "TR", "Türkiye", 40.1553, 26.4142),
            ("edirne", "Edirne", "TR", "Türkiye", 41.6818, 26.5623),
            ("sakarya", "Sakarya", "TR", "Türkiye", 40.7569, 30.3781),
            ("kocaeli", "Kocaeli", "TR", "Türkiye", 40.8533, 29.8815),
            ("tekirdag", "Tekirdağ", "TR", "Türkiye", 40.9833, 27.5167),
            ("manisa", "Manisa", "TR", "Türkiye", 38.6191, 27.4289),
            ("aydin", "Aydın", "TR", "Türkiye", 37.8560, 27.8416),
            ("balikesir", "Balıkesir", "TR", "Türkiye", 39.6484, 27.8826),
            ("kahramanmaras", "Kahramanmaraş", "TR", "Türkiye", 37.5858, 36.9371),
            ("van", "Van", "TR", "Türkiye", 38.4891, 43.4089),
            ("elazig", "Elazığ", "TR", "Türkiye", 38.6810, 39.2264),
            ("batman", "Batman", "TR", "Türkiye", 37.8812, 41.1351),
            ("mardin", "Mardin", "TR", "Türkiye", 37.3212, 40.7245),
            ("rize", "Rize", "TR", "Türkiye", 41.0201, 40.5234),
            ("artvin", "Artvin", "TR", "Türkiye", 41.1828, 41.8183),
            ("ordu", "Ordu", "TR", "Türkiye", 40.9862, 37.8797),
            ("giresun", "Giresun", "TR", "Türkiye", 40.9128, 38.3895),
            ("sinop", "Sinop", "TR", "Türkiye", 42.0231, 35.1531),
            ("kastamonu", "Kastamonu", "TR", "Türkiye", 41.3887, 33.7827),
            ("bolu", "Bolu", "TR", "Türkiye", 40.7392, 31.6089),
            ("afyon", "Afyonkarahisar", "TR", "Türkiye", 38.7507, 30.5567),
            ("isparta", "Isparta", "TR", "Türkiye", 37.7648, 30.5566),
            ("nevsehir", "Nevşehir", "TR", "Türkiye", 38.6939, 34.6857),
            ("aksaray", "Aksaray", "TR", "Türkiye", 38.3687, 34.0370),
            ("nigde", "Niğde", "TR", "Türkiye", 37.9667, 34.6833),
            ("karaman", "Karaman", "TR", "Türkiye", 37.1759, 33.2287),
            ("hatay", "Hatay", "TR", "Türkiye", 36.2025, 36.1606),
            ("osmaniye", "Osmaniye", "TR", "Türkiye", 37.0742, 36.2474),
            ("adiyaman", "Adıyaman", "TR", "Türkiye", 37.7648, 38.2786),
            ("siirt", "Siirt", "TR", "Türkiye", 37.9333, 41.95),
            ("bitlis", "Bitlis", "TR", "Türkiye", 38.4, 42.1167),
            ("mus", "Muş", "TR", "Türkiye", 38.7432, 41.5064),
            ("agri", "Ağrı", "TR", "Türkiye", 39.7191, 43.0503),
            ("kars", "Kars", "TR", "Türkiye", 40.6013, 43.0975),
            ("igdir", "Iğdır", "TR", "Türkiye", 39.9237, 44.0450),
            ("ardahan", "Ardahan", "TR", "Türkiye", 41.1105, 42.7022),
            ("hakkari", "Hakkâri", "TR", "Türkiye", 37.5833, 43.7333),
            ("sirnak", "Şırnak", "TR", "Türkiye", 37.5164, 42.4611),
            ("tunceli", "Tunceli", "TR", "Türkiye", 39.1079, 39.5401),
            ("bingol", "Bingöl", "TR", "Türkiye", 38.8854, 40.4966),
            ("erzincan", "Erzincan", "TR", "Türkiye", 39.7500, 39.5000),
            ("gumushane", "Gümüşhane", "TR", "Türkiye", 40.4386, 39.5086),
            ("bayburt", "Bayburt", "TR", "Türkiye", 40.2552, 40.2249),
            ("amasya", "Amasya", "TR", "Türkiye", 40.6499, 35.8353),
            ("tokat", "Tokat", "TR", "Türkiye", 40.3167, 36.55),
            ("sivas", "Sivas", "TR", "Türkiye", 39.7477, 37.0179),
            ("yozgat", "Yozgat", "TR", "Türkiye", 39.8181, 34.8147),
            ("corum", "Çorum", "TR", "Türkiye", 40.5506, 34.9556),
            ("cankiri", "Çankırı", "TR", "Türkiye", 40.6013, 33.6134),
            ("kirikkale", "Kırıkkale", "TR", "Türkiye", 39.8468, 33.5153),
            ("kirsehir", "Kırşehir", "TR", "Türkiye", 39.1425, 34.1709),
            ("usak", "Uşak", "TR", "Türkiye", 38.6823, 29.4082),
            ("kutahya", "Kütahya", "TR", "Türkiye", 39.4167, 29.9833),
            ("bilecik", "Bilecik", "TR", "Türkiye", 40.0567, 30.0665),
            ("duzce", "Düzce", "TR", "Türkiye", 40.8438, 31.1565),
            ("zonguldak", "Zonguldak", "TR", "Türkiye", 41.4564, 31.7987),
            ("karabuk", "Karabük", "TR", "Türkiye", 41.2061, 32.6204),
            ("bartin", "Bartın", "TR", "Türkiye", 41.6344, 32.3375),
            ("yalova", "Yalova", "TR", "Türkiye", 40.6500, 29.2667),
            ("kirklareli", "Kırklareli", "TR", "Türkiye", 41.7333, 27.2167),
            ("kilis", "Kilis", "TR", "Türkiye", 36.7184, 37.1212),

            // Avrupa - Batı Avrupa
            ("paris", "Paris", "FR", "Fransa", 48.8566, 2.3522),
            ("london", "Londra", "GB", "İngiltere", 51.5074, -0.1278),
            ("rome", "Roma", "IT", "İtalya", 41.9028, 12.4964),
            ("madrid", "Madrid", "ES", "İspanya", 40.4168, -3.7038),
            ("berlin", "Berlin", "DE", "Almanya", 52.5200, 13.4050),
            ("amsterdam", "Amsterdam", "NL", "Hollanda", 52.3676, 4.9041),
            ("barcelona", "Barselona", "ES", "İspanya", 41.3851, 2.1734),
            ("vienna", "Viyana", "AT", "Avusturya", 48.2082, 16.3738),
            ("lisbon", "Lizbon", "PT", "Portekiz", 38.7223, -9.1393),
            ("brussels", "Brüksel", "BE", "Belçika", 50.8503, 4.3517),
            ("milan", "Milano", "IT", "İtalya", 45.4642, 9.1900),
            ("venice", "Venedik", "IT", "İtalya", 45.4408, 12.3155),
            ("florence", "Floransa", "IT", "İtalya", 43.7696, 11.2558),
            ("munich", "Münih", "DE", "Almanya", 48.1351, 11.5820),
            ("zurich", "Zürih", "CH", "İsviçre", 47.3769, 8.5417),
            ("geneva", "Cenevre", "CH", "İsviçre", 46.2044, 6.1432),
            ("lyon", "Lyon", "FR", "Fransa", 45.7640, 4.8357),
            ("nice", "Nice", "FR", "Fransa", 43.7102, 7.2620),
            ("marseille", "Marsilya", "FR", "Fransa", 43.2965, 5.3698),
            ("sevilla", "Sevilla", "ES", "İspanya", 37.3891, -5.9845),
            ("valencia", "Valencia", "ES", "İspanya", 39.4699, -0.3763),
            ("porto", "Porto", "PT", "Portekiz", 41.1579, -8.6291),
            ("naples", "Napoli", "IT", "İtalya", 40.8518, 14.2681),
            ("turin", "Torino", "IT", "İtalya", 45.0703, 7.6869),
            ("frankfurt", "Frankfurt", "DE", "Almanya", 50.1109, 8.6821),
            ("hamburg", "Hamburg", "DE", "Almanya", 53.5511, 9.9937),
            ("cologne", "Köln", "DE", "Almanya", 50.9375, 6.9603),
            ("dusseldorf", "Düsseldorf", "DE", "Almanya", 51.2277, 6.7735),
            ("edinburgh", "Edinburgh", "GB", "İngiltere", 55.9533, -3.1883),
            ("manchester", "Manchester", "GB", "İngiltere", 53.4808, -2.2426),
            ("liverpool", "Liverpool", "GB", "İngiltere", 53.4084, -2.9916),
            ("birmingham", "Birmingham", "GB", "İngiltere", 52.4862, -1.8904),
            ("glasgow", "Glasgow", "GB", "İngiltere", 55.8642, -4.2518),
            ("rotterdam", "Rotterdam", "NL", "Hollanda", 51.9244, 4.4777),
            ("antwerp", "Anvers", "BE", "Belçika", 51.2194, 4.4025),
            ("salzburg", "Salzburg", "AT", "Avusturya", 47.8095, 13.0550),
            ("innsbruck", "Innsbruck", "AT", "Avusturya", 47.2692, 11.4041),

            // Avrupa - Kuzey Avrupa
            ("dublin", "Dublin", "IE", "İrlanda", 53.3498, -6.2603),
            ("copenhagen", "Kopenhag", "DK", "Danimarka", 55.6761, 12.5683),
            ("stockholm", "Stokholm", "SE", "İsveç", 59.3293, 18.0686),
            ("oslo", "Oslo", "NO", "Norveç", 59.9139, 10.7522),
            ("helsinki", "Helsinki", "FI", "Finlandiya", 60.1699, 24.9384),
            ("reykjavik", "Reykjavik", "IS", "İzlanda", 64.1466, -21.9426),
            ("bergen", "Bergen", "NO", "Norveç", 60.3913, 5.3221),
            ("gothenburg", "Göteborg", "SE", "İsveç", 57.7089, 11.9746),
            ("malmo", "Malmö", "SE", "İsveç", 55.6050, 13.0038),
            ("tromso", "Tromsø", "NO", "Norveç", 69.6492, 18.9553),

            // Avrupa - Doğu Avrupa
            ("prague", "Prag", "CZ", "Çekya", 50.0755, 14.4378),
            ("budapest", "Budapeşte", "HU", "Macaristan", 47.4979, 19.0402),
            ("warsaw", "Varşova", "PL", "Polonya", 52.2297, 21.0122),
            ("krakow", "Krakov", "PL", "Polonya", 50.0647, 19.9450),
            ("moscow", "Moskova", "RU", "Rusya", 55.7558, 37.6173),
            ("stpetersburg", "St. Petersburg", "RU", "Rusya", 59.9343, 30.3351),
            ("kiev", "Kiev", "UA", "Ukrayna", 50.4501, 30.5234),
            ("bucharest", "Bükreş", "RO", "Romanya", 44.4268, 26.1025),
            ("sofia", "Sofya", "BG", "Bulgaristan", 42.6977, 23.3219),
            ("belgrade", "Belgrad", "RS", "Sırbistan", 44.7866, 20.4489),
            ("zagreb", "Zagreb", "HR", "Hırvatistan", 45.8150, 15.9819),
            ("ljubljana", "Ljubljana", "SI", "Slovenya", 46.0569, 14.5058),
            ("bratislava", "Bratislava", "SK", "Slovakya", 48.1486, 17.1077),
            ("tallinn", "Tallinn", "EE", "Estonya", 59.4370, 24.7536),
            ("riga", "Riga", "LV", "Letonya", 56.9496, 24.1052),
            ("vilnius", "Vilnius", "LT", "Litvanya", 54.6872, 25.2797),
            ("minsk", "Minsk", "BY", "Belarus", 53.9045, 27.5615),
            ("dubrovnik", "Dubrovnik", "HR", "Hırvatistan", 42.6507, 18.0944),
            ("split", "Split", "HR", "Hırvatistan", 43.5081, 16.4402),
            ("sarajevo", "Saraybosna", "BA", "Bosna Hersek", 43.8563, 18.4131),
            ("podgorica", "Podgorica", "ME", "Karadağ", 42.4304, 19.2594),
            ("tirana", "Tiran", "AL", "Arnavutluk", 41.3275, 19.8187),
            ("skopje", "Üsküp", "MK", "Kuzey Makedonya", 41.9981, 21.4254),

            // Avrupa - Güney Avrupa
            ("athens", "Atina", "GR", "Yunanistan", 37.9838, 23.7275),
            ("thessaloniki", "Selanik", "GR", "Yunanistan", 40.6401, 22.9444),
            ("santorini", "Santorini", "GR", "Yunanistan", 36.3932, 25.4615),
            ("mykonos", "Mikonos", "GR", "Yunanistan", 37.4467, 25.3289),
            ("rhodes", "Rodos", "GR", "Yunanistan", 36.4341, 28.2176),
            ("crete", "Girit", "GR", "Yunanistan", 35.2401, 24.8093),
            ("malta", "Valletta", "MT", "Malta", 35.8989, 14.5146),
            ("monaco", "Monaco", "MC", "Monaco", 43.7384, 7.4246),
            ("andorra", "Andorra", "AD", "Andorra", 42.5063, 1.5218),

            // Amerika - Kuzey Amerika
            ("newyork", "New York", "US", "ABD", 40.7128, -74.0060),
            ("losangeles", "Los Angeles", "US", "ABD", 34.0522, -118.2437),
            ("chicago", "Chicago", "US", "ABD", 41.8781, -87.6298),
            ("miami", "Miami", "US", "ABD", 25.7617, -80.1918),
            ("sanfrancisco", "San Francisco", "US", "ABD", 37.7749, -122.4194),
            ("lasvegas", "Las Vegas", "US", "ABD", 36.1699, -115.1398),
            ("washington", "Washington D.C.", "US", "ABD", 38.9072, -77.0369),
            ("boston", "Boston", "US", "ABD", 42.3601, -71.0589),
            ("seattle", "Seattle", "US", "ABD", 47.6062, -122.3321),
            ("denver", "Denver", "US", "ABD", 39.7392, -104.9903),
            ("atlanta", "Atlanta", "US", "ABD", 33.7490, -84.3880),
            ("dallas", "Dallas", "US", "ABD", 32.7767, -96.7970),
            ("houston", "Houston", "US", "ABD", 29.7604, -95.3698),
            ("phoenix", "Phoenix", "US", "ABD", 33.4484, -112.0740),
            ("sandiego", "San Diego", "US", "ABD", 32.7157, -117.1611),
            ("neworleans", "New Orleans", "US", "ABD", 29.9511, -90.0715),
            ("nashville", "Nashville", "US", "ABD", 36.1627, -86.7816),
            ("orlando", "Orlando", "US", "ABD", 28.5383, -81.3792),
            ("hawaii", "Honolulu", "US", "ABD", 21.3069, -157.8583),
            ("toronto", "Toronto", "CA", "Kanada", 43.6532, -79.3832),
            ("vancouver", "Vancouver", "CA", "Kanada", 49.2827, -123.1207),
            ("montreal", "Montreal", "CA", "Kanada", 45.5017, -73.5673),
            ("quebec", "Quebec City", "CA", "Kanada", 46.8139, -71.2080),
            ("calgary", "Calgary", "CA", "Kanada", 51.0447, -114.0719),
            ("ottawa", "Ottawa", "CA", "Kanada", 45.4215, -75.6972),

            // Amerika - Latin Amerika
            ("mexicocity", "Mexico City", "MX", "Meksika", 19.4326, -99.1332),
            ("cancun", "Cancun", "MX", "Meksika", 21.1619, -86.8515),
            ("guadalajara", "Guadalajara", "MX", "Meksika", 20.6597, -103.3496),
            ("buenosaires", "Buenos Aires", "AR", "Arjantin", 34.6037, -58.3816),
            ("riodejaneiro", "Rio de Janeiro", "BR", "Brezilya", -22.9068, -43.1729),
            ("saopaulo", "Sao Paulo", "BR", "Brezilya", -23.5505, -46.6333),
            ("lima", "Lima", "PE", "Peru", -12.0464, -77.0428),
            ("cusco", "Cusco", "PE", "Peru", -13.5320, -71.9675),
            ("bogota", "Bogota", "CO", "Kolombiya", 4.7110, -74.0721),
            ("cartagena", "Cartagena", "CO", "Kolombiya", 10.3910, -75.4794),
            ("medellin", "Medellin", "CO", "Kolombiya", 6.2442, -75.5812),
            ("santiago", "Santiago", "CL", "Şili", -33.4489, -70.6693),
            ("havana", "Havana", "CU", "Küba", 23.1136, -82.3666),
            ("puntacana", "Punta Cana", "DO", "Dominik Cumhuriyeti", 18.5601, -68.3725),
            ("sanjuan", "San Juan", "PR", "Porto Riko", 18.4655, -66.1057),
            ("montevideo", "Montevideo", "UY", "Uruguay", -34.9011, -56.1645),
            ("quito", "Quito", "EC", "Ekvador", -0.1807, -78.4678),
            ("lapaz", "La Paz", "BO", "Bolivya", -16.5000, -68.1500),
            ("asuncion", "Asuncion", "PY", "Paraguay", -25.2637, -57.5759),
            ("caracas", "Caracas", "VE", "Venezuela", 10.4806, -66.9036),
            ("panama", "Panama City", "PA", "Panama", 8.9824, -79.5199),
            ("sanjose", "San Jose", "CR", "Kosta Rika", 9.9281, -84.0907),

            // Asya - Doğu Asya
            ("tokyo", "Tokyo", "JP", "Japonya", 35.6762, 139.6503),
            ("osaka", "Osaka", "JP", "Japonya", 34.6937, 135.5023),
            ("kyoto", "Kyoto", "JP", "Japonya", 35.0116, 135.7681),
            ("hiroshima", "Hiroşima", "JP", "Japonya", 34.3853, 132.4553),
            ("nagoya", "Nagoya", "JP", "Japonya", 35.1815, 136.9066),
            ("fukuoka", "Fukuoka", "JP", "Japonya", 33.5904, 130.4017),
            ("sapporo", "Sapporo", "JP", "Japonya", 43.0618, 141.3545),
            ("nara", "Nara", "JP", "Japonya", 34.6851, 135.8048),
            ("seoul", "Seul", "KR", "Güney Kore", 37.5665, 126.9780),
            ("busan", "Busan", "KR", "Güney Kore", 35.1796, 129.0756),
            ("jeju", "Jeju", "KR", "Güney Kore", 33.4996, 126.5312),
            ("beijing", "Pekin", "CN", "Çin", 39.9042, 116.4074),
            ("shanghai", "Şangay", "CN", "Çin", 31.2304, 121.4737),
            ("hongkong", "Hong Kong", "HK", "Hong Kong", 22.3193, 114.1694),
            ("macau", "Makao", "MO", "Makao", 22.1987, 113.5439),
            ("guangzhou", "Guangzhou", "CN", "Çin", 23.1291, 113.2644),
            ("shenzhen", "Shenzhen", "CN", "Çin", 22.5431, 114.0579),
            ("xian", "Xi'an", "CN", "Çin", 34.3416, 108.9398),
            ("chengdu", "Chengdu", "CN", "Çin", 30.5728, 104.0668),
            ("taipei", "Taipei", "TW", "Tayvan", 25.0330, 121.5654),
            ("kaohsiung", "Kaohsiung", "TW", "Tayvan", 22.6273, 120.3014),

            // Asya - Güneydoğu Asya
            ("singapore", "Singapur", "SG", "Singapur", 1.3521, 103.8198),
            ("bangkok", "Bangkok", "TH", "Tayland", 13.7563, 100.5018),
            ("phuket", "Phuket", "TH", "Tayland", 7.8804, 98.3923),
            ("chiangmai", "Chiang Mai", "TH", "Tayland", 18.7883, 98.9853),
            ("pattaya", "Pattaya", "TH", "Tayland", 12.9236, 100.8825),
            ("bali", "Bali", "ID", "Endonezya", -8.3405, 115.0920),
            ("jakarta", "Jakarta", "ID", "Endonezya", -6.2088, 106.8456),
            ("kualalumpur", "Kuala Lumpur", "MY", "Malezya", 3.1390, 101.6869),
            ("penang", "Penang", "MY", "Malezya", 5.4164, 100.3327),
            ("hanoi", "Hanoi", "VN", "Vietnam", 21.0285, 105.8542),
            ("hochiminh", "Ho Chi Minh", "VN", "Vietnam", 10.8231, 106.6297),
            ("danang", "Da Nang", "VN", "Vietnam", 16.0544, 108.2022),
            ("manila", "Manila", "PH", "Filipinler", 14.5995, 120.9842),
            ("cebu", "Cebu", "PH", "Filipinler", 10.3157, 123.8854),
            ("boracay", "Boracay", "PH", "Filipinler", 11.9674, 121.9248),
            ("siemreap", "Siem Reap", "KH", "Kamboçya", 13.3671, 103.8448),
            ("phnompenh", "Phnom Penh", "KH", "Kamboçya", 11.5564, 104.9282),
            ("vientiane", "Vientiane", "LA", "Laos", 17.9757, 102.6331),
            ("luangprabang", "Luang Prabang", "LA", "Laos", 19.8860, 102.1347),
            ("yangon", "Yangon", "MM", "Myanmar", 16.8661, 96.1951),

            // Asya - Güney Asya
            ("mumbai", "Mumbai", "IN", "Hindistan", 19.0760, 72.8777),
            ("delhi", "Delhi", "IN", "Hindistan", 28.7041, 77.1025),
            ("bangalore", "Bangalore", "IN", "Hindistan", 12.9716, 77.5946),
            ("chennai", "Chennai", "IN", "Hindistan", 13.0827, 80.2707),
            ("kolkata", "Kalküta", "IN", "Hindistan", 22.5726, 88.3639),
            ("jaipur", "Jaipur", "IN", "Hindistan", 26.9124, 75.7873),
            ("agra", "Agra", "IN", "Hindistan", 27.1767, 78.0081),
            ("goa", "Goa", "IN", "Hindistan", 15.2993, 74.1240),
            ("varanasi", "Varanasi", "IN", "Hindistan", 25.3176, 82.9739),
            ("kathmandu", "Katmandu", "NP", "Nepal", 27.7172, 85.3240),
            ("colombo", "Colombo", "LK", "Sri Lanka", 6.9271, 79.8612),
            ("dhaka", "Dakka", "BD", "Bangladeş", 23.8103, 90.4125),
            ("male", "Male", "MV", "Maldivler", 4.1755, 73.5093),

            // Asya - Orta Doğu
            ("dubai", "Dubai", "AE", "BAE", 25.2048, 55.2708),
            ("abudhabi", "Abu Dhabi", "AE", "BAE", 24.4539, 54.3773),
            ("doha", "Doha", "QA", "Katar", 25.2854, 51.5310),
            ("riyadh", "Riyad", "SA", "Suudi Arabistan", 24.7136, 46.6753),
            ("jeddah", "Cidde", "SA", "Suudi Arabistan", 21.4858, 39.1925),
            ("mecca", "Mekke", "SA", "Suudi Arabistan", 21.3891, 39.8579),
            ("medina", "Medine", "SA", "Suudi Arabistan", 24.5247, 39.5692),
            ("muscat", "Maskat", "OM", "Umman", 23.5880, 58.3829),
            ("manama", "Manama", "BH", "Bahreyn", 26.2285, 50.5860),
            ("kuwait", "Kuveyt", "KW", "Kuveyt", 29.3759, 47.9774),
            ("amman", "Amman", "JO", "Ürdün", 31.9454, 35.9284),
            ("petra", "Petra", "JO", "Ürdün", 30.3285, 35.4444),
            ("beirut", "Beyrut", "LB", "Lübnan", 33.8938, 35.5018),
            ("tehran", "Tahran", "IR", "İran", 35.6892, 51.3890),
            ("isfahan", "Isfahan", "IR", "İran", 32.6546, 51.6680),
            ("shiraz", "Şiraz", "IR", "İran", 29.5918, 52.5837),
            ("baku", "Bakü", "AZ", "Azerbaycan", 40.4093, 49.8671),
            ("tbilisi", "Tiflis", "GE", "Gürcistan", 41.7151, 44.8271),
            ("yerevan", "Erivan", "AM", "Ermenistan", 40.1792, 44.4991),
            ("jerusalem", "Kudüs", "IL", "İsrail", 31.7683, 35.2137),
            ("telaviv", "Tel Aviv", "IL", "İsrail", 32.0853, 34.7818),

            // Afrika
            ("cairo", "Kahire", "EG", "Mısır", 30.0444, 31.2357),
            ("luxor", "Luksor", "EG", "Mısır", 25.6872, 32.6396),
            ("alexandria", "İskenderiye", "EG", "Mısır", 31.2001, 29.9187),
            ("sharmelsheikh", "Şarm El Şeyh", "EG", "Mısır", 27.9158, 34.3300),
            ("marrakech", "Marakeş", "MA", "Fas", 31.6295, -7.9811),
            ("casablanca", "Kazablanka", "MA", "Fas", 33.5731, -7.5898),
            ("fes", "Fes", "MA", "Fas", 34.0181, -5.0078),
            ("tunis", "Tunus", "TN", "Tunus", 36.8065, 10.1815),
            ("algiers", "Cezayir", "DZ", "Cezayir", 36.7538, 3.0588),
            ("capetown", "Cape Town", "ZA", "Güney Afrika", -33.9249, 18.4241),
            ("johannesburg", "Johannesburg", "ZA", "Güney Afrika", -26.2041, 28.0473),
            ("durban", "Durban", "ZA", "Güney Afrika", -29.8587, 31.0218),
            ("nairobi", "Nairobi", "KE", "Kenya", -1.2921, 36.8219),
            ("mombasa", "Mombasa", "KE", "Kenya", -4.0435, 39.6682),
            ("zanzibar", "Zanzibar", "TZ", "Tanzanya", -6.1659, 39.2026),
            ("daressalaam", "Darüsselam", "TZ", "Tanzanya", -6.7924, 39.2083),
            ("lagos", "Lagos", "NG", "Nijerya", 6.5244, 3.3792),
            ("accra", "Accra", "GH", "Gana", 5.6037, -0.1870),
            ("dakar", "Dakar", "SN", "Senegal", 14.7167, -17.4677),
            ("addisababa", "Addis Ababa", "ET", "Etiyopya", 8.9806, 38.7578),
            ("kigali", "Kigali", "RW", "Ruanda", -1.9403, 29.8739),
            ("kampala", "Kampala", "UG", "Uganda", 0.3476, 32.5825),
            ("mauritius", "Port Louis", "MU", "Mauritius", -20.1609, 57.5012),
            ("seychelles", "Victoria", "SC", "Seyşeller", -4.6191, 55.4513),

            // Okyanusya
            ("sydney", "Sidney", "AU", "Avustralya", -33.8688, 151.2093),
            ("melbourne", "Melbourne", "AU", "Avustralya", -37.8136, 144.9631),
            ("brisbane", "Brisbane", "AU", "Avustralya", -27.4698, 153.0251),
            ("perth", "Perth", "AU", "Avustralya", -31.9505, 115.8605),
            ("goldcoast", "Gold Coast", "AU", "Avustralya", -28.0167, 153.4000),
            ("cairns", "Cairns", "AU", "Avustralya", -16.9186, 145.7781),
            ("adelaide", "Adelaide", "AU", "Avustralya", -34.9285, 138.6007),
            ("auckland", "Auckland", "NZ", "Yeni Zelanda", -36.8485, 174.7633),
            ("queenstown", "Queenstown", "NZ", "Yeni Zelanda", -45.0312, 168.6626),
            ("wellington", "Wellington", "NZ", "Yeni Zelanda", -41.2865, 174.7762),
            ("fiji", "Suva", "FJ", "Fiji", -18.1416, 178.4415),
            ("tahiti", "Papeete", "PF", "Fransız Polinezyası", -17.5516, -149.5585)
        ]

        return cities.map { city in
            CityData(
                id: city.id,
                name: city.name,
                countryCode: city.countryCode,
                countryName: city.countryName,
                latitude: city.lat,
                longitude: city.lng
            )
        }.sorted { $0.name < $1.name }
    }()
}

#Preview {
    WorldMapView()
}
