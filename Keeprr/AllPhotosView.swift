//
//  AllPhotosView.swift
//  Keeprr
//
//  Created by Ethan Um on 2026-01-04.
//

import SwiftUI
import Photos
#if canImport(UIKit)
import UIKit
#endif

// MARK: - All Photos View

struct AllPhotosView: View {
    @StateObject private var photoManager = PhotoManager()
    
    private struct SelectedAsset: Identifiable {
        let asset: PHAsset
        var id: String { asset.localIdentifier }
    }
    
    @State private var selectedAsset: SelectedAsset?
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationView {
            contentView
                .navigationTitle("All Photos (\(photoManager.totalPhotoCount))")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    photoManager.requestAuthorization()
                }
                .fullScreenCover(item: $selectedAsset) { selected in
                    photoModalView(for: selected.asset)
                }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ZStack {
            if photoManager.authorizationStatus == .authorized || photoManager.authorizationStatus == .limited {
                photosScrollView
            } else if photoManager.authorizationStatus == .denied || photoManager.authorizationStatus == .restricted {
                permissionDeniedView
            } else {
                loadingView
            }
        }
    }
    
    private var photosScrollView: some View {
        ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    calendarViews
                    
                    // Loading indicator at bottom when loading more photos
                    if photoManager.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Text("Loading older photos...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(height: 50)
                        .padding(.top, 20)
                    }
                    
                    // Trigger loading when this view appears (user scrolled to bottom)
                    Color.clear
                        .frame(height: 1)
                        .id("load-more-trigger")
                        .onAppear {
                            // When user scrolls to bottom, load more photos
                            if !photoManager.isLoadingMore && 
                               photoManager.loadedPhotoCount < photoManager.totalPhotoCount {
                                photoManager.loadMorePhotos()
                            }
                        }
                }
            }
            .scrollDismissesKeyboard(.never)
    }
    
    @ViewBuilder
    private var calendarViews: some View {
        // Show all loaded months, newest first (at top)
        let allMonths = Array(photoManager.monthsWithPhotos)
        
        if allMonths.isEmpty {
            EmptyView()
        } else {
            ForEach(Array(allMonths.enumerated()), id: \.element) { index, monthYear in
                CalendarMonthView(
                    monthYear: monthYear,
                    photosByDate: photoManager.photosByDate,
                    monthFormatter: photoManager.monthFormatter,
                    onPhotoTap: handlePhotoTap,
                    photoManager: photoManager
                )
                .padding(.bottom, 30)
                .id("month-\(monthYear.timeIntervalSince1970)")
                // Detect when oldest month (last in array) becomes visible to load more
                .onAppear {
                    // Last month in array is the oldest
                    let isOldestMonth = index == allMonths.count - 1
                    let canLoadMore = !photoManager.isLoadingMore && 
                                     photoManager.loadedPhotoCount < photoManager.totalPhotoCount
                    
                    if isOldestMonth && canLoadMore {
                        // Small delay to prevent multiple rapid calls
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if !photoManager.isLoadingMore && 
                               photoManager.loadedPhotoCount < photoManager.totalPhotoCount {
                                photoManager.loadMorePhotos()
                            }
                        }
                    }
                }
            }
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
            Text("Keeprr needs access to your photo library to display your photos. This allows you to view and manage your entire photo collection.")
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
    
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading photos...")
                .foregroundColor(.secondary)
                .padding(.top, 10)
        }
    }
    
    private func photoModalView(for photo: PHAsset) -> some View {
        return PhotoViewerModal(
            photoManager: photoManager,
            initialAsset: photo,
            daysEachDirection: 3,
            onDelete: {
                photoManager.deletePhoto($0)
                selectedAsset = nil
            }
        )
    }

    private func getWindowAssets(around photo: PHAsset, daysEachDirection: Int) -> [PHAsset] {
        let calendar = Calendar.current
        guard let d = photo.creationDate else {
            return [photo]
        }
        let selectedDay = calendar.startOfDay(for: d)

        let days = photoManager.photosByDate.keys
            .map { calendar.startOfDay(for: $0) }
            .sorted(by: >) // newest day first

        guard let dayIndex = days.firstIndex(of: selectedDay) else {
            // If we haven't loaded that day into the manager yet, just show the single photo.
            return [photo]
        }

        let start = max(0, dayIndex - daysEachDirection)
        let end = min(days.count - 1, dayIndex + daysEachDirection)
        let windowDays = Array(days[start...end])

        // Build a single ordered list (newest -> oldest) across the window.
        let assets: [PHAsset] = windowDays.flatMap { day in
            (photoManager.photosByDate[day] ?? [])
        }
        .sorted { a, b in
            (a.creationDate ?? .distantPast) > (b.creationDate ?? .distantPast)
        }

        // Ensure selected photo is included
        if assets.contains(where: { $0.localIdentifier == photo.localIdentifier }) {
            return assets
        }
        return [photo] + assets
    }
    
    private func getDayPhotos(for photo: PHAsset) -> [PHAsset] {
        // If photo has no creation date, just return the photo itself
        guard let photoDate = photo.creationDate else {
            return [photo]
        }
        
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: photoDate)
        
        // Get photos from the photo manager for this day
        var dayPhotos = photoManager.photosByDate[dayStart]?.sorted { asset1, asset2 in
            guard let date1 = asset1.creationDate, let date2 = asset2.creationDate else { return false }
            return date1 < date2 // Sort from earliest to latest (AM to PM)
        } ?? []
        
        // Ensure the selected photo is in the array (fallback)
        if dayPhotos.isEmpty {
            dayPhotos = [photo]
        } else if !dayPhotos.contains(where: { $0.localIdentifier == photo.localIdentifier }) {
            dayPhotos.append(photo)
            dayPhotos.sort { asset1, asset2 in
                guard let date1 = asset1.creationDate, let date2 = asset2.creationDate else { return false }
                return date1 < date2
            }
        }
        
        return dayPhotos
    }
    
    private func handlePhotoTap(photo: PHAsset, index: Int) {
        selectedAsset = SelectedAsset(asset: photo)
    }
    
    private func openSettings() {
        // Use the supported Settings deep link.
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            openURL(settingsUrl)
        }
    }
}

