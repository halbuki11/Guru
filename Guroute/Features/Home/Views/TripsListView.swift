import SwiftUI

// MARK: - TripsListView (Flight Board Concept)
struct TripsListView: View {
    @StateObject private var viewModel = TripsListViewModel()
    @State private var selectedFilter: TripFilter = .all
    @State private var showCreateTrip = false
    @State private var tripToDelete: Trip?
    @State private var showDeleteAlert = false
    @State private var appeared = false
    @State private var countdownNow = Date()

    private let screenW = UIScreen.main.bounds.width
    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                // Subtle scan-line texture
                scanLines

                if viewModel.isLoading && viewModel.trips.isEmpty {
                    skeletonLoading
                } else if viewModel.trips.isEmpty {
                    emptyState
                } else {
                    mainContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.primary)
                        Text("myTrips.departures".localized)
                            .font(ThemeManager.Typography.boardToolbar)
                            .foregroundStyle(AppColors.textPrimary)
                            .tracking(2)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreateTrip = true } label: {
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
            }
            .sheet(isPresented: $showCreateTrip) {
                CreateTripView()
            }
            .alert("myTrips.deleteConfirm".localized, isPresented: $showDeleteAlert) {
                Button("common.cancel".localized, role: .cancel) {}
                Button("common.delete".localized, role: .destructive) {
                    if let trip = tripToDelete {
                        Task { await viewModel.deleteTrip(trip) }
                    }
                }
            } message: {
                Text("myTrips.deleteMessage".localized)
            }
        }
        .task {
            await viewModel.loadTrips()
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) {
                appeared = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await viewModel.loadTrips() }
        }
        .onChange(of: showCreateTrip) { _, isShowing in
            if !isShowing {
                // Sheet dismissed — refresh trips list
                Task { await viewModel.loadTrips() }
            }
        }
        .onReceive(countdownTimer) { _ in
            countdownNow = Date()
        }
    }

    // MARK: - Scan Lines Background
    private var scanLines: some View {
        Canvas { context, size in
            for y in stride(from: 0, to: size.height, by: 3) {
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(.white.opacity(0.008))
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Main Content
    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Countdown hero for next trip
                if let nextTrip = viewModel.nextUpcomingTrip {
                    countdownHero(nextTrip)
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                }

                // Board info strip
                boardInfoStrip
                    .padding(.top, 20)

                // Filter tabs
                filterBar
                    .padding(.top, 16)

                // Column headers
                columnHeaders
                    .padding(.top, 18)
                    .padding(.horizontal, 16)

                // Trips board
                tripsBoard
                    .padding(.top, 4)
                    .padding(.bottom, 100)
            }
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Countdown Hero
    private func countdownHero(_ trip: Trip) -> some View {
        NavigationLink(destination: TripDetailView(trip: trip)) {
            VStack(spacing: 16) {
                // "NEXT DEPARTURE" label
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 6, height: 6)
                        .overlay(
                            Circle()
                                .fill(AppColors.success.opacity(0.4))
                                .frame(width: 14, height: 14)
                                .opacity(appeared ? 0 : 1)
                                .scaleEffect(appeared ? 2.5 : 1)
                                .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: appeared)
                        )
                    Text("myTrips.nextDeparture".localized)
                        .font(ThemeManager.Typography.boardCaption)
                        .foregroundStyle(AppColors.success)
                        .tracking(1.5)
                }

                // Destination
                HStack(spacing: 10) {
                    VStack(spacing: 2) {
                        Text(cityCode(trip.destinationCities.first ?? ""))
                            .font(ThemeManager.Typography.boardTitle)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(trip.destinationCities.first ?? "")
                            .font(ThemeManager.Typography.boardHeader)
                            .foregroundStyle(AppColors.textTertiary)
                            .lineLimit(1)
                    }

                    if trip.destinationCities.count > 1 {
                        // Flight path indicator
                        HStack(spacing: 4) {
                            dashedLine
                            Image(systemName: "airplane")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.primary)
                            dashedLine
                        }
                        .frame(maxWidth: 80)

                        VStack(spacing: 2) {
                            Text(cityCode(trip.destinationCities.last ?? ""))
                                .font(ThemeManager.Typography.boardTitle)
                                .foregroundStyle(AppColors.textPrimary)
                            Text(trip.destinationCities.last ?? "")
                                .font(ThemeManager.Typography.boardHeader)
                                .foregroundStyle(AppColors.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    if trip.destinationCities.count > 2 {
                        Text("+\(trip.destinationCities.count - 2)")
                            .font(ThemeManager.Typography.boardLabel)
                            .foregroundStyle(AppColors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(AppColors.primary.opacity(0.12))
                            )
                    }
                }

                // Countdown boxes
                if let startDate = trip.startDate {
                    let components = countdownComponents(to: startDate)
                    HStack(spacing: 8) {
                        countdownBox(value: components.days, label: "myTrips.countDays".localized)
                        countdownSeparator
                        countdownBox(value: components.hours, label: "myTrips.countHours".localized)
                        countdownSeparator
                        countdownBox(value: components.minutes, label: "myTrips.countMins".localized)
                        countdownSeparator
                        countdownBox(value: components.seconds, label: "myTrips.countSecs".localized)
                    }
                }

                // Trip info pills
                HStack(spacing: 10) {
                    boardPill(icon: "calendar", text: trip.startDate?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                    boardPill(icon: "moon.fill", text: String(format: "createTrip.nights".localized, trip.durationNights))
                    boardPill(icon: trip.companion.icon, text: trip.companion.displayName)
                }
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppColors.surface)
                    // Subtle radar sweep effect
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            RadialGradient(
                                colors: [AppColors.primary.opacity(0.06), .clear],
                                center: .topTrailing,
                                startRadius: 0,
                                endRadius: 250
                            )
                        )
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppColors.cardBorder, lineWidth: 0.5)
                }
            )
            .shadow(color: AppColors.primary.opacity(0.08), radius: 20, y: 10)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var dashedLine: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .foregroundStyle(AppColors.textTertiary.opacity(0.4))
        }
        .frame(height: 1)
    }

    private func countdownBox(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", max(value, 0)))
                .font(ThemeManager.Typography.boardDisplay)
                .foregroundStyle(AppColors.primary)
                .contentTransition(.numericText(value: Double(value)))
                .animation(.spring(response: 0.4), value: value)
            Text(label)
                .font(ThemeManager.Typography.boardMicro)
                .foregroundStyle(AppColors.textTertiary)
                .tracking(1)
        }
        .frame(width: 70)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.primary.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var countdownSeparator: some View {
        VStack(spacing: 6) {
            Circle().fill(AppColors.primary.opacity(0.5)).frame(width: 4, height: 4)
            Circle().fill(AppColors.primary.opacity(0.5)).frame(width: 4, height: 4)
        }
        .offset(y: -8)
    }

    private func boardPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(ThemeManager.Typography.boardHeader)
        }
        .foregroundStyle(AppColors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(AppColors.background.opacity(0.6))
                .overlay(Capsule().stroke(AppColors.cardBorder, lineWidth: 0.5))
        )
    }

    // MARK: - Board Info Strip
    private var boardInfoStrip: some View {
        HStack(spacing: 0) {
            boardStatItem(
                value: "\(viewModel.trips.count)",
                label: "myTrips.statsTotal".localized,
                icon: "airplane.circle.fill"
            )
            Divider()
                .frame(height: 28)
                .background(AppColors.cardBorder)
            boardStatItem(
                value: "\(viewModel.upcomingCount)",
                label: "myTrips.statsUpcoming".localized,
                icon: "clock.fill"
            )
            Divider()
                .frame(height: 28)
                .background(AppColors.cardBorder)
            boardStatItem(
                value: "\(viewModel.completedCount)",
                label: "myTrips.statsCompleted".localized,
                icon: "checkmark.seal.fill"
            )
        }
        .padding(.vertical, 14)
        .background(
            Rectangle()
                .fill(AppColors.surface.opacity(0.7))
                .overlay(
                    VStack(spacing: 0) {
                        Rectangle().fill(AppColors.cardBorder).frame(height: 0.5)
                        Spacer()
                        Rectangle().fill(AppColors.cardBorder).frame(height: 0.5)
                    }
                )
        )
        .opacity(appeared ? 1 : 0)
    }

    private func boardStatItem(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.primary)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(ThemeManager.Typography.boardValue)
                    .foregroundStyle(AppColors.textPrimary)
                Text(label)
                    .font(ThemeManager.Typography.boardMicro)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Bar
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(TripFilter.allCases, id: \.self) { filter in
                    let count = countForFilter(filter)
                    let isActive = selectedFilter == filter

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 6) {
                            // Status dot
                            Circle()
                                .fill(isActive ? filterColor(filter) : AppColors.textTertiary.opacity(0.4))
                                .frame(width: 6, height: 6)

                            Text(filter.boardLabel)
                                .font(.custom(isActive ? "SpaceMono-Bold" : "SpaceMono-Regular", size: 12))

                            if count > 0 && filter != .all {
                                Text("\(count)")
                                    .font(ThemeManager.Typography.boardHeader)
                                    .foregroundStyle(isActive ? filterColor(filter) : AppColors.textTertiary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(isActive ? filterColor(filter).opacity(0.15) : AppColors.surfaceLighter)
                                    )
                            }
                        }
                        .foregroundStyle(isActive ? AppColors.textPrimary : AppColors.textTertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isActive ? AppColors.surfaceLight : .clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isActive ? AppColors.cardBorder : .clear, lineWidth: 0.5)
                                )
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Column Headers
    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Text("myTrips.colFlight".localized)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("myTrips.colDate".localized)
                .frame(width: 80, alignment: .center)
            Text("myTrips.colStatus".localized)
                .frame(width: 90, alignment: .trailing)
        }
        .font(ThemeManager.Typography.boardHeader)
        .foregroundStyle(AppColors.textTertiary.opacity(0.6))
        .tracking(1)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            Rectangle().fill(AppColors.surfaceLight.opacity(0.3))
        )
        .overlay(
            VStack {
                Spacer()
                Rectangle().fill(AppColors.cardBorder.opacity(0.5)).frame(height: 0.5)
            }
        )
    }

    // MARK: - Trips Board
    private var tripsBoard: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(filteredTrips.enumerated()), id: \.element.id) { index, trip in
                NavigationLink(destination: TripDetailView(trip: trip)) {
                    boardRow(trip, index: index)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        tripToDelete = trip
                        showDeleteAlert = true
                    } label: {
                        Label("common.delete".localized, systemImage: "trash")
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.06),
                    value: appeared
                )
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Board Row
    private func boardRow(_ trip: Trip, index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left: City + route
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        // City code
                        Text(cityCode(trip.destinationCities.first ?? ""))
                            .font(ThemeManager.Typography.boardCity)
                            .foregroundStyle(AppColors.textPrimary)

                        if trip.destinationCities.count > 1 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9))
                                .foregroundStyle(AppColors.primary.opacity(0.6))

                            Text(cityCode(trip.destinationCities.last ?? ""))
                                .font(ThemeManager.Typography.boardCity)
                                .foregroundStyle(AppColors.textPrimary)

                            if trip.destinationCities.count > 2 {
                                Text("+\(trip.destinationCities.count - 2)")
                                    .font(ThemeManager.Typography.boardHeader)
                                    .foregroundStyle(AppColors.primary)
                            }
                        }
                    }

                    // Full city name + companion
                    HStack(spacing: 6) {
                        Text(trip.title ?? trip.destinationCities.joined(separator: " → "))
                            .font(ThemeManager.Typography.boardCaption)
                            .foregroundStyle(AppColors.textTertiary)
                            .lineLimit(1)

                        Text("·")
                            .foregroundStyle(AppColors.textTertiary.opacity(0.4))

                        HStack(spacing: 3) {
                            Image(systemName: trip.companion.icon)
                                .font(.system(size: 9))
                            Text(trip.companion.displayName)
                                .font(ThemeManager.Typography.boardHeader)
                        }
                        .foregroundStyle(AppColors.textTertiary)
                    }

                    // Duration + nights
                    HStack(spacing: 4) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 8))
                        Text(String(format: "createTrip.nights".localized, trip.durationNights))
                            .font(ThemeManager.Typography.boardHeader)
                    }
                    .foregroundStyle(AppColors.textTertiary.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Center: Date
                VStack(spacing: 2) {
                    if let startDate = trip.startDate {
                        Text(startDate.formatted(.dateTime.day()))
                            .font(ThemeManager.Typography.boardValue)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(startDate.formatted(.dateTime.month(.abbreviated)).uppercased())
                            .font(ThemeManager.Typography.boardHeader)
                            .foregroundStyle(AppColors.textTertiary)
                            .tracking(1)
                    } else {
                        Text("--")
                            .font(ThemeManager.Typography.boardValue)
                            .foregroundStyle(AppColors.textTertiary)
                        Text("---")
                            .font(ThemeManager.Typography.boardHeader)
                            .foregroundStyle(AppColors.textTertiary.opacity(0.5))
                    }
                }
                .frame(width: 50)

                // Right: Status badge
                statusBadge(trip)
                    .frame(width: 90, alignment: .trailing)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.surface.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.cardBorder.opacity(0.3), lineWidth: 0.5)
                    )
            )
            .padding(.vertical, 4)
        }
    }

    // MARK: - Status Badge
    private func statusBadge(_ trip: Trip) -> some View {
        let status = trip.status
        let color = statusColor(for: trip)
        let label = statusBoardLabel(trip)

        return VStack(spacing: 6) {
            HStack(spacing: 5) {
                if status == .generating {
                    // Pulse dot for generating
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                        .opacity(appeared ? 0.3 : 1)
                        .animation(.easeInOut(duration: 0.8).repeatForever(), value: appeared)
                }
                Text(label)
                    .font(ThemeManager.Typography.boardMicro)
                    .tracking(0.5)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(color.opacity(0.2), lineWidth: 0.5)
                    )
            )

            // Days left for upcoming trips
            if let startDate = trip.startDate, status != .generating {
                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: startDate).day ?? 0
                if daysLeft > 0 {
                    Text(String(format: "myTrips.daysLeft".localized, daysLeft))
                        .font(ThemeManager.Typography.boardMicro)
                        .foregroundStyle(status == .failed ? AppColors.error : AppColors.primary)
                }
            }
        }
    }

    // MARK: - Skeleton Loading
    private var skeletonLoading: some View {
        VStack(spacing: 0) {
            // Hero skeleton
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.surface)
                .frame(height: 220)
                .shimmer()
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // Info strip skeleton
            Rectangle()
                .fill(AppColors.surface)
                .frame(height: 56)
                .shimmer()
                .padding(.top, 20)

            // Rows skeleton
            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.surface)
                        .frame(height: 80)
                        .shimmer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)

            Spacer()
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 32) {
            Spacer()

            // Runway illustration
            ZStack {
                // Runway
                VStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 12) {
                        ForEach(0..<7, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(AppColors.primary.opacity(0.15))
                                .frame(width: 20, height: 3)
                                .opacity(appeared ? 1.0 : 0.3)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.1),
                                    value: appeared
                                )
                        }
                    }
                }
                .frame(height: 120)

                // Airplane taking off
                Image(systemName: "airplane")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.primary.opacity(0.6))
                    .rotationEffect(.degrees(-30))
                    .offset(
                        x: appeared ? 30 : -20,
                        y: appeared ? -30 : 10
                    )
                    .animation(
                        .easeInOut(duration: 3).repeatForever(autoreverses: true),
                        value: appeared
                    )
            }
            .frame(height: 120)

            VStack(spacing: 10) {
                Text("myTrips.boardEmpty".localized)
                    .font(ThemeManager.Typography.boardCity)
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(1)

                Text("myTrips.emptySubtitle".localized)
                    .font(ThemeManager.Typography.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
            }

            Button {
                showCreateTrip = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15))
                    Text("myTrips.scheduleFirst".localized)
                        .font(ThemeManager.Typography.subheadlineBold)
                        .tracking(0.5)
                }
                .foregroundStyle(AppColors.background)
                .frame(width: 240, height: 50)
                .background(
                    Capsule().fill(AppColors.primaryGradient)
                )
                .shadow(color: AppColors.primary.opacity(0.3), radius: 16, y: 8)
            }

            Spacer()
        }
        .onAppear { appeared = true }
    }

    // MARK: - Helpers

    private var filteredTrips: [Trip] {
        switch selectedFilter {
        case .all:
            return viewModel.trips
        case .upcoming:
            // Gelecekte olan ve planı hazır geziler (kalkışa hazır)
            return viewModel.trips.filter { trip in
                guard let startDate = trip.startDate else { return false }
                return startDate > Date() && trip.status == .completed
            }
        case .draft:
            // Planı henüz hazır olmayan geziler (taslak, oluşturuluyor, başarısız)
            return viewModel.trips.filter { trip in
                trip.status == .draft || trip.status == .generating || trip.status == .failed
            }
        case .completed:
            // Geçmiş tarihli tamamlanmış geziler (iniş yapanlar)
            return viewModel.trips.filter { trip in
                guard let startDate = trip.startDate else { return false }
                return trip.status == .completed && startDate < Date()
            }
        }
    }

    private func countForFilter(_ filter: TripFilter) -> Int {
        switch filter {
        case .all: return viewModel.trips.count
        case .upcoming: return viewModel.upcomingCount
        case .draft: return viewModel.draftCount
        case .completed: return viewModel.completedCount
        }
    }

    private func statusColor(for trip: Trip) -> Color {
        switch trip.status {
        case .completed:
            // Gelecekteki trip = mavi (hazır), geçmiş trip = yeşil (tamamlandı)
            if let startDate = trip.startDate, startDate > Date() {
                return AppColors.info
            }
            return AppColors.success
        case .generating: return AppColors.warning
        case .failed: return AppColors.error
        case .draft: return AppColors.textSecondary
        }
    }

    private func statusBoardLabel(_ trip: Trip) -> String {
        switch trip.status {
        case .completed:
            if let startDate = trip.startDate, startDate < Date() {
                return "myTrips.statusLanded".localized
            }
            return "myTrips.statusOnTime".localized
        case .generating: return "myTrips.statusBoarding".localized
        case .failed: return "myTrips.statusCancelled".localized
        case .draft: return "myTrips.statusScheduled".localized
        }
    }

    private func filterColor(_ filter: TripFilter) -> Color {
        switch filter {
        case .all: return AppColors.primary
        case .completed: return AppColors.success
        case .draft: return AppColors.info
        case .upcoming: return AppColors.warning
        }
    }

    /// Generate 3-letter city code from city name
    private func cityCode(_ city: String) -> String {
        let clean = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "---" }

        // Well-known city codes
        let codes: [String: String] = [
            "istanbul": "IST", "ankara": "ANK", "izmir": "IZM",
            "antalya": "AYT", "paris": "CDG", "london": "LHR",
            "londra": "LHR", "roma": "FCO", "rome": "FCO",
            "new york": "JFK", "dubai": "DXB", "tokyo": "TYO",
            "barcelona": "BCN", "amsterdam": "AMS", "berlin": "BER",
            "münih": "MUC", "munich": "MUC", "viyana": "VIE",
            "vienna": "VIE", "prag": "PRG", "prague": "PRG",
            "budapeşte": "BUD", "budapest": "BUD", "atina": "ATH",
            "athens": "ATH", "lizbon": "LIS", "lisbon": "LIS",
            "madrid": "MAD", "milano": "MXP", "milan": "MXP",
            "venedik": "VCE", "venice": "VCE", "floransa": "FLR",
            "florence": "FLR", "marakeş": "RAK", "marrakech": "RAK",
            "kahire": "CAI", "cairo": "CAI", "singapur": "SIN",
            "singapore": "SIN", "bangkok": "BKK", "bali": "DPS",
            "seul": "ICN", "seoul": "ICN", "pekin": "PEK",
            "beijing": "PEK", "los angeles": "LAX", "bodrum": "BJV",
            "dalaman": "DLM", "trabzon": "TZX", "adana": "ADA",
            "gaziantep": "GZT", "konya": "KYA", "bursa": "YEI",
            "kapadokya": "NAV", "cappadocia": "NAV", "fethiye": "DLM",
            "kuşadası": "ADB", "çeşme": "ADB", "sydney": "SYD",
            "melbourne": "MEL", "toronto": "YYZ", "moskova": "SVO",
            "moscow": "SVO", "miami": "MIA", "boston": "BOS"
        ]

        let lowered = clean.lowercased()
        if let code = codes[lowered] { return code }

        // Fallback: first 3 letters uppercased
        let ascii = clean.uppercased().filter { $0.isLetter }
        return String(ascii.prefix(3)).padding(toLength: 3, withPad: "X", startingAt: 0)
    }

    private func countdownComponents(to date: Date) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let diff = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: countdownNow, to: date)
        return (
            days: max(diff.day ?? 0, 0),
            hours: max(diff.hour ?? 0, 0),
            minutes: max(diff.minute ?? 0, 0),
            seconds: max(diff.second ?? 0, 0)
        )
    }
}

