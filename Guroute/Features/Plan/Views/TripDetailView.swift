import SwiftUI
import MapKit

struct TripDetailView: View {
    let trip: Trip
    @StateObject private var viewModel: TripDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDay: Int = 1
    @State private var showShareSheet = false
    @State private var showRevisionSheet = false
    @State private var showDeleteConfirmation = false

    init(trip: Trip) {
        self.trip = trip
        _viewModel = StateObject(wrappedValue: TripDetailViewModel(trip: trip))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                headerSection

                // Day selector
                daySelector

                // Day content
                if let selectedTripDay = viewModel.days.first(where: { $0.dayNumber == selectedDay }) {
                    dayContent(selectedTripDay)
                }
            }
        }
        .background(AppColors.background)
        .navigationTitle(trip.title ?? trip.destinationCities.first ?? "tab.trips".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("tripDetail.share".localized, systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showRevisionSheet = true
                    } label: {
                        Label("tripDetail.revise".localized, systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("common.delete".localized, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
        .sheet(isPresented: $showRevisionSheet) {
            RevisionSheet(tripId: trip.id) {
                // Reload data after revision
                Task {
                    await viewModel.reloadDays()
                }
            }
        }
        .confirmationDialog("tripDetail.deleteConfirmTitle".localized, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("common.delete".localized, role: .destructive) {
                Task {
                    await viewModel.deleteTrip()
                }
            }
            Button("common.cancel".localized, role: .cancel) {}
        } message: {
            Text("tripDetail.deleteConfirmMessage".localized)
        }
        .onChange(of: viewModel.isDeleted) { _, isDeleted in
            if isDeleted {
                dismiss()
            }
        }
        .task {
            await viewModel.loadDetails()
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: ThemeManager.Spacing.md) {
            // Destination info
            HStack {
                VStack(alignment: .leading, spacing: ThemeManager.Spacing.xxs) {
                    Text(trip.destinationCities.joined(separator: " → "))
                        .font(ThemeManager.Typography.title2)
                        .foregroundStyle(AppColors.textPrimary)

                    HStack(spacing: ThemeManager.Spacing.md) {
                        Label(String(format: "createTrip.nights".localized, trip.durationNights), systemImage: "moon.fill")
                        Label(trip.companion.displayName, systemImage: trip.companion.icon)
                    }
                    .font(ThemeManager.Typography.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                // Status badge
                StatusBadge(status: trip.status)
            }

            // Date & Weather
            if let startDate = trip.startDate {
                HStack {
                    VStack(alignment: .leading) {
                        Text("tripDetail.start".localized)
                            .font(ThemeManager.Typography.caption1)
                            .foregroundStyle(AppColors.textTertiary)
                        Text(startDate.formatted(style: .dayMonthYear))
                            .font(ThemeManager.Typography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    Spacer()

                    if let weather = viewModel.weather.first {
                        VStack(alignment: .trailing) {
                            Image(systemName: weather.conditionIcon)
                                .foregroundStyle(AppColors.primary)
                            Text(weather.temperatureRangeFormatted)
                                .font(ThemeManager.Typography.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
                .padding(ThemeManager.Spacing.md)
                .cardStyle()
            }

            // Quick stats
            HStack(spacing: ThemeManager.Spacing.md) {
                QuickStat(icon: "figure.walk", value: "\(viewModel.totalActivities)", label: "tripDetail.activityLabel".localized)
                QuickStat(icon: "clock", value: estimatedDuration, label: "tripDetail.estimatedDuration".localized)
                QuickStat(icon: viewModel.trip.budget.icon, value: viewModel.trip.budget.displayName, label: "createTrip.budget".localized)
            }
        }
        .padding(ThemeManager.Spacing.md)
    }

    // MARK: - Day Selector
    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ThemeManager.Spacing.sm) {
                ForEach(viewModel.days) { day in
                    DayTab(
                        day: day,
                        isSelected: selectedDay == day.dayNumber,
                        weather: viewModel.weather.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day.date ?? Date()) })
                    ) {
                        selectedDay = day.dayNumber
                    }
                }
            }
            .padding(.horizontal, ThemeManager.Spacing.md)
        }
        .padding(.vertical, ThemeManager.Spacing.sm)
        .background(AppColors.surface)
    }

    // MARK: - Day Content
    private func dayContent(_ day: TripDay) -> some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.md) {
            // Day title
            if let title = day.title {
                Text(title)
                    .font(ThemeManager.Typography.title3)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, ThemeManager.Spacing.md)
                    .padding(.top, ThemeManager.Spacing.md)
            }

            // Activities sorted by start time
            if let activities = day.activities?.sorted(by: { ($0.startTime ?? "99:99") < ($1.startTime ?? "99:99") }) {
                ForEach(activities) { activity in
                    ActivityCard(activity: activity) {
                        viewModel.toggleActivityCompletion(activity)
                    }
                }
            }
        }
        .padding(.bottom, ThemeManager.Spacing.xxl)
    }

    private var estimatedDuration: String {
        let hours = viewModel.totalActivities * 2 // Rough estimate
        if hours < 10 {
            return "\(hours) \("tripDetail.hours".localized)"
        }
        return "\(hours / 8) \("generating.days".localized)"
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: TripStatus

    var body: some View {
        Text(status.displayName)
            .font(ThemeManager.Typography.caption1)
            .padding(.horizontal, ThemeManager.Spacing.sm)
            .padding(.vertical, ThemeManager.Spacing.xxs)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .cornerRadius(ThemeManager.CornerRadius.small)
    }

    private var statusColor: Color {
        switch status {
        case .completed: return AppColors.success
        case .generating: return AppColors.warning
        case .failed: return AppColors.error
        case .draft: return AppColors.textSecondary
        }
    }
}

// MARK: - Quick Stat

struct QuickStat: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: ThemeManager.Spacing.xxs) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.primary)
            Text(value)
                .font(ThemeManager.Typography.headline)
                .foregroundStyle(AppColors.textPrimary)
            Text(label)
                .font(ThemeManager.Typography.caption2)
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(ThemeManager.Spacing.sm)
        .cardStyle()
    }
}

