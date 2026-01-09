//
//  KeeprrMomentsView.swift
//  Keeprr
//
//  Created by Ethan Um on 2026-01-04.
//

import SwiftUI
import Photos

// MARK: - Keeprr Moments View

struct KeeprrMomentsView: View {
    @StateObject private var momentsManager = KeeprrMomentsManager()
    @State private var selectedMoment: Moment?
    
    var body: some View {
        NavigationView {
            contentView
                .navigationTitle("Keeprr Moments (\(momentsManager.moments.count))")
                .navigationBarTitleDisplayMode(.inline)
                .fullScreenCover(item: $selectedMoment) { moment in
                    MomentDetailView(moment: moment, momentsManager: momentsManager)
                }
                .onAppear {
                    // Ensure we request photo permissions and load assets the first time this tab is opened.
                    momentsManager.requestAuthorization()
                }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if momentsManager.authorizationStatus == .denied || momentsManager.authorizationStatus == .restricted {
            permissionDeniedView
        } else if momentsManager.authorizationStatus == .notDetermined {
            loadingView
        } else if momentsManager.isLoading && momentsManager.moments.isEmpty {
            loadingView
        } else if momentsManager.moments.isEmpty {
            emptyStateView
        } else {
            momentsCalendarView
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading moments...")
                .foregroundColor(.secondary)
                .padding(.top, 10)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No Moments Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Capture your first Keeprr moment using the camera tab. Moments are created when you take both front and back photos.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
        }
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("Photo Access Required")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Keeprr needs access to your photo library to load your moments.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            Button(action: openSettings) {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top, 20)
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private var momentsCalendarView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                calendarViews
            }
            .scrollDismissesKeyboard(.never)
        }
    }
    
    @ViewBuilder
    private var calendarViews: some View {
        // Show all loaded months, newest first (at top)
        let allMonths = Array(momentsManager.monthsWithMoments)
        
        if allMonths.isEmpty {
            EmptyView()
        } else {
            ForEach(Array(allMonths.enumerated()), id: \.element) { index, monthYear in
                MomentsCalendarMonthView(
                    monthYear: monthYear,
                    momentsByDate: momentsManager.momentsByDate,
                    monthFormatter: momentsManager.monthFormatter,
                    onMomentTap: handleMomentTap,
                    momentsManager: momentsManager
                )
                .padding(.bottom, 30)
                .id("month-\(monthYear.timeIntervalSince1970)")
            }
        }
    }
    
    private func handleMomentTap(moment: Moment) {
        selectedMoment = moment
    }
}

// MARK: - Moments Calendar Month View

struct MomentsCalendarMonthView: View {
    let monthYear: Date
    let momentsByDate: [Date: [Moment]]
    let monthFormatter: DateFormatter
    let onMomentTap: (Moment) -> Void
    @ObservedObject var momentsManager: KeeprrMomentsManager
    
    private var calendar: Calendar {
        Calendar.current
    }
    
    private var monthStart: Date {
        let components = calendar.dateComponents([.year, .month], from: monthYear)
        let date = calendar.date(from: components)!
        return calendar.startOfDay(for: date)
    }
    
