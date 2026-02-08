import SwiftUI

// MARK: - CreateTripView (Flight Board / Boarding Pass Concept)
struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateTripViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Flight progress tracker
                    flightProgressBar
                        .padding(.top, 8)
                        .padding(.horizontal, 20)

                    // Step content
                    TabView(selection: $viewModel.currentStep) {
                        destinationStep.tag(TripCreationStep.destination)
                        durationStep.tag(TripCreationStep.duration)
                        companionStep.tag(TripCreationStep.companion)
                        preferencesStep.tag(TripCreationStep.preferences)
                        budgetStep.tag(TripCreationStep.budget)
                        reviewStep.tag(TripCreationStep.review)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.currentStep)

                    // Bottom control bar
                    bottomBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "ticket.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.primary)
                        Text("createTrip.boardingPass".localized)
                            .font(ThemeManager.Typography.subheadlineBold)
                            .foregroundStyle(AppColors.textPrimary)
                            .tracking(1.5)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(AppColors.surface))
                    }
                }
            }
            .fullScreenCover(isPresented: $viewModel.showGenerating, onDismiss: {
                if viewModel.createdTripId != nil { dismiss() }
            }) {
                if let tripId = viewModel.createdTripId {
                    GeneratingView(tripId: tripId)
                }
            }
        }
    }

    // MARK: - Flight Progress Bar
    private var flightProgressBar: some View {
        let steps = TripCreationStep.allCases
        let currentIdx = steps.firstIndex(of: viewModel.currentStep) ?? 0

        return HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element) { idx, step in
                let isCompleted = idx < currentIdx
                let isCurrent = idx == currentIdx

                // Step node
                ZStack {
                    if isCompleted {
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.background)
                    } else if isCurrent {
                        Circle()
                            .fill(AppColors.primary.opacity(0.15))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle().stroke(AppColors.primary, lineWidth: 2)
                            )
                        Image(systemName: step.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.primary)
                    } else {
                        Circle()
                            .fill(AppColors.surface)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle().stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                        Text("\(idx + 1)")
                            .font(ThemeManager.Typography.boardHeader)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }

                // Connector line
                if idx < steps.count - 1 {
                    Rectangle()
                        .fill(idx < currentIdx ? AppColors.primary : AppColors.cardBorder)
                        .frame(height: 1.5)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        let isFirst = viewModel.currentStep == .destination
        let isLast = viewModel.currentStep == .review

        return HStack(spacing: 12) {
            // Back button
            if !isFirst {
                Button {
                    withAnimation { viewModel.previousStep() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12))
                        Text("createTrip.back".localized)
                            .font(ThemeManager.Typography.footnoteBold)
                    }
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(height: 50)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.cardBorder, lineWidth: 0.5)
                            )
                    )
                }
            }

            // Next / Generate button
            Button {
                if isLast {
                    viewModel.createTrip()
                } else {
                    withAnimation { viewModel.nextStep() }
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(AppColors.background)
                            .scaleEffect(0.8)
                    } else {
                        Text(isLast ? "createTrip.clearForTakeoff".localized : "common.next".localized)
                            .font(ThemeManager.Typography.subheadlineBold)
                            .tracking(0.5)
                        Image(systemName: isLast ? "airplane" : "chevron.right")
                            .font(.system(size: 12))
                    }
                }
                .foregroundStyle(AppColors.background)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.canProceed ? AppColors.primaryGradient : LinearGradient(colors: [AppColors.textTertiary], startPoint: .leading, endPoint: .trailing))
                )
                .shadow(color: viewModel.canProceed ? AppColors.primary.opacity(0.3) : .clear, radius: 12, y: 6)
            }
            .disabled(!viewModel.canProceed || viewModel.isLoading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(AppColors.background)
                .overlay(
                    VStack { Rectangle().fill(AppColors.cardBorder).frame(height: 0.5); Spacer() }
                )
                .ignoresSafeArea(.container, edges: .bottom)
        )
    }

    // MARK: - Step Header
    private func stepHeader(title: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.primary)
                Text(title.uppercased())
                    .font(ThemeManager.Typography.boardValue)
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(1)
            }
            Text(subtitle)
                .font(.custom("SpaceMono-Regular", size: 13))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    // MARK: - Boarding Pass Card Wrapper
    private func boardingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 0.5)
            }
        )
        .padding(.horizontal, 20)
    }

    // MARK: - ═══════════════════════════════════════
    // MARK:   STEP 1: DESTINATION
    // MARK: - ═══════════════════════════════════════

    @FocusState private var isSearchFocused: Bool
    @State private var searchText = ""
    @StateObject private var citySearch = CitySearchService()

    private var destinationStep: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                stepHeader(
                    title: "createTrip.destination".localized,
                    subtitle: "createTrip.whereSubtitle".localized,
                    icon: "mappin"
                )
                .padding(.top, 12)

                // Selected cities as boarding tags
                if !viewModel.selectedCities.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.selectedCities, id: \.self) { city in
                                HStack(spacing: 6) {
                                    Text(cityCode(city))
                                        .font(ThemeManager.Typography.footnoteBold)
                                        .foregroundStyle(AppColors.primary)
                                    Text(city)
                                        .font(.custom("SpaceMono-Bold", size: 12))
                                        .foregroundStyle(AppColors.textPrimary)
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            viewModel.selectedCities.removeAll { $0 == city }
                                        }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8))
                                            .foregroundStyle(AppColors.textTertiary)
                                            .frame(width: 18, height: 18)
                                            .background(Circle().fill(AppColors.surfaceLighter))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppColors.primary.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(isSearchFocused ? AppColors.primary : AppColors.textTertiary)
                    TextField("createTrip.destinationPlaceholder".localized, text: $searchText)
                        .font(ThemeManager.Typography.subheadline)
                        .foregroundStyle(AppColors.textPrimary)
                        .focused($isSearchFocused)
                        .onChange(of: searchText) { _, newValue in
                            citySearch.search(newValue)
                        }
                    if citySearch.isSearching {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(AppColors.primary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSearchFocused ? AppColors.primary : AppColors.cardBorder, lineWidth: isSearchFocused ? 1.5 : 0.5)
                        )
                )
                .padding(.horizontal, 20)

                // Live search results from Apple Maps
                if !citySearch.results.isEmpty || (searchText.count >= 2 && !citySearch.isSearching) {
                    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let filtered = citySearch.results.filter { !viewModel.selectedCities.contains($0.name) }
                    let alreadyAdded = viewModel.selectedCities.contains { $0.lowercased() == trimmed.lowercased() }

                    if !filtered.isEmpty || (!alreadyAdded && trimmed.count >= 2) {
                        VStack(spacing: 2) {
                            // Apple Maps results
                            ForEach(filtered) { city in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        viewModel.selectedCities.append(city.name)
                                        searchText = ""
                                        citySearch.clear()
                                        isSearchFocused = false
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(countryFlag(city.countryCode))
                                            .font(.custom("SpaceMono-Regular", size: 22))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(city.name)
                                                .font(.custom("SpaceMono-Bold", size: 14))
                                                .foregroundStyle(AppColors.textPrimary)
                                            Text(city.subtitle)
                                                .font(ThemeManager.Typography.boardCaption)
                                                .foregroundStyle(AppColors.textTertiary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(AppColors.primary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }

                            // Custom city option (always available if no exact match)
                            if !alreadyAdded && trimmed.count >= 2 && !filtered.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
                                if !filtered.isEmpty {
                                    Rectangle()
                                        .fill(AppColors.cardBorder)
                                        .frame(height: 0.5)
                                        .padding(.horizontal, 16)
                                }
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        let capitalized = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
                                        viewModel.selectedCities.append(capitalized)
                                        searchText = ""
                                        citySearch.clear()
                                        isSearchFocused = false
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Text("🌍")
                                            .font(.custom("SpaceMono-Regular", size: 22))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\"\(trimmed)\" " + "createTrip.addCustomCity".localized)
                                                .font(.custom("SpaceMono-Bold", size: 14))
                                                .foregroundStyle(AppColors.primary)
                                            Text(cityCode(trimmed))
                                                .font(ThemeManager.Typography.boardCaption)
                                                .foregroundStyle(AppColors.textTertiary)
                                        }
                                        Spacer()
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(AppColors.primary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.cardBorder, lineWidth: 0.5)
                                )
                        )
                        .padding(.horizontal, 20)
                    }
                }

                // Popular destinations grid
                if searchText.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.primary)
                            Text("createTrip.popularDestinations".localized)
                                .font(ThemeManager.Typography.boardCaption)
                                .foregroundStyle(AppColors.textTertiary)
                                .tracking(1)
                        }
                        .padding(.horizontal, 20)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ], spacing: 8) {
                            ForEach(popularCities, id: \.name) { city in
                                let isSelected = viewModel.selectedCities.contains(city.name)
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        if isSelected {
                                            viewModel.selectedCities.removeAll { $0 == city.name }
                                        } else {
                                            viewModel.selectedCities.append(city.name)
                                        }
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(countryFlag(city.code))
                                            .font(.custom("SpaceMono-Regular", size: 24))
                                        Text(cityCode(city.name))
                                            .font(ThemeManager.Typography.footnoteBold)
                                            .foregroundStyle(isSelected ? AppColors.primary : AppColors.textPrimary)
                                        Text(city.name)
                                            .font(.custom("SpaceMono-Bold", size: 10))
                                            .foregroundStyle(AppColors.textTertiary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(isSelected ? AppColors.primary.opacity(0.1) : AppColors.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(isSelected ? AppColors.primary.opacity(0.4) : AppColors.cardBorder, lineWidth: isSelected ? 1.5 : 0.5)
                                            )
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Spacer(minLength: 80)
            }
        }
    }

    // MARK: - ═══════════════════════════════════════
    // MARK:   STEP 2: DURATION
    // MARK: - ═══════════════════════════════════════

    private var durationStep: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                stepHeader(
                    title: "createTrip.duration".localized,
                    subtitle: "createTrip.durationSubtitle".localized,
                    icon: "calendar"
                )
                .padding(.top, 12)

                boardingCard {
                    VStack(spacing: 24) {
                        // Night counter
                        HStack(spacing: 24) {
                            Button {
                                if viewModel.durationNights > 1 {
                                    withAnimation(.spring(response: 0.3)) {
                                        viewModel.durationNights -= 1
                                    }
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 16))
                                    .foregroundStyle(viewModel.durationNights > 1 ? AppColors.textPrimary : AppColors.textTertiary)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        Circle()
                                            .fill(AppColors.surfaceLight)
                                            .overlay(Circle().stroke(AppColors.cardBorder, lineWidth: 0.5))
                                    )
                            }
                            .disabled(viewModel.durationNights <= 1)

                            VStack(spacing: 4) {
                                Text("\(viewModel.durationNights)")
                                    .font(ThemeManager.Typography.displayLarge)
                                    .foregroundStyle(AppColors.primary)
                                    .contentTransition(.numericText(value: Double(viewModel.durationNights)))
                                    .animation(.spring(response: 0.3), value: viewModel.durationNights)
                                Text("createTrip.night".localized)
                                    .font(ThemeManager.Typography.boardLabel)
                                    .foregroundStyle(AppColors.textTertiary)
                                    .tracking(1)
                            }
                            .frame(width: 120)

                            Button {
                                if viewModel.durationNights < 30 {
                                    withAnimation(.spring(response: 0.3)) {
                                        viewModel.durationNights += 1
                                    }
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 16))
                                    .foregroundStyle(viewModel.durationNights < 30 ? AppColors.textPrimary : AppColors.textTertiary)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        Circle()
                                            .fill(AppColors.surfaceLight)
                                            .overlay(Circle().stroke(AppColors.cardBorder, lineWidth: 0.5))
                                    )
                            }
                            .disabled(viewModel.durationNights >= 30)
                        }

                        // Quick presets
                        HStack(spacing: 8) {
                            ForEach([3, 5, 7, 10, 14], id: \.self) { nights in
                                let isActive = viewModel.durationNights == nights
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        viewModel.durationNights = nights
                                    }
                                } label: {
                                    Text("\(nights)")
                                        .font(ThemeManager.Typography.subheadlineBold)
                                        .foregroundStyle(isActive ? AppColors.background : AppColors.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 38)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(isActive ? AppColors.primary : AppColors.surfaceLight)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(isActive ? .clear : AppColors.cardBorder, lineWidth: 0.5)
                                                )
                                        )
                                }
                            }
                        }

                        perforatedDivider
                    }
                }

                // Date toggle
                boardingCard {
                    VStack(spacing: 16) {
                        Toggle(isOn: $viewModel.hasSpecificDate) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppColors.primary)
                                Text("createTrip.setDate".localized)
                                    .font(.custom("SpaceMono-Bold", size: 14))
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                        }
                        .tint(AppColors.primary)

                        if viewModel.hasSpecificDate {
                            DatePicker(
                                "createTrip.startDate".localized,
                                selection: $viewModel.startDate,
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .tint(AppColors.primary)
                        }
                    }
                }

                Spacer(minLength: 80)
            }
        }
    }

    // MARK: - ═══════════════════════════════════════
    // MARK:   STEP 3: COMPANION
    // MARK: - ═══════════════════════════════════════

    private var companionStep: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                stepHeader(
                    title: "createTrip.companion".localized,
                    subtitle: "createTrip.companionSubtitle".localized,
                    icon: "person.2"
                )
                .padding(.top, 12)

                VStack(spacing: 8) {
                    companionCard(.solo, desc: "createTrip.companionSoloDesc".localized)
                    companionCard(.friends, desc: "createTrip.companionFriendsDesc".localized)
                    companionCard(.family, desc: "createTrip.companionFamilyDesc".localized)
                    companionCard(.couple, desc: "createTrip.companionCoupleDesc".localized)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 80)
            }
        }
    }

    private func companionCard(_ type: CompanionType, desc: String) -> some View {
        let isSelected = viewModel.companion == type

        return Button {
            withAnimation(.spring(response: 0.3)) {
                viewModel.companion = type
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.primary.opacity(0.15) : AppColors.surfaceLight)
                        .frame(width: 44, height: 44)
                    Image(systemName: type.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? AppColors.primary : AppColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(type.displayName)
                        .font(.custom("SpaceMono-Bold", size: 15))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(desc)
                        .font(.custom("SpaceMono-Regular", size: 12))
                        .foregroundStyle(AppColors.textTertiary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColors.primary : AppColors.cardBorder, lineWidth: isSelected ? 2 : 1)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.primary.opacity(0.05) : AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppColors.primary.opacity(0.3) : AppColors.cardBorder, lineWidth: isSelected ? 1.5 : 0.5)
                    )
            )
        }
    }

    // MARK: - ═══════════════════════════════════════
    // MARK:   STEP 4: PREFERENCES
    // MARK: - ═══════════════════════════════════════

    private var preferencesStep: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                stepHeader(
                    title: "createTrip.interests".localized,
                    subtitle: "createTrip.preferencesSubtitle".localized,
                    icon: "slider.horizontal.3"
                )
                .padding(.top, 12)

                // Transport
                boardingCard {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel(icon: "car.fill", text: "createTrip.transport".localized)
                        chipRow(items: TransportMode.allCases.map { ($0.rawValue, $0.icon, $0.displayName) },
                                selected: viewModel.transportMode.rawValue) { raw in
                            if let mode = TransportMode(rawValue: raw) {
                                viewModel.transportMode = mode
                            }
                        }
                    }
                }

                // Pace
                boardingCard {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel(icon: "gauge.medium", text: "createTrip.pace".localized)
                        chipRow(items: PaceType.allCases.map { ($0.rawValue, paceIcon($0), $0.displayName) },
                                selected: viewModel.pace.rawValue) { raw in
                            if let pace = PaceType(rawValue: raw) {
                                viewModel.pace = pace
                            }
                        }
                    }
                }

                // Iconic preference
                boardingCard {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel(icon: "building.columns.fill", text: "createTrip.iconic".localized)
                        chipRow(items: IconicPreference.allCases.map { ($0.rawValue, iconicIcon($0), $0.displayName) },
                                selected: viewModel.iconicPreference.rawValue) { raw in
                            if let pref = IconicPreference(rawValue: raw) {
                                viewModel.iconicPreference = pref
                            }
                        }
                    }
                }

                // Must-visit
                boardingCard {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel(icon: "mappin.and.ellipse", text: "createTrip.mustVisitOptional".localized)
                        TextField("createTrip.mustVisitPlaceholder".localized, text: $viewModel.mustVisitText, axis: .vertical)
                            .font(ThemeManager.Typography.footnote)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(3...5)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppColors.background)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(AppColors.cardBorder, lineWidth: 0.5)
                                    )
                            )
                    }
                }

                Spacer(minLength: 80)
            }
        }
    }

    private func sectionLabel(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.primary)
            Text(text.uppercased())
                .font(ThemeManager.Typography.boardCaption)
                .foregroundStyle(AppColors.textSecondary)
                .tracking(0.5)
        }
    }

    private func chipRow(items: [(String, String, String)], selected: String, onSelect: @escaping (String) -> Void) -> some View {
        let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items, id: \.0) { id, icon, label in
                let isActive = selected == id
                Button {
                    withAnimation(.spring(response: 0.3)) { onSelect(id) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.system(size: 11))
                        Text(label)
                            .font(.custom(isActive ? "SpaceMono-Bold" : "SpaceMono-Regular", size: 11))
                            .lineLimit(1)
                    }
                    .foregroundStyle(isActive ? AppColors.primary : AppColors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isActive ? AppColors.primary.opacity(0.1) : AppColors.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isActive ? AppColors.primary.opacity(0.4) : AppColors.cardBorder, lineWidth: isActive ? 1.5 : 0.5)
                            )
                    )
                }
            }
        }
    }

    // MARK: - ═══════════════════════════════════════
    // MARK:   STEP 5: BUDGET
    // MARK: - ═══════════════════════════════════════

    private var budgetStep: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                stepHeader(
                    title: "createTrip.budget".localized,
                    subtitle: "createTrip.budgetSubtitle".localized,
                    icon: "creditcard"
                )
                .padding(.top, 12)

                VStack(spacing: 8) {
                    budgetCard(.budget, desc: "budget.lowDesc".localized)
                    budgetCard(.moderate, desc: "budget.mediumDesc".localized)
                    budgetCard(.luxury, desc: "budget.highDesc".localized)
                    budgetCard(.flexible, desc: "budget.anyDesc".localized)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 80)
            }
        }
    }

    private func budgetCard(_ type: BudgetType, desc: String) -> some View {
        let isSelected = viewModel.budget == type

        return Button {
            withAnimation(.spring(response: 0.3)) {
                viewModel.budget = type
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? AppColors.primary.opacity(0.15) : AppColors.surfaceLight)
                        .frame(width: 44, height: 44)
                    Image(systemName: type.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? AppColors.primary : AppColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(type.displayName)
                        .font(.custom("SpaceMono-Bold", size: 15))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(desc)
                        .font(.custom("SpaceMono-Regular", size: 12))
                        .foregroundStyle(AppColors.textTertiary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColors.primary : AppColors.cardBorder, lineWidth: isSelected ? 2 : 1)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.primary.opacity(0.05) : AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppColors.primary.opacity(0.3) : AppColors.cardBorder, lineWidth: isSelected ? 1.5 : 0.5)
                    )
            )
        }
    }

    // MARK: - ═══════════════════════════════════════
    // MARK:   STEP 6: REVIEW
    // MARK: - ═══════════════════════════════════════

    private var reviewStep: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                stepHeader(
                    title: "createTrip.summaryTitle".localized,
                    subtitle: "createTrip.summarySubtitle".localized,
                    icon: "checkmark.circle"
                )
                .padding(.top, 12)

                // Boarding pass card
                VStack(spacing: 0) {
                    // Top section: Route
                    VStack(spacing: 16) {
                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text(cityCode(viewModel.selectedCities.first ?? ""))
                                    .font(ThemeManager.Typography.title2)
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(viewModel.selectedCities.first ?? "")
                                    .font(.custom("SpaceMono-Bold", size: 11))
                                    .foregroundStyle(AppColors.textTertiary)
                            }

                            Spacer()

                            VStack(spacing: 4) {
                                Image(systemName: "airplane")
                                    .font(.system(size: 16))
                                    .foregroundStyle(AppColors.primary)
                                HStack(spacing: 2) {
                                    Circle().fill(AppColors.primary).frame(width: 3, height: 3)
                                    ForEach(0..<5, id: \.self) { _ in
                                        Circle().fill(AppColors.primary.opacity(0.3)).frame(width: 3, height: 3)
                                    }
                                    Circle().fill(AppColors.primary).frame(width: 3, height: 3)
                                }
                                Text(String(format: "createTrip.nights".localized, viewModel.durationNights))
                                    .font(ThemeManager.Typography.boardHeader)
                                    .foregroundStyle(AppColors.textTertiary)
                            }

                            Spacer()

                            VStack(spacing: 2) {
                                Text(cityCode(viewModel.selectedCities.last ?? viewModel.selectedCities.first ?? ""))
                                    .font(ThemeManager.Typography.title2)
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(viewModel.selectedCities.last ?? viewModel.selectedCities.first ?? "")
                                    .font(.custom("SpaceMono-Bold", size: 11))
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                        }

                        if viewModel.selectedCities.count > 2 {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppColors.primary)
                                Text(viewModel.selectedCities.dropFirst().dropLast().joined(separator: " · "))
                                    .font(ThemeManager.Typography.boardCaption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                    .padding(20)

                    perforatedDivider
                        .padding(.horizontal, 4)

                    // Bottom section: Details grid
                    VStack(spacing: 14) {
                        HStack(spacing: 16) {
                            reviewField(label: "createTrip.dateLabel".localized,
                                        value: viewModel.hasSpecificDate ? viewModel.startDate.formatted(date: .abbreviated, time: .omitted) : "--",
                                        icon: "calendar")
                            reviewField(label: "createTrip.travelTypeLabel".localized,
                                        value: viewModel.companion.displayName,
                                        icon: viewModel.companion.icon)
                        }

                        HStack(spacing: 16) {
                            reviewField(label: "createTrip.transport".localized,
                                        value: viewModel.transportMode.displayName,
                                        icon: viewModel.transportMode.icon)
                            reviewField(label: "createTrip.pace".localized,
                                        value: viewModel.pace.displayName,
                                        icon: paceIcon(viewModel.pace))
                        }

                        HStack(spacing: 16) {
                            reviewField(label: "createTrip.budget".localized,
                                        value: viewModel.budget.displayName,
                                        icon: viewModel.budget.icon)
                            reviewField(label: "createTrip.iconic".localized,
                                        value: viewModel.iconicPreference.displayName,
                                        icon: iconicIcon(viewModel.iconicPreference))
                        }

                        if !viewModel.mustVisitText.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("createTrip.mustVisitOptional".localized.uppercased())
                                    .font(ThemeManager.Typography.boardMicro)
                                    .foregroundStyle(AppColors.textTertiary)
                                    .tracking(0.5)
                                Text(viewModel.mustVisitText)
                                    .font(.custom("SpaceMono-Bold", size: 12))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)

                    // AI note
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.primary)
                        Text("createTrip.aiNote".localized)
                            .font(.custom("SpaceMono-Regular", size: 11))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.primary.opacity(0.05))
                    .overlay(
                        Rectangle().fill(AppColors.primary.opacity(0.15)).frame(height: 0.5),
                        alignment: .top
                    )
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppColors.cardBorder, lineWidth: 0.5)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)

                Spacer(minLength: 80)
            }
        }
    }

    private func reviewField(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(ThemeManager.Typography.boardMicro)
                .foregroundStyle(AppColors.textTertiary)
                .tracking(0.5)
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.primary)
                Text(value)
                    .font(.custom("SpaceMono-Bold", size: 13))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Shared Components

    private var perforatedDivider: some View {
        HStack(spacing: 5) {
            ForEach(0..<40, id: \.self) { _ in
                Circle()
                    .fill(AppColors.background)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 12)
        .clipped()
    }

    // MARK: - Data & Helpers

    private struct PopularCity {
        let name: String
        let code: String
    }

    /// Popular cities shown in the quick-select grid (before search)
    private let popularCities: [PopularCity] = [
        PopularCity(name: "İstanbul", code: "TR"),
        PopularCity(name: "Paris", code: "FR"),
        PopularCity(name: "Londra", code: "GB"),
        PopularCity(name: "Roma", code: "IT"),
        PopularCity(name: "Barcelona", code: "ES"),
        PopularCity(name: "Amsterdam", code: "NL"),
        PopularCity(name: "Dubai", code: "AE"),
        PopularCity(name: "Tokyo", code: "JP"),
        PopularCity(name: "New York", code: "US"),
        PopularCity(name: "Berlin", code: "DE"),
        PopularCity(name: "Prag", code: "CZ"),
        PopularCity(name: "Antalya", code: "TR"),
    ]

    private func countryFlag(_ code: String) -> String {
        let base: UInt32 = 127397
        var flag = ""
        for scalar in code.uppercased().unicodeScalars {
            if let flagScalar = Unicode.Scalar(base + scalar.value) {
                flag.append(String(flagScalar))
            }
        }
        return flag.isEmpty ? "🌍" : flag
    }

    private func cityCode(_ city: String) -> String {
        let clean = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "---" }
        let codes: [String: String] = [
            "istanbul": "IST", "İstanbul": "IST", "ankara": "ANK", "izmir": "IZM",
            "antalya": "AYT", "paris": "CDG", "london": "LHR", "londra": "LHR",
            "roma": "FCO", "rome": "FCO", "new york": "JFK", "dubai": "DXB",
            "tokyo": "TYO", "barcelona": "BCN", "amsterdam": "AMS", "berlin": "BER",
            "prag": "PRG", "prague": "PRG", "budapeşte": "BUD", "budapest": "BUD",
            "atina": "ATH", "athens": "ATH", "lizbon": "LIS", "lisbon": "LIS",
            "madrid": "MAD", "milano": "MXP", "milan": "MXP", "venedik": "VCE",
            "bodrum": "BJV", "dalaman": "DLM", "trabzon": "TZX", "kapadokya": "NAV",
            "münih": "MUC", "viyana": "VIE", "singapur": "SIN", "bangkok": "BKK",
            "bali": "DPS", "seul": "ICN", "sydney": "SYD", "miami": "MIA"
        ]
        let lowered = clean.lowercased()
        if let code = codes[lowered] { return code }
        let ascii = clean.uppercased().filter { $0.isLetter }
        return String(ascii.prefix(3)).padding(toLength: 3, withPad: "X", startingAt: 0)
    }

    private func paceIcon(_ pace: PaceType) -> String {
        switch pace {
        case .relaxed: return "tortoise.fill"
        case .moderate: return "gauge.medium"
        case .intensive: return "hare.fill"
        }
    }

    private func iconicIcon(_ pref: IconicPreference) -> String {
        switch pref {
        case .essential: return "building.columns.fill"
        case .optional: return "building.columns"
        case .avoid: return "eye.slash"
        }
    }
}