// MARK: - Day Tab

struct DayTab: View {
    let day: TripDay
    let isSelected: Bool
    let weather: DailyForecast?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: ThemeManager.Spacing.xxs) {
                Text(String(format: "tripDetail.day".localized, day.dayNumber))
                    .font(ThemeManager.Typography.caption1)
                    .foregroundStyle(isSelected ? AppColors.primary : AppColors.textTertiary)

                if let date = day.date {
                    Text(date.formatted(style: .dayMonth))
                        .font(ThemeManager.Typography.subheadline)
                        .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                }

                if let weather = weather {
                    Image(systemName: weather.conditionIcon)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, ThemeManager.Spacing.md)
            .padding(.vertical, ThemeManager.Spacing.sm)
            .background(isSelected ? AppColors.primary.opacity(0.1) : .clear)
            .cornerRadius(ThemeManager.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.small)
                    .stroke(isSelected ? AppColors.primary : .clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Activity Card

struct ActivityCard: View {
    let activity: TripActivity
    let onToggleCompletion: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
            // Main row
            HStack(alignment: .top, spacing: ThemeManager.Spacing.sm) {
                // Time badge on the left
                if let timeRange = activity.timeRangeDisplay {
                    VStack(spacing: 2) {
                        Text(activity.startTime ?? "")
                            .font(ThemeManager.Typography.caption1.bold())
                            .foregroundStyle(AppColors.primary)
                        if activity.endTime != nil {
                            Text(activity.endTime ?? "")
                                .font(ThemeManager.Typography.caption2)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                    .frame(width: 45)
                    .padding(.vertical, ThemeManager.Spacing.xs)
                    .background(AppColors.primary.opacity(0.1))
                    .cornerRadius(ThemeManager.CornerRadius.small)
                } else {
                    // Fallback: Completion checkbox
                    Button(action: onToggleCompletion) {
                        Image(systemName: activity.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(activity.isCompleted ? AppColors.success : AppColors.textTertiary)
                            .font(.title3)
                    }
                    .frame(width: 45)
                }

                // Content
                VStack(alignment: .leading, spacing: ThemeManager.Spacing.xxs) {
                    HStack {
                        Text(activity.name)
                            .font(ThemeManager.Typography.headline)
                            .foregroundStyle(activity.isCompleted ? AppColors.textTertiary : AppColors.textPrimary)
                            .strikethrough(activity.isCompleted)

                        Spacer()

                        // Completion indicator
                        Button(action: onToggleCompletion) {
                            Image(systemName: activity.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(activity.isCompleted ? AppColors.success : AppColors.textTertiary)
                                .font(.body)
                        }
                    }

                    if let address = activity.address {
                        HStack(spacing: ThemeManager.Spacing.xxs) {
                            Image(systemName: "mappin")
                                .font(.caption2)
                            Text(address)
                                .font(ThemeManager.Typography.caption1)
                                .lineLimit(1)
                        }
                        .foregroundStyle(AppColors.textSecondary)
                    }

                    HStack(spacing: ThemeManager.Spacing.md) {
                        if let duration = activity.duration {
                            HStack(spacing: ThemeManager.Spacing.xxs) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text("\(duration) dk")
                                    .font(ThemeManager.Typography.caption1)
                            }
                            .foregroundStyle(AppColors.textTertiary)
                        }

                        // Slot indicator
                        HStack(spacing: ThemeManager.Spacing.xxs) {
                            Image(systemName: activity.slot.icon)
                                .font(.caption2)
                            Text(activity.slot.displayName)
                                .font(ThemeManager.Typography.caption1)
                        }
                        .foregroundStyle(AppColors.textTertiary)
                    }
                }

                // Expand button
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
                    if let description = activity.description {
                        Text(description)
                            .font(ThemeManager.Typography.body)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    if let tips = activity.tips {
                        HStack(alignment: .top, spacing: ThemeManager.Spacing.xs) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(AppColors.warning)
                            Text(tips)
                                .font(ThemeManager.Typography.caption1)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(ThemeManager.Spacing.sm)
                        .background(AppColors.warning.opacity(0.1))
                        .cornerRadius(ThemeManager.CornerRadius.small)
                    }

                    if let cost = activity.cost {
                        HStack {
                            Image(systemName: "creditcard")
                                .foregroundStyle(AppColors.primary)
                            Text(cost)
                                .font(ThemeManager.Typography.subheadline)
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }

                    // Map button
                    if activity.latitude != nil && activity.longitude != nil {
                        Button {
                            openInMaps()
                        } label: {
                            Label("tripDetail.showOnMap".localized, systemImage: "map")
                                .font(ThemeManager.Typography.subheadline)
                        }
                        .foregroundStyle(AppColors.primary)
                    }
                }
                .padding(.leading, 36) // Align with text after checkbox
            }
        }
        .padding(ThemeManager.Spacing.md)
        .background(AppColors.surface)
        .cornerRadius(ThemeManager.CornerRadius.medium)
        .padding(.horizontal, ThemeManager.Spacing.md)
    }

    private func openInMaps() {
        guard let lat = activity.latitude, let lng = activity.longitude else { return }
        let url = URL(string: "maps://?q=\(activity.name)&ll=\(lat),\(lng)")!
        UIApplication.shared.open(url)
    }
}

// MARK: - Revision Sheet

struct RevisionSheet: View {
    let tripId: String
    let onRevisionComplete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRevision: RevisionType = .alternative
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(tripId: String, onRevisionComplete: (() -> Void)? = nil) {
        self.tripId = tripId
        self.onRevisionComplete = onRevisionComplete
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ThemeManager.Spacing.lg) {
                Text("tripDetail.revisionPrompt".localized)
                    .font(ThemeManager.Typography.title3)
                    .foregroundStyle(AppColors.textPrimary)

                VStack(spacing: ThemeManager.Spacing.md) {
                    RevisionOption(
                        icon: "hare.fill",
                        title: "tripDetail.moreIntensive".localized,
                        description: "tripDetail.moreIntensiveDesc".localized,
                        isSelected: selectedRevision == .heavier
                    ) {
                        selectedRevision = .heavier
                    }
                    .disabled(isLoading)

                    RevisionOption(
                        icon: "tortoise.fill",
                        title: "tripDetail.lighter".localized,
                        description: "tripDetail.lighterDesc".localized,
                        isSelected: selectedRevision == .lighter
                    ) {
                        selectedRevision = .lighter
                    }
                    .disabled(isLoading)

                    RevisionOption(
                        icon: "arrow.triangle.2.circlepath",
                        title: "tripDetail.alternative".localized,
                        description: "tripDetail.alternativeDesc".localized,
                        isSelected: selectedRevision == .alternative
                    ) {
                        selectedRevision = .alternative
                    }
                    .disabled(isLoading)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(ThemeManager.Typography.caption1)
                        .foregroundStyle(AppColors.error)
                        .padding()
                }

                Spacer()

                Button {
                    Task {
                        await startRevision()
                    }
                } label: {
                    if isLoading {
                        HStack {
                            ProgressView()
                                .tint(.white)
                            Text("tripDetail.revising".localized)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("tripDetail.revise".localized)
                            .frame(maxWidth: .infinity)
                    }
                }
                .primaryButton()
                .disabled(isLoading)
            }
            .padding(ThemeManager.Spacing.lg)
            .background(AppColors.background)
            .navigationTitle("tripDetail.revisionTitle".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .disabled(isLoading)
                    .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private func startRevision() async {
        isLoading = true
        errorMessage = nil

        do {
            // 1. Fetch the trip from Supabase
            let trip = try await SupabaseService.shared.fetchTrip(id: tripId)

            // 2. Call Claude to revise the plan
            let revisedDays = try await ClaudeService.shared.revisePlan(trip: trip, revisionType: selectedRevision)

            // 3. Save the revised days to Supabase
            try await SupabaseService.shared.saveTripDays(tripId: tripId, days: revisedDays)

            // 4. Dismiss and notify parent
            await MainActor.run {
                isLoading = false
                onRevisionComplete?()
                dismiss()
            }

        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = String(format: "tripDetail.revisionFailed".localized, error.localizedDescription)
            }
        }
    }
}

struct RevisionOption: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? AppColors.primary : AppColors.textSecondary)
                    .frame(width: 40)

                VStack(alignment: .leading) {
                    Text(title)
                        .font(ThemeManager.Typography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(description)
                        .font(ThemeManager.Typography.caption1)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppColors.primary : AppColors.textTertiary)
            }
            .padding(ThemeManager.Spacing.md)
            .background(isSelected ? AppColors.primary.opacity(0.1) : AppColors.surface)
            .cornerRadius(ThemeManager.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.medium)
                    .stroke(isSelected ? AppColors.primary : AppColors.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

// MARK: - View Model

@MainActor
class TripDetailViewModel: ObservableObject {
    let trip: Trip

    @Published var days: [TripDay] = []
    @Published var weather: [DailyForecast] = []
    @Published var isLoading = false

    var totalActivities: Int {
        days.reduce(0) { $0 + ($1.activities?.count ?? 0) }
    }

    init(trip: Trip) {
        self.trip = trip
        self.days = trip.days ?? []
    }

    func loadDetails() async {
        isLoading = true
        defer { isLoading = false }

        // Fetch days from Supabase if not already loaded
        if days.isEmpty {
            do {
                let fetchedDays = try await SupabaseService.shared.fetchTripDays(tripId: trip.id)
                await MainActor.run {
                    self.days = fetchedDays
                }
            } catch {
            }
        }

        // Load weather forecast
        do {
            if let destination = trip.destinationCities.first {
                weather = try await WeatherService.shared.getForecast(city: destination, days: trip.durationNights + 1)
            }
        } catch {
        }
    }

    func reloadDays() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedDays = try await SupabaseService.shared.fetchTripDays(tripId: trip.id)
            self.days = fetchedDays
        } catch {
        }
    }

    func toggleActivityCompletion(_ activity: TripActivity) {
        guard let dayIndex = days.firstIndex(where: { $0.activities?.contains(where: { $0.id == activity.id }) ?? false }),
              let activityIndex = days[dayIndex].activities?.firstIndex(where: { $0.id == activity.id }) else {
            return
        }

        days[dayIndex].activities?[activityIndex].isCompleted.toggle()
        saveLocalChanges()
    }

    @Published var isDeleted = false

    func deleteTrip() async {
        do {
            // Delete from Supabase
            try await SupabaseService.shared.deleteTrip(id: trip.id)
            await MainActor.run {
                isDeleted = true
            }
        } catch {
        }
    }

    private func saveLocalChanges() {
        // Local changes are saved to Supabase via viewModel
    }
}

#Preview {
    NavigationStack {
        TripDetailView(trip: Trip(
            id: "1",
            userId: "user1",
            destinationCities: ["Paris", "Roma"],
            durationNights: 5,
            startDate: Date(),
            arrivalTime: nil,
            departureTime: nil,
            companion: .couple,
            arrivalPoint: nil,
            stayArea: .center,
            transportMode: .mixed,
            iconicPreference: .essential,
            budget: .moderate,
            pace: .moderate,
            mustVisitPlaces: [],
            title: "Avrupa Turu",
            status: .completed,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