    private var firstDayOfMonth: Int {
        let components = calendar.dateComponents([.weekday], from: monthStart)
        // Calendar.weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        // Convert to Sunday = 0, Monday = 1, etc.
        let weekday = components.weekday!
        // Ensure we get 0-6 range (Sunday = 0)
        return (weekday - 1) % 7
    }
    
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 0
    }
    
    private var isFirstMonth: Bool {
        let currentMonth = calendar.dateComponents([.year, .month], from: Date())
        let viewMonth = calendar.dateComponents([.year, .month], from: monthYear)
        return currentMonth.year == viewMonth.year && currentMonth.month == viewMonth.month
    }
    
    private var maxDayToShow: Int {
        if isFirstMonth {
            // For current month, only show days up to today
            return calendar.component(.day, from: Date())
        } else {
            // For past months, show all days
            return daysInMonth
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Month header - always show
            Text(monthFormatter.string(from: monthYear))
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            
            // Day labels - always show
            HStack(spacing: 0) {
                ForEach(["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                // Empty cells for days before month starts
                ForEach(0..<firstDayOfMonth, id: \.self) { index in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .id("\(monthStart.timeIntervalSince1970)-empty-\(index)")
                }
                
                // Days of the month (only show up to today for current month)
                ForEach(1...maxDayToShow, id: \.self) { day in
                    let dayDate = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
                    let dayStart = calendar.startOfDay(for: dayDate)
                    let isToday = calendar.isDateInToday(dayDate)
                    
                    MomentsCalendarDayCell(
                        day: day,
                        moments: momentsByDate[dayStart] ?? [],
                        isToday: isToday,
                        momentsManager: momentsManager,
                        onMomentTap: onMomentTap
                    )
                    .id("\(monthStart.timeIntervalSince1970)-\(day)")
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Moments Calendar Day Cell

struct MomentsCalendarDayCell: View {
    let day: Int
    let moments: [Moment]
    let isToday: Bool
    @ObservedObject var momentsManager: KeeprrMomentsManager
    let onMomentTap: (Moment) -> Void
    
    @State private var thumbnail: UIImage?
    @State private var loadFailed = false
    
    // Filter moments to only those with valid assets
    private var validMoments: [Moment] {
        moments.filter { moment in
            let assets = momentsManager.getAssets(for: moment.id)
            // A Keeprr Moment should always have BOTH images (front overlay + back base).
            return assets.front != nil && assets.back != nil
        }
    }
    
    private var hasValidMoments: Bool {
        !validMoments.isEmpty && !loadFailed
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if hasValidMoments {
                    // Show moment thumbnail
                    Group {
                        if let thumbnail = thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        } else {
                            // Loading state - show static placeholder
                            ZStack {
                                Color.gray.opacity(0.2)
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                    .clipped()
                    .cornerRadius(8)
                    .overlay(
                        // Moment count badge
                        Group {
                            if validMoments.count > 1 {
                                HStack {
                                    Spacer()
                                    VStack {
                                        Text("\(validMoments.count)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.black.opacity(0.7))
                                            .cornerRadius(10)
                                        Spacer()
                                    }
                                }
                                .padding(4)
                            }
                        }
                        .allowsHitTesting(false)
                    )
                    .overlay(
                        // Day number overlay
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("\(day)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(4)
                                    .padding(4)
                            }
                        }
                        .allowsHitTesting(false)
                    )
                    .overlay(
                        // Today indicator
                        Group {
                            if isToday {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 2)
                            }
                        }
                        .allowsHitTesting(false)
                    )
                } else {
                    // Empty cell - show even if moments exist but assets are invalid
                    ZStack {
                        Color.gray.opacity(0.1)
                        Text("\(day)")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .cornerRadius(8)
                    .overlay(
                        Group {
                            if isToday {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 2)
                            }
                        }
                        .allowsHitTesting(false)
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Allow tap even if the thumbnail is still loading.
                if let firstMoment = validMoments.first {
                    onMomentTap(firstMoment)
                }
            }
            .onAppear {
                loadThumbnail(targetSize: geometry.size)
            }
            .onChange(of: validMoments.first?.id) { _, _ in
                // When assets finish loading, validMoments transitions from empty -> non-empty.
                // Retry thumbnail load so the first open of the tab shows previews immediately.
                loadThumbnail(targetSize: geometry.size)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func loadThumbnail(targetSize: CGSize) {
        // If assets haven't been resolved yet, don't mark as failed — we'll retry when they load.
        guard let firstMoment = validMoments.first else { return }
        
        // Moments thumbnails should always be the BACK camera image.
        let assets = momentsManager.getAssets(for: firstMoment.id)
        guard let asset = assets.back else {
            loadFailed = true
            return
        }
        
        loadFailed = false
        
        momentsManager.loadThumbnail(for: asset, targetSize: targetSize) { image in
            if let image = image {
                thumbnail = image
                loadFailed = false
            } else {
                // If thumbnail failed to load, mark as failed so we don't display
                loadFailed = true
                thumbnail = nil
            }
        }
    }
}

// MARK: - Moment Detail View

struct MomentDetailView: View {
    let moment: Moment
    @ObservedObject var momentsManager: KeeprrMomentsManager
    @Environment(\.dismiss) var dismiss
    
    private var dayStart: Date { Calendar.current.startOfDay(for: moment.createdAt) }
    
    @State private var currentIndex: Int = 0
    @State private var windowMoments: [Moment] = []
    @State private var currentMomentId: String = ""
    @State private var windowCenterDay: Date?
    @State private var isRebuildingWindow = false
    
    @State private var showDeleteAlert = false
    @State private var deleteErrorMessage: String?
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Fixed header (always above the image content)
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    if let current = dayMoments[safe: currentIndex] {
                        VStack(spacing: 4) {
                            Text(current.createdAt.formatted(date: .long, time: .omitted))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Text(current.createdAt.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                            Text("\(currentDayIndex + 1) of \(max(currentDayCount, 1))")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 2)
                        }
                    }
                    
                    Spacer()

                    Menu {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete Moment", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, geo.safeAreaInsets.top + 10)
                .padding(.bottom, 12)
                .background(Color.black.ignoresSafeArea(edges: .top))
                
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if dayMoments.isEmpty {
                        VStack(spacing: 16) {
                            ProgressView().tint(.white)
                            Text("Loading moments...")
                                .foregroundColor(.white.opacity(0.85))
                            Button("Close") { dismiss() }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(10)
                        }
                    } else {
                        TabView(selection: $currentIndex) {
                            ForEach(Array(dayMoments.enumerated()), id: \.element.id) { index, m in
                                MomentPageView(moment: m, momentsManager: momentsManager)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .transaction { txn in
                            if isRebuildingWindow {
                                txn.animation = nil
                            }
                        }
                        
                        VStack {
                            Spacer()
                            momentDayAwareIndicator
                                .padding(.bottom, max(10, geo.safeAreaInsets.bottom + 6))
                        }
                        .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.black.ignoresSafeArea())
        }
        .onAppear {
            currentMomentId = moment.id
            windowCenterDay = dayStart
            rebuildWindow(centerDay: windowCenterDay, keepingMomentId: currentMomentId)
            if let idx = windowMoments.firstIndex(where: { $0.id == moment.id }) {
                currentIndex = idx
            }
        }
        .onChange(of: momentsManager.moments.map(\.id)) { _, _ in
            // `momentsByDate` isn't Equatable (Moment isn't Equatable), so observe a stable Equatable proxy.
            rebuildWindow(centerDay: windowCenterDay, keepingMomentId: currentMomentId)
        }
        .onChange(of: currentIndex) { _, newValue in
            guard let current = windowMoments[safe: newValue] else { return }
            currentMomentId = current.id
            windowCenterDay = Calendar.current.startOfDay(for: current.createdAt)
            maybeShiftWindowForPagingEdge()
        }
        .alert("Delete Moment", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                guard let current = windowMoments[safe: currentIndex] else { return }
                momentsManager.deleteMomentPhotos(current) { result in
                    switch result {
                    case .success:
                        dismiss()
                    case .failure(let err):
                        deleteErrorMessage = err.localizedDescription
                    }
                }
            }
        } message: {
            Text("This will delete the moment’s photos from your library. This action cannot be undone.")
        }
        .alert("Unable to Delete", isPresented: Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "Unknown error.")
        }
    }

    // MARK: - Windowed paging across days
    
    private var dayMoments: [Moment] { windowMoments }
    
    private func rebuildWindow(centerDay: Date?, keepingMomentId: String?) {
        let calendar = Calendar.current
        let center = centerDay ?? dayStart
        
        let allDays = momentsManager.momentsByDate.keys
            .map { calendar.startOfDay(for: $0) }
            .sorted(by: >) // newest day first
        
        guard let dayIndex = allDays.firstIndex(of: center) else {
            // Oldest -> newest so swipe left goes toward present, swipe right goes further back.
            windowMoments = (momentsManager.momentsByDate[dayStart] ?? []).sorted { $0.createdAt < $1.createdAt }
            currentIndex = windowMoments.firstIndex(where: { $0.id == (keepingMomentId ?? moment.id) }) ?? 0
            return
        }
        
        let daysEachDirection = 3
        let start = max(0, dayIndex - daysEachDirection)
        let end = min(allDays.count - 1, dayIndex + daysEachDirection)
        let windowDays = Array(allDays[start...end])
        
        var next: [Moment] = []
        next.reserveCapacity(64)
        for day in windowDays {
            // Oldest -> newest so swiping direction matches the (flipped) photo viewer.
            let ms = (momentsManager.momentsByDate[day] ?? []).sorted { $0.createdAt < $1.createdAt }
            next.append(contentsOf: ms)
        }
        
        // Ensure selected moment exists in list.
        if !next.contains(where: { $0.id == moment.id }) {
            next.insert(moment, at: 0)
        }

        // Make ordering unambiguous for the pager: oldest -> newest across the whole window.
        // This guarantees swipe-left = newer (toward present), swipe-right = older (further),
        // even if upstream arrays arrive in an unexpected order.
        next.sort { $0.createdAt < $1.createdAt }
        
        let targetId = keepingMomentId ?? currentMomentId
        
        isRebuildingWindow = true
        var txn = Transaction()
        txn.animation = nil
        withTransaction(txn) {
            windowMoments = next
            currentIndex = next.firstIndex(where: { $0.id == targetId }) ?? 0
        }
        isRebuildingWindow = false
    }
    
    private func maybeShiftWindowForPagingEdge() {
        guard !windowMoments.isEmpty else { return }
        let nearStart = currentIndex <= 2
        let nearEnd = currentIndex >= max(0, windowMoments.count - 3)
        guard nearStart || nearEnd else { return }
        
        rebuildWindow(centerDay: windowCenterDay, keepingMomentId: currentMomentId)
    }
    
    // MARK: - Day-scoped counter + day-aware indicator
    
    private var currentDayKey: Date? {
        guard let current = windowMoments[safe: currentIndex] else { return nil }
        return Calendar.current.startOfDay(for: current.createdAt)
    }
    
    private var currentDayMoments: [Moment] {
        guard let day = currentDayKey else { return [] }
        let cal = Calendar.current
        return windowMoments
            .filter { cal.startOfDay(for: $0.createdAt) == day }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    private var currentDayCount: Int { currentDayMoments.count }
    
    private var currentDayIndex: Int {
        guard let current = windowMoments[safe: currentIndex] else { return 0 }
        return currentDayMoments.firstIndex(where: { $0.id == current.id }) ?? 0
    }
    
    private var momentDayAwareIndicator: some View {
        guard !windowMoments.isEmpty else { return AnyView(EmptyView()) }
        let radius = 10
        let start = max(0, currentIndex - radius)
        let end = min(windowMoments.count - 1, currentIndex + radius)
        
        return AnyView(
            HStack(spacing: 6) {
                ForEach(start...end, id: \.self) { idx in
                    Circle()
                        .fill(idx == currentIndex ? Color.white : Color.white.opacity(0.35))
                        .frame(width: idx == currentIndex ? 8 : 6, height: idx == currentIndex ? 8 : 6)
                    
                    if idx < end {
                        let aDay = Calendar.current.startOfDay(for: windowMoments[idx].createdAt)
                        let bDay = Calendar.current.startOfDay(for: windowMoments[idx + 1].createdAt)
                        if aDay != bDay {
                            Rectangle()
                                .fill(Color.white.opacity(0.45))
                                .frame(width: 2, height: 8)
                                .padding(.horizontal, 6)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.35))
            .clipShape(Capsule())
        )
    }
}

// MARK: - Moment Page View (single moment display)

private struct MomentPageView: View {
    let moment: Moment
    @ObservedObject var momentsManager: KeeprrMomentsManager
    
    @State private var backImage: UIImage?
    @State private var frontImage: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var isSwapped = false
    @State private var overlayOffset: CGSize = .zero
    @State private var overlayDragTranslation: CGSize = .zero
    @State private var canSwap = true
    @GestureState private var isPressingBaseImage = false
    @State private var activeLoadToken = UUID()
    
    private var backAsset: PHAsset? {
        momentsManager.getAssets(for: moment.id).back
    }
    
    private var frontAsset: PHAsset? {
        momentsManager.getAssets(for: moment.id).front
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Prefer showing the last-rendered image during paging to avoid a spinner flash.
            if let backImage {
                GeometryReader { geo in
                    let container = geo.size
                    let baseImage: UIImage = (isSwapped ? (frontImage ?? backImage) : backImage)
                    let overlayImage: UIImage? = (isSwapped ? backImage : frontImage)
                    
                    let imgSize = baseImage.size
                    let safeW = max(imgSize.width, CGFloat(1))
                    let safeH = max(imgSize.height, CGFloat(1))
                    let scale = min(container.width / safeW, container.height / safeH)
                    let fitted = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
                    
                    // Keep the overlay within the displayed back-photo frame (account for padding).
                    let overlayPaddingX: CGFloat = 18
                    let overlayPaddingY: CGFloat = 24
                    let overlayMaxWidth = max(CGFloat(0), fitted.width - (overlayPaddingX * 2))
                    let overlayMaxHeight = max(CGFloat(0), fitted.height - (overlayPaddingY * 2))
                    let overlayWidth = min(CGFloat(140), overlayMaxWidth)
                    let overlayHeight = min(CGFloat(190), overlayMaxHeight)

                    let currentOverlayOffset = clampedOverlayOffset(
                        raw: CGSize(
                            width: overlayOffset.width + overlayDragTranslation.width,
                            height: overlayOffset.height + overlayDragTranslation.height
                        ),
                        fitted: fitted,
                        overlaySize: CGSize(width: overlayWidth, height: overlayHeight),
                        paddingX: overlayPaddingX,
                        paddingY: overlayPaddingY
                    )
                    
                    // Important: Keep overlays *within the displayed back photo bounds*
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: baseImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: fitted.width, height: fitted.height)
                            .clipped()
                            .simultaneousGesture(
                                // Hide overlay only after a true hold (prevents accidental hides while paging),
                                // and keep it hidden until finger-up even if the finger moves a bit.
                                LongPressGesture(minimumDuration: 0.5, maximumDistance: 10)
                                    .sequenced(before: DragGesture(minimumDistance: 0))
                                    .updating($isPressingBaseImage) { value, state, _ in
                                        switch value {
                                        case .second(true, _):
                                            state = true
                                        default:
                                            state = false
                                        }
                                    }
                            )
                        
                        if let overlayImage {
                            Image(uiImage: overlayImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: overlayWidth, height: overlayHeight)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
                                .opacity(isPressingBaseImage ? 0 : 1)
                                .animation(.easeInOut(duration: 0.15), value: isPressingBaseImage)
                                .offset(
                                    x: overlayPaddingX + currentOverlayOffset.width,
                                    y: overlayPaddingY + currentOverlayOffset.height
                                )
                                .onTapGesture {
                                    // Only swap if we actually have both photos loaded.
                                    guard frontImage != nil, canSwap else { return }
                                    canSwap = false
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        isSwapped.toggle()
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        canSwap = true
                                    }
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 2)
                                        .onChanged { value in
                                            overlayDragTranslation = value.translation
                                        }
                                        .onEnded { _ in
                                            overlayOffset = currentOverlayOffset
                                            overlayDragTranslation = .zero
                                        }
                                )
                        }
                    }
                    .frame(width: fitted.width, height: fitted.height)
                    // Top-align content within the available space (matches All Photos viewer layout).
                    .position(x: container.width / 2, y: fitted.height / 2)
                }
                // No spinner overlay here: this branch already has a rendered image.
            } else if loadFailed {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.7))
                    Text("Unable to load moment")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("The image may have been deleted")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else if isLoading {
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    Text("Loading moment...")
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            loadMomentImages()
        }
        .onChange(of: moment.id) { _, _ in
            loadMomentImages()
        }
    }
    
    private func loadMomentImages() {
        isLoading = true
        loadFailed = false
        isSwapped = false
        overlayOffset = .zero
        overlayDragTranslation = .zero
        canSwap = true
        
        let loadToken = UUID()
        activeLoadToken = loadToken
        
        guard let backAsset, let frontAsset else {
            isLoading = false
            loadFailed = true
            return
        }
        
        let group = DispatchGroup()
        var loadedBack: UIImage?
        var loadedFront: UIImage?
        
        group.enter()
        momentsManager.loadFullImage(for: backAsset) { image in
            loadedBack = image
            group.leave()
        }
        
        group.enter()
        momentsManager.loadFullImage(for: frontAsset) { image in
            loadedFront = image
            group.leave()
        }
        
        group.notify(queue: .main) {
            guard activeLoadToken == loadToken else { return }
            if let loadedBack {
                backImage = loadedBack
                frontImage = loadedFront
                isLoading = false
                loadFailed = false
            } else {
                isLoading = false
                loadFailed = true
            }
        }
    }

    private func clampedOverlayOffset(
        raw: CGSize,
        fitted: CGSize,
        overlaySize: CGSize,
        paddingX: CGFloat,
        paddingY: CGFloat
    ) -> CGSize {
        // We place the overlay at (padding + offset). Clamp so the overlay stays within [0..fitted - overlaySize].
        let minX = -paddingX
        let maxX = max(CGFloat(0), fitted.width - overlaySize.width - paddingX)
        let minY = -paddingY
        let maxY = max(CGFloat(0), fitted.height - overlaySize.height - paddingY)

        return CGSize(
            width: min(max(raw.width, minX), maxX),
            height: min(max(raw.height, minY), maxY)
        )
    }
}


