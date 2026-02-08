import SwiftUI

struct GeneratingView: View {
    let tripId: String
    @StateObject private var viewModel: GeneratingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showTripDetail = false

    init(tripId: String) {
        self.tripId = tripId
        _viewModel = StateObject(wrappedValue: GeneratingViewModel(tripId: tripId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background with gradient
                AppColors.heroMeshGradient
                    .ignoresSafeArea()

                if viewModel.isWaitingForEventSelection {
                    // Event Selection Mode — full screen selectable list
                    eventSelectionView
                } else {
                    // Normal generation flow
                    normalGenerationView
                }
            }
            .navigationBarBackButtonHidden(viewModel.isGenerating)
            .navigationDestination(isPresented: $showTripDetail) {
                if let trip = viewModel.completedTrip {
                    TripDetailView(trip: trip)
                }
            }
            .toolbar {
                if !viewModel.isGenerating && !viewModel.isWaitingForEventSelection {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            if viewModel.isComplete {
                                Text("common.close".localized)
                                    .foregroundStyle(AppColors.textSecondary)
                            } else {
                                Image(systemName: "xmark")
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showPaywall) {
                CreditStoreView()
            }
        }
        .task {
            await viewModel.startGeneration()
        }
    }

    // MARK: - Normal Generation View
    private var normalGenerationView: some View {
        VStack(spacing: ThemeManager.Spacing.xl) {
            Spacer()

            // Main animation
            mainAnimation

            // Status text
            statusText

            // Progress steps
            progressSteps

            // Days preview
            if !viewModel.generatedDays.isEmpty {
                daysPreview
            }

            Spacer()

            // Action button
            actionButton
        }
        .padding(ThemeManager.Spacing.lg)
    }

    // MARK: - Event Selection View
    private var eventSelectionView: some View {
        VStack(spacing: 0) {
            // Header
            eventSelectionHeader

            // Event list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: ThemeManager.Spacing.sm) {
                    // Info text
                    HStack(spacing: ThemeManager.Spacing.xs) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.primary)
                        Text("generating.selectEventsInfo".localized)
                            .font(ThemeManager.Typography.caption1)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ThemeManager.Spacing.md)
                    .padding(.top, ThemeManager.Spacing.sm)

                    // Select All / Deselect All
                    HStack {
                        Button {
                            withAnimation(ThemeManager.Animation.normal) {
                                viewModel.selectAllEvents()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                Text("generating.selectAll".localized)
                                    .font(ThemeManager.Typography.caption1Bold)
                            }
                            .foregroundStyle(AppColors.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppColors.primary.opacity(0.1))
                            .cornerRadius(ThemeManager.CornerRadius.small)
                        }

                        Button {
                            withAnimation(ThemeManager.Animation.normal) {
                                viewModel.deselectAllEvents()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "circle")
                                    .font(.system(size: 12))
                                Text("generating.deselectAll".localized)
                                    .font(ThemeManager.Typography.caption1Bold)
                            }
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppColors.surfaceLight)
                            .cornerRadius(ThemeManager.CornerRadius.small)
                        }

                        Spacer()

                        Text("\(viewModel.selectedEventIds.count)/\(viewModel.foundEvents.count)")
                            .font(ThemeManager.Typography.monoSmall)
                            .foregroundStyle(AppColors.primary)
                    }
                    .padding(.horizontal, ThemeManager.Spacing.md)
                    .padding(.top, ThemeManager.Spacing.xs)