// MARK: - Trip Creation Step
enum TripCreationStep: Int, CaseIterable, Hashable {
    case destination = 0, duration = 1, companion = 2
    case preferences = 3, budget = 4, review = 5

    var title: String {
        switch self {
        case .destination: return "createTrip.stepWhere".localized
        case .duration: return "createTrip.stepWhen".localized
        case .companion: return "createTrip.stepWith".localized
        case .preferences: return "createTrip.stepPreferences".localized
        case .budget: return "createTrip.stepBudget".localized
        case .review: return "createTrip.stepSummary".localized
        }
    }

    var icon: String {
        switch self {
        case .destination: return "mappin"
        case .duration: return "calendar"
        case .companion: return "person.2"
        case .preferences: return "slider.horizontal.3"
        case .budget: return "creditcard"
        case .review: return "checkmark.circle"
        }
    }
}

// MARK: - View Model
@MainActor
class CreateTripViewModel: ObservableObject {
    @Published var currentStep: TripCreationStep = .destination
    @Published var selectedCities: [String] = []
    @Published var durationNights: Int = 3
    @Published var hasSpecificDate: Bool = false
    @Published var startDate: Date = Date().addingTimeInterval(7 * 24 * 60 * 60)
    @Published var companion: CompanionType = .solo
    @Published var transportMode: TransportMode = .mixed
    @Published var pace: PaceType = .moderate
    @Published var iconicPreference: IconicPreference = .essential
    @Published var budget: BudgetType = .moderate
    @Published var mustVisitText: String = ""
    @Published var isLoading = false
    @Published var showGenerating = false
    @Published var createdTripId: String?
    @Published var createdTrip: Trip?