// MARK: - Trip Filter
enum TripFilter: String, CaseIterable {
    case all, upcoming, draft, completed

    var displayName: String {
        switch self {
        case .all: return "myTrips.filterAll".localized
        case .completed: return "myTrips.filterCompleted".localized
        case .draft: return "myTrips.filterDraft".localized
        case .upcoming: return "myTrips.filterUpcoming".localized
        }
    }

    var boardLabel: String {
        switch self {
        case .all: return "myTrips.boardAll".localized
        case .upcoming: return "myTrips.boardUpcoming".localized
        case .draft: return "myTrips.boardDraft".localized
        case .completed: return "myTrips.boardCompleted".localized
        }
    }

    var icon: String {
        switch self {
        case .all: return "tray.full.fill"
        case .completed: return "checkmark.circle"
        case .draft: return "doc.text"
        case .upcoming: return "airplane"
        }
    }
}

// MARK: - View Model
@MainActor
class TripsListViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var isLoading = false
    @Published var error: Error?

    private var localUserId: String {
        if let id = UserDefaults.standard.string(forKey: "localUserId") { return id }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "localUserId")
        return newId
    }

    var upcomingCount: Int {
        // Gelecekte olan ve planı hazır geziler
        trips.filter { trip in
            guard let startDate = trip.startDate else { return false }
            return startDate > Date() && trip.status == .completed
        }.count
    }

    var draftCount: Int {
        // Planı henüz hazır olmayan geziler (taslak, oluşturuluyor, başarısız)
        trips.filter { trip in
            trip.status == .draft || trip.status == .generating || trip.status == .failed
        }.count
    }

    var completedCount: Int {
        // Geçmiş tarihli tamamlanmış geziler
        trips.filter { trip in
            guard let startDate = trip.startDate else { return false }
            return trip.status == .completed && startDate < Date()
        }.count
    }

    var nextUpcomingTrip: Trip? {
        trips
            .filter { trip in
                guard let startDate = trip.startDate else { return false }
                return startDate > Date() && trip.status == .completed
            }
            .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
            .first
    }

    func loadTrips() async {
        isLoading = true
        defer { isLoading = false }
        do {
            trips = try await SupabaseService.shared.fetchTrips(userId: localUserId)
        } catch {
            self.error = error
        }
    }

    func refresh() async { await loadTrips() }

    func deleteTrip(_ trip: Trip) async {
        do {
            try await SupabaseService.shared.deleteTrip(id: trip.id)
            withAnimation(.spring(response: 0.4)) {
                trips.removeAll { $0.id == trip.id }
            }
        } catch {
        }
    }
}

#Preview { TripsListView() }