                    // Event cards
                    ForEach(viewModel.foundEvents) { event in
                        SelectableEventCard(
                            event: event,
                            isSelected: viewModel.selectedEventIds.contains(event.id)
                        ) {
                            withAnimation(ThemeManager.Animation.normal) {
                                viewModel.toggleEvent(id: event.id)
                            }
                        }
                        .padding(.horizontal, ThemeManager.Spacing.md)
                    }
                }
                .padding(.bottom, 160) // Space for buttons
            }

            // Bottom action buttons
            eventSelectionButtons
        }
    }

    private var eventSelectionHeader: some View {
        VStack(spacing: ThemeManager.Spacing.xs) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: "music.note.list")
                    .font(.system(size: 28))
                    .foregroundStyle(AppColors.primary)
                    .symbolEffect(.pulse)
            }
            .padding(.top, ThemeManager.Spacing.lg)

            Text("generating.selectEventsTitle".localized)
                .font(ThemeManager.Typography.title2)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(String(format: "generating.selectEventsSubtitle".localized, viewModel.foundEvents.count))
                .font(ThemeManager.Typography.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ThemeManager.Spacing.xl)
        }
        .padding(.bottom, ThemeManager.Spacing.sm)
    }

    private var eventSelectionButtons: some View {
        VStack(spacing: ThemeManager.Spacing.sm) {
            // Continue with selected events
            Button {
                Task {
                    await viewModel.continueWithSelectedEvents()
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    if viewModel.selectedEventIds.isEmpty {
                        Text("generating.continueWithoutEvents".localized)
                    } else {
                        Text(String(format: "generating.continueWithEvents".localized, viewModel.selectedEventIds.count))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .primaryButton()

            // Skip events entirely
            Button {
                Task {
                    await viewModel.skipEvents()
                }
            } label: {
                Text("generating.skipEventsButton".localized)
            }
            .ghostButton()
        }
        .padding(ThemeManager.Spacing.lg)
        .background(
            LinearGradient(
                colors: [AppColors.background.opacity(0), AppColors.background],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Main Animation
    private var mainAnimation: some View {
        ZStack {
            // Outer pulsing rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(AppColors.primary.opacity(0.1), lineWidth: 2)
                    .frame(width: CGFloat(160 + index * 30), height: CGFloat(160 + index * 30))
                    .scaleEffect(viewModel.isGenerating ? 1.1 : 1.0)
                    .opacity(viewModel.isGenerating ? 0.3 : 0.1)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: viewModel.isGenerating
                    )
            }

            // Background circle
            Circle()
                .fill(AppColors.surface)
                .frame(width: 160, height: 160)

            // Progress ring
            Circle()
                .trim(from: 0, to: viewModel.progress)
                .stroke(
                    AppColors.primaryGradient,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))
                .animation(ThemeManager.Animation.springSmooth, value: viewModel.progress)

            // Inner content
            VStack(spacing: ThemeManager.Spacing.sm) {
                ZStack {
                    if viewModel.isComplete {
                        AnimatedCheckmark()
                    } else if viewModel.hasFailed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(AppColors.error)
                    } else {
                        // Animated icon based on step
                        Image(systemName: stepIcon)
                            .font(.system(size: 44))
                            .foregroundStyle(AppColors.primary)
                            .symbolEffect(.pulse, isActive: viewModel.isGenerating)
                    }
                }
                .frame(height: 60)

                if viewModel.isGenerating && !viewModel.isComplete {
                    Text("\(Int(viewModel.progress * 100))%")
                        .font(ThemeManager.Typography.monoLarge)
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
    }

    private var stepIcon: String {
        switch viewModel.currentStep {
        case .analyzing: return "magnifyingglass"
        case .weather: return "cloud.sun.fill"
        case .events: return "music.note.list"
        case .planning: return "map.fill"
        case .detailing: return "text.justify.left"
        case .finalizing: return "sparkles"
        }
    }

    // MARK: - Status Text
    private var statusText: some View {
        VStack(spacing: ThemeManager.Spacing.sm) {
            Text(viewModel.statusTitle)
                .font(ThemeManager.Typography.title1)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(viewModel.statusMessage)
                .font(ThemeManager.Typography.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(.horizontal, ThemeManager.Spacing.md)
    }

    // MARK: - Progress Steps
    private var progressSteps: some View {
        VStack(spacing: ThemeManager.Spacing.md) {
            // Step indicators
            HStack(spacing: ThemeManager.Spacing.xxs) {
                ForEach(GeneratingStep.allCases, id: \.self) { step in
                    StepIndicatorPro(
                        step: step,
                        currentStep: viewModel.currentStep,
                        isComplete: step.rawValue < viewModel.currentStep.rawValue || viewModel.isComplete
                    )

                    if step != GeneratingStep.allCases.last {
                        // Connector line
                        Rectangle()
                            .fill(step.rawValue < viewModel.currentStep.rawValue ? AppColors.success : AppColors.surfaceLight)
                            .frame(height: 2)
                    }
                }
            }
            .padding(.horizontal, ThemeManager.Spacing.md)

            // Current step label
            Text(viewModel.isComplete ? "generating.completed".localized : viewModel.currentStep.displayName)
                .font(ThemeManager.Typography.subheadlineBold)
                .foregroundStyle(viewModel.isComplete ? AppColors.success : AppColors.primary)
                .animation(ThemeManager.Animation.normal, value: viewModel.currentStep)
        }
    }

    // MARK: - Days Preview
    private var daysPreview: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
            HStack {
                Text("generating.generatedDays".localized)
                    .font(ThemeManager.Typography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Text("\(viewModel.generatedDays.count) \("generating.days".localized)")
                    .font(ThemeManager.Typography.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ThemeManager.Spacing.sm) {
                    ForEach(viewModel.generatedDays) { day in
                        DayPreviewCardPro(day: day)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .animation(ThemeManager.Animation.spring, value: viewModel.generatedDays.count)
    }

    // MARK: - Action Button
    private var actionButton: some View {
        VStack(spacing: ThemeManager.Spacing.md) {
            if viewModel.isComplete {
                Button {
                    if viewModel.completedTrip != nil {
                        showTripDetail = true
                    } else {
                        dismiss()
                    }
                } label: {
                    HStack {
                        Image(systemName: "map.fill")
                        Text("tripDetail.viewPlan".localized)
                    }
                    .frame(maxWidth: .infinity)
                }
                .primaryButton()

            } else if viewModel.hasFailed {
                Button {
                    Task {
                        await viewModel.retry()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("generating.retry".localized)
                    }
                    .frame(maxWidth: .infinity)
                }
                .primaryButton()

                Button {
                    dismiss()
                } label: {
                    Text("generating.goBack".localized)
                }
                .ghostButton()

            } else {
                // Generating state - show tips
                InfoBanner(
                    message: generationTip,
                    icon: "lightbulb.fill",
                    style: .info
                )
                .transition(.opacity)

                Button {
                    viewModel.cancel()
                    dismiss()
                } label: {
                    Text("generating.cancelGeneration".localized)
                }
                .ghostButton()
            }
        }
    }

    private var generationTip: String {
        let tips = [
            "generating.tipWeather".localized,
            "generating.tipPersonalize".localized,
            "generating.tipEvents".localized,
            "generating.tipCuisine".localized,
            "generating.tipTransport".localized,
            "generating.tipTransport".localized
        ]
        return tips[min(viewModel.currentStep.rawValue, tips.count - 1)]
    }
}

// MARK: - Selectable Event Card
struct SelectableEventCard: View {
    let event: TicketmasterEvent
    let isSelected: Bool
    let onToggle: () -> Void

    private var categoryColor: Color {
        switch event.category?.lowercased() {
        case "music": return Color(hex: "E91E63")
        case "sports": return Color(hex: "4CAF50")
        case "arts & theatre", "arts": return Color(hex: "9C27B0")
        default: return AppColors.primary
        }
    }

    private var categoryIcon: String {
        switch event.category?.lowercased() {
        case "music": return "music.mic"
        case "sports": return "sportscourt"
        case "arts & theatre", "arts": return "theatermasks"
        case "film": return "film"
        default: return "ticket"
        }
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: ThemeManager.Spacing.md) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? categoryColor : AppColors.textTertiary, lineWidth: 2)
                        .frame(width: 26, height: 26)

                    if isSelected {
                        Circle()
                            .fill(categoryColor)
                            .frame(width: 26, height: 26)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                // Event info
                VStack(alignment: .leading, spacing: 4) {
                    // Category badge
                    HStack(spacing: 4) {
                        Image(systemName: categoryIcon)
                            .font(.system(size: 9))
                        Text(event.genre ?? event.category ?? "Event")
                            .font(ThemeManager.Typography.boardMicro)
                            .lineLimit(1)
                    }
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(categoryColor.opacity(0.15))
                    )

                    // Event name
                    Text(event.name)
                        .font(ThemeManager.Typography.subheadlineBold)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Date, time & venue
                    HStack(spacing: ThemeManager.Spacing.md) {
                        if let date = event.localDate {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 9))
                                Text(event.formattedDate)
                                    .font(ThemeManager.Typography.caption1)
                            }
                            .foregroundStyle(AppColors.textSecondary)
                        }

                        if let time = event.localTime {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                Text(event.formattedTime)
                                    .font(ThemeManager.Typography.monoSmall)
                            }
                            .foregroundStyle(AppColors.accent)
                        }
                    }

                    if let venue = event.venueName {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .font(.system(size: 9))
                            Text(venue)
                                .font(ThemeManager.Typography.caption1)
                                .lineLimit(1)
                        }
                        .foregroundStyle(AppColors.textTertiary)
                    }
                }

                Spacer()

                // Price indicator if available
                if let price = event.priceRange {
                    Text(price)
                        .font(ThemeManager.Typography.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.surfaceLight)
                        .cornerRadius(ThemeManager.CornerRadius.small)
                }
            }
            .padding(ThemeManager.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                    .fill(AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                    .stroke(
                        isSelected ? categoryColor.opacity(0.5) : AppColors.cardBorder,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .shadow(color: isSelected ? categoryColor.opacity(0.1) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step Indicator Pro
struct StepIndicatorPro: View {
    let step: GeneratingStep
    let currentStep: GeneratingStep
    let isComplete: Bool

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 36, height: 36)

            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
            } else if step == currentStep {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
            } else {
                Image(systemName: step.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    private var backgroundColor: Color {
        if isComplete {
            return AppColors.success
        } else if step == currentStep {
            return AppColors.primary
        } else {
            return AppColors.surfaceLight
        }
    }
}

// MARK: - Day Preview Card Pro
struct DayPreviewCardPro: View {
    let day: TripDay

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.xs) {
            // Day badge
            HStack {
                Text("\("generating.day".localized) \(day.dayNumber)")
                    .font(ThemeManager.Typography.caption1Bold)
                    .foregroundStyle(AppColors.primary)

                Spacer()

                if let weather = day.weather {
                    HStack(spacing: 2) {
                        Image(systemName: weather.sfSymbol)
                            .font(.system(size: 10))
                        Text("\(Int(weather.temperatureMax))°")
                            .font(ThemeManager.Typography.caption2)
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
            }

            // Title
            Text(day.title ?? "")
                .font(ThemeManager.Typography.subheadlineBold)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)

            Spacer()

            // Activities count
            if let activities = day.activities {
                HStack(spacing: ThemeManager.Spacing.xxs) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 10))
                    Text("\(activities.count) \("generating.activity".localized)")
                        .font(ThemeManager.Typography.caption1)
                }
                .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(ThemeManager.Spacing.md)
        .frame(width: 140, height: 120)
        .background(AppColors.surface)
        .cornerRadius(ThemeManager.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                .stroke(AppColors.cardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Generating Step
enum GeneratingStep: Int, CaseIterable {
    case analyzing = 0
    case weather = 1
    case events = 2
    case planning = 3
    case detailing = 4
    case finalizing = 5

    var displayName: String {
        switch self {
        case .analyzing: return "generating.stepAnalyzing".localized
        case .weather: return "generating.stepWeather".localized
        case .events: return "generating.stepEvents".localized
        case .planning: return "generating.stepRoute".localized
        case .detailing: return "generating.stepDetails".localized
        case .finalizing: return "generating.stepFinishing".localized
        }
    }

    var icon: String {
        switch self {
        case .analyzing: return "magnifyingglass"
        case .weather: return "cloud.sun"
        case .events: return "music.note.list"
        case .planning: return "map"
        case .detailing: return "text.justify"
        case .finalizing: return "sparkles"
        }
    }
}

// MARK: - View Model
@MainActor
class GeneratingViewModel: ObservableObject {
    let tripId: String

    @Published var isGenerating = false
    @Published var isComplete = false
    @Published var hasFailed = false
    @Published var progress: CGFloat = 0
    @Published var currentStep: GeneratingStep = .analyzing
    @Published var generatedDays: [TripDay] = []
    @Published var errorMessage: String?
    @Published var completedTrip: Trip?
    @Published var foundEvents: [TicketmasterEvent] = []

    // Event selection state
    @Published var selectedEventIds: Set<String> = []
    @Published var isWaitingForEventSelection = false

    // Stored trip for continuing after event selection
    private var fetchedTrip: Trip?

    var statusTitle: String {
        if isComplete {
            return "generating.readyTitle".localized
        } else if hasFailed {
            return "generating.errorTitle".localized
        } else {
            return "generating.creatingPlan".localized
        }
    }

    var statusMessage: String {
        if isComplete {
            if !foundEvents.isEmpty && !selectedEventIds.isEmpty {
                return String(format: "generating.readyWithEvents".localized, selectedEventIds.count)
            }
            return "generating.readySubtitle".localized
        } else if hasFailed {
            return errorMessage ?? "generating.errorMessage".localized
        } else {
            return "generating.aiPreparing".localized
        }
    }

    private var generationTask: Task<Void, Never>?
    private var continuation: CheckedContinuation<Void, Never>?

    init(tripId: String) {
        self.tripId = tripId
    }

    // MARK: - Event Selection Methods

    func toggleEvent(id: String) {
        if selectedEventIds.contains(id) {
            selectedEventIds.remove(id)
        } else {
            selectedEventIds.insert(id)
        }
    }

    func selectAllEvents() {
        selectedEventIds = Set(foundEvents.map { $0.id })
    }

    func deselectAllEvents() {
        selectedEventIds.removeAll()
    }

    /// Continue generation with only the selected events
    func continueWithSelectedEvents() async {
        let selectedEvents = foundEvents.filter { selectedEventIds.contains($0.id) }
        isWaitingForEventSelection = false
        isGenerating = true
        await continueGeneration(with: selectedEvents)
    }

    /// Skip all events and continue without them
    func skipEvents() async {
        isWaitingForEventSelection = false
        isGenerating = true
        await continueGeneration(with: [])
    }

    // MARK: - Generation Flow

    @Published var showPaywall = false
    @Published var insufficientCredits = false

    func startGeneration() async {
        isGenerating = true
        progress = 0
        currentStep = .analyzing

        generationTask = Task {
            do {
                // Step 0: Kredi/Premium kontrolü (Apple Sign In → UserManager)
                guard let userId = UserManager.shared.userId else {
                    await MainActor.run {
                        hasFailed = true
                        errorMessage = "generating.authRequired".localized
                        isGenerating = false
                    }
                    return
                }

                let spendResult = await CreditManager.shared.spendCredit(userId: userId, tripId: tripId)
                if !spendResult.success {
                    await MainActor.run {
                        insufficientCredits = true
                        showPaywall = true
                        isGenerating = false
                    }
                    return
                }

                // Step 1: Fetch trip from Supabase
                await updateProgress(to: 0.08, step: .analyzing)
                try await Task.sleep(nanoseconds: 500_000_000)
                let trip = try await SupabaseService.shared.fetchTrip(id: tripId)
                self.fetchedTrip = trip

                // Update status to generating
                try await SupabaseService.shared.updateTrip(id: tripId, updates: [
                    "status": .string(TripStatus.generating.rawValue)
                ])

                // Step 2: Fetch weather
                await updateProgress(to: 0.16, step: .weather)
                try await Task.sleep(nanoseconds: 300_000_000)

                // Step 3: Fetch events from Ticketmaster
                await updateProgress(to: 0.25, step: .events)
                var events: [TicketmasterEvent] = []
                do {
                    events = try await TicketmasterService.shared.fetchEventsForTrip(
                        cities: trip.destinationCities,
                        startDate: trip.startDate,
                        durationNights: trip.durationNights
                    )
                    await MainActor.run {
                        foundEvents = events
                    }
                } catch {
                }

                // If events found → PAUSE and show selection UI
                if !events.isEmpty {
                    await MainActor.run {
                        // Pre-select all events by default
                        selectedEventIds = Set(events.map { $0.id })
                        isWaitingForEventSelection = true
                        isGenerating = false
                    }
                    // Stop here — user will call continueWithSelectedEvents() or skipEvents()
                    return
                }

                // No events found → continue directly
                await continueGeneration(with: [])

            } catch {
                await MainActor.run {
                    hasFailed = true
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }

        await generationTask?.value
    }

    /// Continue generation after event selection (or if no events found)
    private func continueGeneration(with selectedEvents: [TicketmasterEvent]) async {
        guard let trip = fetchedTrip else {
            hasFailed = true
            errorMessage = "Trip data not found"
            isGenerating = false
            return
        }

        do {
            // Step 4: Generate itinerary with Claude + Weather + Selected Events
            await updateProgress(to: 0.4, step: .planning)
            let days = try await ClaudeService.shared.generateItinerary(for: trip, events: selectedEvents)

            // Step 5: Process and add days with animation
            await updateProgress(to: 0.65, step: .detailing)
            for (index, day) in days.enumerated() {
                try await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run {
                    withAnimation(ThemeManager.Animation.spring) {
                        generatedDays.append(day)
                    }
                    progress = 0.65 + (CGFloat(index + 1) / CGFloat(days.count)) * 0.2
                }
            }

            // Step 6: Finalize - Save to Supabase
            await updateProgress(to: 0.92, step: .finalizing)

            // Save generated days to Supabase
            try await SupabaseService.shared.saveTripDays(tripId: tripId, days: days)

            // Update trip status to completed
            try await SupabaseService.shared.updateTrip(id: tripId, updates: [
                "status": .string(TripStatus.completed.rawValue),
                "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
            ])

            // Fetch the completed trip for navigation
            let finalTrip = try await SupabaseService.shared.fetchTrip(id: tripId)

            // Complete
            await MainActor.run {
                withAnimation(ThemeManager.Animation.spring) {
                    progress = 1.0
                    isComplete = true
                    isGenerating = false
                    completedTrip = finalTrip
                }
            }

        } catch {
            // Update trip status to failed
            try? await SupabaseService.shared.updateTrip(id: tripId, updates: [
                "status": .string(TripStatus.failed.rawValue),
                "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
            ])
            await MainActor.run {
                hasFailed = true
                errorMessage = error.localizedDescription
                isGenerating = false
            }
        }
    }

    private func updateProgress(to value: CGFloat, step: GeneratingStep) async {
        await MainActor.run {
            withAnimation(ThemeManager.Animation.normal) {
                progress = value
                currentStep = step
            }
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        isGenerating = false
    }

    func retry() async {
        hasFailed = false
        errorMessage = nil
        generatedDays = []
        foundEvents = []
        selectedEventIds = []
        isWaitingForEventSelection = false
        await startGeneration()
    }

    func cancel() {
        generationTask?.cancel()
        isGenerating = false
    }
}

#Preview {
    NavigationStack {
        GeneratingView(tripId: "test-trip-id")
    }
    .preferredColorScheme(.dark)
}