// MARK: - Calendar Month View

struct CalendarMonthView: View {
    let monthYear: Date
    let photosByDate: [Date: [PHAsset]]
    let monthFormatter: DateFormatter
    let onPhotoTap: (PHAsset, Int) -> Void
    @ObservedObject var photoManager: PhotoManager
    
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
                    
                    CalendarDayCell(
                        day: day,
                        photos: photosByDate[dayStart] ?? [],
                        isToday: isToday,
                        photoManager: photoManager,
                        onPhotoTap: onPhotoTap
                    )
                    .id("\(monthStart.timeIntervalSince1970)-\(day)")
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let day: Int
    let photos: [PHAsset]
    let isToday: Bool
    @ObservedObject var photoManager: PhotoManager
    let onPhotoTap: (PHAsset, Int) -> Void
    
    @State private var thumbnail: UIImage?
    
    var hasPhotos: Bool {
        !photos.isEmpty
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if hasPhotos {
                    // Show photo thumbnail
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
                            .onAppear {
                                loadThumbnail(targetSize: geometry.size)
                            }
                        }
                    }
                    .clipped()
                    .cornerRadius(8)
                    .overlay(
                        // Photo count badge
                        Group {
                            if photos.count > 1 {
                                HStack {
                                    Spacer()
                                    VStack {
                                        Text("\(photos.count)")
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
                    // Empty cell
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
                // Allow tap even if thumbnail is still loading
                if let firstPhoto = photos.first {
                    onPhotoTap(firstPhoto, 0)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func loadThumbnail(targetSize: CGSize) {
        guard let firstPhoto = photos.first else { return }
        
        // PhotoManager handles cache checking internally
        photoManager.loadThumbnail(for: firstPhoto, targetSize: targetSize) { image in
            thumbnail = image
        }
    }
}

// MARK: - Photo Viewer Modal

struct PhotoViewerModal: View {
    @ObservedObject var photoManager: PhotoManager
    let initialAsset: PHAsset
    let daysEachDirection: Int
    let onDelete: (PHAsset) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var currentPhotoIndex: Int = 0
    @State private var showDeleteAlert = false
    @State private var images: [String: UIImage] = [:] // Use asset ID as key
    @State private var failedImageIds: Set<String> = []
    @State private var imageRequestIds: [String: PHImageRequestID] = [:]
    @State private var assets: [PHAsset] = [] // current window, ordered newest -> oldest
    @State private var currentAssetId: String = ""
    @State private var windowCenterDay: Date?
    @State private var isRebuildingWindow = false
    
    private let imageManager = PHImageManager.default()

    init(photoManager: PhotoManager, initialAsset: PHAsset, daysEachDirection: Int = 3, onDelete: @escaping (PHAsset) -> Void) {
        self.photoManager = photoManager
        self.initialAsset = initialAsset
        self.daysEachDirection = daysEachDirection
        self.onDelete = onDelete
    }
    
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
                    
                    // Date and time - centered at top
                    VStack(spacing: 4) {
                        if currentPhotoIndex < assets.count,
                           let currentPhoto = assets[safe: currentPhotoIndex],
                           let creationDate = currentPhoto.creationDate {
                            Text(creationDate.formatted(date: .long, time: .omitted))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Text(creationDate.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                            
                            // Photo counter within the current DAY (e.g., "1 of 5")
                            let dayCount = currentDayCount
                            Text("\(currentDayIndex + 1) of \(max(dayCount, 1))")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 2)
                        }
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button(role: .destructive, action: {
                            showDeleteAlert = true
                        }) {
                            Label("Delete Photo", systemImage: "trash")
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
                // Swipe on the header to jump day-to-day (without fighting the photo pager swipe).
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            if value.translation.width < 0 {
                                jumpDay(direction: 1)
                            } else {
                                jumpDay(direction: -1)
                            }
                        }
                )
                
                // Image pager below header
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if assets.isEmpty {
                        VStack(spacing: 20) {
                            ProgressView().tint(.white)
                            Text("Loading photos...")
                                .foregroundColor(.white)
                        }
                    } else {
                        TabView(selection: $currentPhotoIndex) {
                            ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                ZStack(alignment: .top) {
                                    Color.black
                                    
                                    if let image = images[asset.localIdentifier] {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                    } else if failedImageIds.contains(asset.localIdentifier) {
                                        VStack(spacing: 12) {
                                            Image(systemName: "exclamationmark.triangle")
                                                .font(.system(size: 44))
                                                .foregroundColor(.white.opacity(0.8))
                                            Text("Failed to load image")
                                                .foregroundColor(.white)
                                            Button("Retry") {
                                                failedImageIds.remove(asset.localIdentifier)
                                                loadFullImage(for: asset)
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Color.white.opacity(0.2))
                                            .cornerRadius(10)
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                    } else {
                                        VStack(spacing: 20) {
                                            ProgressView().tint(.white)
                                            Text("Loading...")
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        .onAppear { loadFullImage(for: asset) }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                    }
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .transaction { txn in
                            // Avoid janky transitions when we rebuild the backing `assets` array while paging.
                            if isRebuildingWindow {
                                txn.animation = nil
                            }
                        }
                        
                        // Custom bottom indicator that shows day boundaries
                        VStack(spacing: 8) {
                            Spacer()
                            dayAwarePageIndicator
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
            currentAssetId = initialAsset.localIdentifier
            if let d = initialAsset.creationDate {
                windowCenterDay = Calendar.current.startOfDay(for: d)
            }
            rebuildWindow(centerDay: windowCenterDay, keepingAssetId: currentAssetId)
        }
        .onChange(of: photoManager.photosByDate) { _, _ in
            // As older photos are loaded, expand the available days and keep the window centered.
            rebuildWindow(centerDay: windowCenterDay, keepingAssetId: currentAssetId)
        }
        .onChange(of: currentPhotoIndex) { _, newValue in
            guard let current = assets[safe: newValue] else { return }
            currentAssetId = current.localIdentifier

            if let d = current.creationDate {
                windowCenterDay = Calendar.current.startOfDay(for: d)
            }

            // Load older photos as you approach the beginning (older direction),
            // since this pager is ordered oldest -> newest.
            if newValue <= 2,
               !photoManager.isLoadingMore,
               photoManager.loadedPhotoCount < photoManager.totalPhotoCount {
                photoManager.loadMorePhotos()
            }

            // Shift the day window as you approach either edge so swiping keeps flowing.
            maybeShiftWindowForPagingEdge()

            // Load current and adjacent images.
            loadFullImage(for: current)
            if newValue > 0, let prev = assets[safe: newValue - 1] { loadFullImage(for: prev) }
            if newValue + 1 < assets.count, let next = assets[safe: newValue + 1] { loadFullImage(for: next) }
            // Preload a bit further to avoid stutter when swiping between very different aspect ratios.
            if newValue > 1, let prev2 = assets[safe: newValue - 2] { loadFullImage(for: prev2) }
            if newValue + 2 < assets.count, let next2 = assets[safe: newValue + 2] { loadFullImage(for: next2) }

            pruneImageCache()
        }
        .alert("Delete Photo", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let assetToDelete = assets[safe: currentPhotoIndex] {
                    onDelete(assetToDelete)
                }
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this photo? This action cannot be undone.")
        }
    }
    
    private func loadFullImage(for asset: PHAsset) {
        let assetId = asset.localIdentifier
        guard images[assetId] == nil,
              !failedImageIds.contains(assetId),
              imageRequestIds[assetId] == nil else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        
        // Request an on-screen sized image (prevents memory blowups from caching full-res).
        let targetSize = recommendedTargetSize()
        
        let reqId = imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
            let error = info?[PHImageErrorKey] as? Error
            
            // Avoid UI-thread decode hitches: prepare image off-main when possible.
            if let image {
                // Degraded frames are often low-quality/partial; don't force decode them.
                if isDegraded {
                    DispatchQueue.main.async {
                        imageRequestIds.removeValue(forKey: assetId)
                        if images[assetId] == nil {
                            images[assetId] = image
                        }
                        failedImageIds.remove(assetId)
                    }
                    return
                }

                DispatchQueue.global(qos: .userInitiated).async {
                    #if canImport(UIKit)
                    // If pre-decode fails, treat as a failure to avoid repeated "decompressing image" spam.
                    guard let prepared = image.preparingForDisplay() else {
                        DispatchQueue.main.async {
                            imageRequestIds.removeValue(forKey: assetId)
                            images.removeValue(forKey: assetId)
                            failedImageIds.insert(assetId)
                        }
                        return
                    }
                    #else
                    let prepared = image
                    #endif
                    DispatchQueue.main.async {
                        imageRequestIds.removeValue(forKey: assetId)
                        images[assetId] = prepared
                        failedImageIds.remove(assetId)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    imageRequestIds.removeValue(forKey: assetId)
                    if !isDegraded && !isCancelled {
                        // Only mark as failed for a final (non-degraded) result.
                        failedImageIds.insert(assetId)
                        if let error {
                            print("Failed to load full image for \(assetId): \(error)")
                        }
                    }
                }
            }
        }
        imageRequestIds[assetId] = reqId
    }

    private func jumpDay(direction: Int) {
        let calendar = Calendar.current
        guard let center = windowCenterDay else { return }

        // Available days sorted oldest -> newest (matches pager ordering)
        let allDays = photoManager.photosByDate.keys
            .map { calendar.startOfDay(for: $0) }
            .sorted(by: <)

        guard let dayIndex = allDays.firstIndex(of: center) else { return }

        // direction: 1 = swipe left -> newer day, -1 = swipe right -> older day
        let targetIndex = dayIndex + direction
        guard targetIndex >= 0, targetIndex < allDays.count else { return }

        let targetDay = allDays[targetIndex]
        windowCenterDay = targetDay
        rebuildWindow(centerDay: targetDay, keepingAssetId: nil)
    }

    private func rebuildWindow(centerDay: Date?, keepingAssetId: String?) {
        let calendar = Calendar.current
        let center: Date
        if let centerDay {
            center = centerDay
        } else if let d = initialAsset.creationDate {
            center = calendar.startOfDay(for: d)
        } else {
            center = calendar.startOfDay(for: Date())
        }

        // Available days sorted oldest -> newest (matches pager ordering)
        let allDays = photoManager.photosByDate.keys
            .map { calendar.startOfDay(for: $0) }
            .sorted(by: <)

        // If we don't have this day loaded yet, just show the initial asset.
        guard let dayIndex = allDays.firstIndex(of: center) else {
            assets = [initialAsset]
            currentPhotoIndex = 0
            currentAssetId = initialAsset.localIdentifier
            windowCenterDay = calendar.startOfDay(for: initialAsset.creationDate ?? Date())
            return
        }

        let start = max(0, dayIndex - daysEachDirection)
        let end = min(allDays.count - 1, dayIndex + daysEachDirection)
        let windowDays = Array(allDays[start...end])

        var windowAssets: [PHAsset] = windowDays.flatMap { day in
            photoManager.photosByDate[day] ?? []
        }
        // Oldest -> newest (so swipe-left moves toward the present)
        windowAssets.sort { a, b in
            (a.creationDate ?? .distantPast) < (b.creationDate ?? .distantPast)
        }

        // Ensure the initial asset is included.
        if !windowAssets.contains(where: { $0.localIdentifier == initialAsset.localIdentifier }) {
            windowAssets.append(initialAsset)
            windowAssets.sort { a, b in
                (a.creationDate ?? .distantPast) < (b.creationDate ?? .distantPast)
            }
        }

        let targetId = keepingAssetId ?? currentAssetId

        isRebuildingWindow = true
        var txn = Transaction()
        txn.animation = nil
        withTransaction(txn) {
            assets = windowAssets

            if let idx = windowAssets.firstIndex(where: { $0.localIdentifier == targetId }) {
                currentPhotoIndex = idx
            } else {
                currentPhotoIndex = 0
            }

            if let current = windowAssets[safe: currentPhotoIndex] {
                currentAssetId = current.localIdentifier
                if let d = current.creationDate {
                    windowCenterDay = calendar.startOfDay(for: d)
                } else {
                    windowCenterDay = center
                }
            } else {
                currentAssetId = initialAsset.localIdentifier
                windowCenterDay = center
            }
        }
        isRebuildingWindow = false

        pruneImageCache()
    }

    private func maybeShiftWindowForPagingEdge() {
        // When close to the start/end, rebuild centered on current day so you can keep swiping
        // while unloading far days.
        guard let d = currentDayKey else { return }
        let nearStart = currentPhotoIndex <= 3
        let nearEnd = currentPhotoIndex >= max(0, assets.count - 4)
        if nearStart || nearEnd {
            rebuildWindow(centerDay: d, keepingAssetId: currentAssetId)
        }
    }

    private func pruneImageCache() {
        guard !assets.isEmpty else { return }

        let keepRadius = 4
        let start = max(0, currentPhotoIndex - keepRadius)
        let end = min(assets.count - 1, currentPhotoIndex + keepRadius)
        let keepIds = Set(assets[start...end].map(\.localIdentifier))

        for (id, req) in imageRequestIds where !keepIds.contains(id) {
            imageManager.cancelImageRequest(req)
            imageRequestIds.removeValue(forKey: id)
        }

        for key in images.keys where !keepIds.contains(key) {
            images.removeValue(forKey: key)
        }

        failedImageIds = failedImageIds.filter { keepIds.contains($0) }
    }

    private func recommendedTargetSize() -> CGSize {
        #if canImport(UIKit)
        let scale = UIScreen.main.scale
        let size = UIScreen.main.bounds.size
        let maxDim = max(size.width, size.height) * scale * 2.0
        return CGSize(width: maxDim, height: maxDim)
        #else
        return PHImageManagerMaximumSize
        #endif
    }

    private var currentDayKey: Date? {
        guard let current = assets[safe: currentPhotoIndex],
              let d = current.creationDate else { return nil }
        return Calendar.current.startOfDay(for: d)
    }

    private var dayAwarePageIndicator: some View {
        // Show a small window of dots around the current page and insert a divider when the day changes.
        guard !assets.isEmpty else {
            return AnyView(EmptyView())
        }

        let radius = 10
        let start = max(0, currentPhotoIndex - radius)
        let end = min(assets.count - 1, currentPhotoIndex + radius)

        return AnyView(
            HStack(spacing: 6) {
                ForEach(start...end, id: \.self) { idx in
                    Circle()
                        .fill(idx == currentPhotoIndex ? Color.white : Color.white.opacity(0.35))
                        .frame(width: idx == currentPhotoIndex ? 8 : 6, height: idx == currentPhotoIndex ? 8 : 6)

                    if idx < end {
                        let aDay = dayKey(for: idx)
                        let bDay = dayKey(for: idx + 1)
                        if aDay != nil, bDay != nil, aDay != bDay {
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

    private func dayKey(for index: Int) -> Date? {
        guard let asset = assets[safe: index],
              let d = asset.creationDate else { return nil }
        return Calendar.current.startOfDay(for: d)
    }

    private var currentDayAssets: [PHAsset] {
        guard let day = currentDayKey else { return [] }
        let calendar = Calendar.current
        return assets.filter { asset in
            guard let d = asset.creationDate else { return false }
            return calendar.startOfDay(for: d) == day
        }
        .sorted { a, b in
            (a.creationDate ?? .distantPast) < (b.creationDate ?? .distantPast)
        }
    }

    private var currentDayCount: Int {
        currentDayAssets.count
    }

    private var currentDayIndex: Int {
        guard let current = assets[safe: currentPhotoIndex] else { return 0 }
        return currentDayAssets.firstIndex(where: { $0.localIdentifier == current.localIdentifier }) ?? 0
    }
}


