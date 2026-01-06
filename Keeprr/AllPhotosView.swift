//
//  AllPhotosView.swift
//  Keeprr
//
//  Created by Ethan Um on 2026-01-04.
//

import SwiftUI
import Photos

// MARK: - All Photos View

struct AllPhotosView: View {
    @StateObject private var photoManager = PhotoManager()
    @State private var selectedPhoto: PHAsset?
    @State private var showPhotoModal = false
    
    var body: some View {
        NavigationView {
            contentView
                .navigationTitle("All Photos (\(photoManager.totalPhotoCount))")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    photoManager.requestAuthorization()
                }
                .fullScreenCover(isPresented: $showPhotoModal) {
                    photoModalView
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
    
    @ViewBuilder
    private var photoModalView: some View {
        if let photo = selectedPhoto {
            let dayPhotos = getDayPhotos(for: photo)
            // Ensure we always have at least the selected photo
            let safeDayPhotos = dayPhotos.isEmpty ? [photo] : dayPhotos
            let actualIndex = safeDayPhotos.firstIndex(where: { $0.localIdentifier == photo.localIdentifier }) ?? 0
            
            PhotoViewerModal(
                photo: photo,
                dayPhotos: safeDayPhotos,
                currentIndex: actualIndex,
                onDelete: {
                    photoManager.deletePhoto($0)
                    showPhotoModal = false
                }
            )
        } else {
            // Fallback if photo is nil - this shouldn't happen but handle it gracefully
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Unable to load photo")
                        .foregroundColor(.white)
                        .font(.headline)
                    Text("Please try again")
                        .foregroundColor(.white.opacity(0.7))
                    Button("Close") {
                        showPhotoModal = false
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                }
            }
        }
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
        selectedPhoto = photo
        showPhotoModal = true
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
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
    let photo: PHAsset
    let dayPhotos: [PHAsset] // Photos from the same day, sorted chronologically
    let currentIndex: Int
    let onDelete: (PHAsset) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var currentPhotoIndex: Int
    @State private var showDeleteAlert = false
    @State private var images: [String: UIImage] = [:] // Use asset ID as key
    
    private let imageManager = PHImageManager.default()
    
    init(photo: PHAsset, dayPhotos: [PHAsset], currentIndex: Int, onDelete: @escaping (PHAsset) -> Void) {
        self.photo = photo
        self.dayPhotos = dayPhotos
        self.currentIndex = currentIndex
        self.onDelete = onDelete
        _currentPhotoIndex = State(initialValue: currentIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if dayPhotos.isEmpty {
                VStack(spacing: 20) {
                    ProgressView()
                        .tint(.white)
                    Text("Loading photos...")
                        .foregroundColor(.white)
                }
            } else {
                TabView(selection: $currentPhotoIndex) {
                    ForEach(Array(dayPhotos.enumerated()), id: \.element.localIdentifier) { index, asset in
                        ZStack {
                            Color.black
                            
                            if let image = images[asset.localIdentifier] {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                VStack(spacing: 20) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Loading...")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .onAppear {
                                    loadFullImage(for: asset)
                                }
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            
            // Header with date and time
            VStack {
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
                        if currentPhotoIndex < dayPhotos.count,
                           let currentPhoto = dayPhotos[safe: currentPhotoIndex],
                           let creationDate = currentPhoto.creationDate {
                            Text(creationDate.formatted(date: .long, time: .omitted))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Text(creationDate.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                            
                            // Photo counter (e.g., "1 of 5")
                            if dayPhotos.count > 1 {
                                Text("\(currentPhotoIndex + 1) of \(dayPhotos.count)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.top, 2)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Menu button
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
                .padding()
                .padding(.top, 50)
                
                Spacer()
            }
        }
        .onAppear {
            // Ensure currentPhotoIndex is within bounds
            let safeIndex = min(max(0, currentPhotoIndex), dayPhotos.count - 1)
            if safeIndex >= 0 && safeIndex < dayPhotos.count {
                currentPhotoIndex = safeIndex
                loadFullImage(for: dayPhotos[safeIndex])
                // Preload adjacent images
                if safeIndex > 0 {
                    loadFullImage(for: dayPhotos[safeIndex - 1])
                }
                if safeIndex < dayPhotos.count - 1 {
                    loadFullImage(for: dayPhotos[safeIndex + 1])
                }
            }
        }
        .onChange(of: currentPhotoIndex) { oldValue, newValue in
            // Update header when photo changes
            if newValue < dayPhotos.count {
                loadFullImage(for: dayPhotos[newValue])
                // Preload adjacent images
                if newValue > 0 {
                    loadFullImage(for: dayPhotos[newValue - 1])
                }
                if newValue < dayPhotos.count - 1 {
                    loadFullImage(for: dayPhotos[newValue + 1])
                }
            }
        }
        .alert("Delete Photo", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let assetToDelete = dayPhotos[safe: currentPhotoIndex] {
                    onDelete(assetToDelete)
                } else {
                    onDelete(photo)
                }
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this photo? This action cannot be undone.")
        }
    }
    
    private func loadFullImage(for asset: PHAsset) {
        let assetId = asset.localIdentifier
        guard images[assetId] == nil else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isSynchronous = false
        
        // Request full resolution image (use a very large size to get full quality)
        let screenSize = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: screenSize.width * scale * 3, height: screenSize.height * scale * 3)
        
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    images[assetId] = image
                }
            }
        }
    }
}