    private var localUserId: String {
        if let id = UserDefaults.standard.string(forKey: "localUserId") { return id }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "localUserId")
        return newId
    }

    var canProceed: Bool {
        switch currentStep {
        case .destination: return !selectedCities.isEmpty
        case .duration: return durationNights > 0
        case .companion, .preferences, .budget: return true
        case .review: return !selectedCities.isEmpty && durationNights > 0
        }
    }

    func nextStep() {
        guard let idx = TripCreationStep.allCases.firstIndex(of: currentStep),
              idx < TripCreationStep.allCases.count - 1 else { return }
        currentStep = TripCreationStep.allCases[idx + 1]
    }

    func previousStep() {
        guard let idx = TripCreationStep.allCases.firstIndex(of: currentStep),
              idx > 0 else { return }
        currentStep = TripCreationStep.allCases[idx - 1]
    }

    func createTrip() {
        isLoading = true
        let request = TripCreateRequest(
            destinationCities: selectedCities,
            durationNights: durationNights,
            startDate: hasSpecificDate ? startDate : nil,
            arrivalTime: nil,
            departureTime: nil,
            companion: companion,
            arrivalPoint: nil,
            stayArea: .center,
            transportMode: transportMode,
            iconicPreference: iconicPreference,
            budget: budget,
            pace: pace,
            mustVisitPlaces: mustVisitText.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        )
        Task {
            do {
                let trip = try await SupabaseService.shared.createTrip(request, userId: localUserId)
                createdTripId = trip.id
                createdTrip = trip
                showGenerating = true
            } catch {
            }
            isLoading = false
        }
    }
}

#Preview { CreateTripView() }
