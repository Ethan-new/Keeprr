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
    @StateObject private var manager = KeeprrMomentsManager()
    @State private var selectedPhoto: PHAsset?
    @State private var showPhotoModal = false
    
    var body: some View {
        NavigationView {
            contentView
                .navigationTitle("Keeprr Moments (\(manager.totalPhotoCount))")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    if manager.authorizationStatus == .notDetermined {
                        manager.requestAuthorization()
                    } else if manager.authorizationStatus == .authorized || manager.authorizationStatus == .limited {
                        // Refresh photos when view appears
                        if manager.totalPhotoCount == 0 || manager.photosByDate.isEmpty {
                            manager.loadPhotos()
                        }
                    }
                }
                .onChange(of: manager.totalPhotoCount) { oldValue, newValue in
                    // Update title when count changes
                }
                .fullScreenCover(isPresented: $showPhotoModal) {
                    photoModalView
                }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ZStack {
            if manager.authorizationStatus == .authorized || manager.authorizationStatus == .limited {
                if manager.monthsWithPhotos.isEmpty && !manager.isLoading && manager.totalPhotoCount == 0 {
                    emptyView
                } else {
                    calendarScrollView
                }
            } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
                permissionDeniedView
            } else {
                loadingView
            }
        }
    }
    
    private var calendarScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if manager.monthsWithPhotos.isEmpty {
                    // Show current month even if no photos
                    let currentMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
                    KeeprrCalendarMonthView(
                        monthYear: currentMonth,
                        photoPairsByDate: manager.photoPairsByDate,
                        monthFormatter: manager.monthFormatter,
                        onPhotoTap: handlePhotoTap,
                        manager: manager
                    )
                    .padding(.bottom, 30)
                } else {
                    ForEach(Array(manager.monthsWithPhotos.enumerated()), id: \.element) { index, monthYear in
                        KeeprrCalendarMonthView(
                            monthYear: monthYear,
                            photoPairsByDate: manager.photoPairsByDate,
                            monthFormatter: manager.monthFormatter,
                            onPhotoTap: handlePhotoTap,
                            manager: manager
                        )
                        .padding(.bottom, 30)
                    }
                }
            }
            .padding(.top, 20)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No Keeprr Moments")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Take photos with the camera to create Keeprr Moments")
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
            Text("Keeprr needs access to your photo library to display your Keeprr Moments.")
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
            Text("Loading Keeprr Moments...")
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
                    manager.deletePhoto(photo)
                    showPhotoModal = false
                    manager.loadPhotos()
                }
            )
        } else {
            // Fallback if photo is nil
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
        
        // Get photos from the manager for this day
        var dayPhotos = manager.photosByDate[dayStart]?.sorted { asset1, asset2 in
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
    
    private func handlePhotoTap(pair: PhotoPair, index: Int) {
        // Use the main photo from the pair
        selectedPhoto = pair.mainPhoto
        showPhotoModal = true
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Keeprr Calendar Month View

struct KeeprrCalendarMonthView: View {
    let monthYear: Date
    let photoPairsByDate: [Date: [PhotoPair]]
    let monthFormatter: DateFormatter
    let onPhotoTap: (PhotoPair, Int) -> Void
    @ObservedObject var manager: KeeprrMomentsManager
    
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
        let weekday = components.weekday!
        return (weekday - 1) % 7
    }
    
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(monthFormatter.string(from: monthYear))
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            
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
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                // Empty cells
                ForEach(Array(0..<firstDayOfMonth), id: \.self) { emptyIndex in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
                .id("empty-\(monthYear.timeIntervalSince1970)")
                
                // Day cells with unique IDs
                let monthID = monthYear.timeIntervalSince1970
                let days = Array(1...daysInMonth)
                ForEach(days, id: \.self) { day in
                    let dayDate = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
                    let dayStart = calendar.startOfDay(for: dayDate)
                    let isToday = calendar.isDateInToday(dayDate)
                    let pairs = photoPairsByDate[dayStart] ?? []
                    
                    KeeprrCalendarDayCell(
                        day: day,
                        pairs: pairs,
                        isToday: isToday,
                        manager: manager,
                        onPhotoTap: onPhotoTap
                    )
                    .id("\(monthID)-\(day)")
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Keeprr Calendar Day Cell

struct KeeprrCalendarDayCell: View {
    let day: Int
    let pairs: [PhotoPair]
    let isToday: Bool
    @ObservedObject var manager: KeeprrMomentsManager
    let onPhotoTap: (PhotoPair, Int) -> Void
    
    @State private var thumbnail: UIImage?
    
    var hasPhotos: Bool {
        !pairs.isEmpty
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if hasPhotos, pairs.first != nil {
                    Group {
                        if let thumbnail = thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        } else {
                            ZStack {
                                Color.gray.opacity(0.2)
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .onAppear {
                                loadThumbnail()
                            }
                        }
                    }
                    .clipped()
                    .cornerRadius(8)
                    .overlay(
                        Group {
                            if pairs.count > 1 {
                                HStack {
                                    Spacer()
                                    VStack {
                                        Text("\(pairs.count)")
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
                    )
                    .overlay(
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
                    )
                    .overlay(
                        Group {
                            if isToday {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 2)
                            }
                        }
                    )
                } else {
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
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let firstPair = pairs.first {
                    onPhotoTap(firstPair, 0)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func loadThumbnail() {
        guard let firstPair = pairs.first else { return }
        
        let cacheKey = firstPair.mainPhoto.localIdentifier
        if let cachedImage = manager.thumbnailCache[cacheKey] {
            thumbnail = cachedImage
            return
        }
        
        manager.loadThumbnail(for: firstPair.mainPhoto) { image in
            thumbnail = image
        }
    }
}

// MARK: - Keeprr Photo Modal View

struct KeeprrPhotoModalView: View {
    let initialPair: PhotoPair
    let allPairs: [PhotoPair]
    @ObservedObject var manager: KeeprrMomentsManager
    let onDelete: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var currentPairIndex: Int
    @State private var showDeleteAlert = false
    @State private var images: [String: UIImage] = [:]
    @State private var showingMainPhoto: [String: Bool] = [:] // Track per pair
    @State private var windowedPairs: [PhotoPair] = []
    @State private var windowStartIndex: Int = 0
    
    private let imageManager = PHImageManager.default()
    private let daysBuffer = 10
    
    init(initialPair: PhotoPair, allPairs: [PhotoPair], manager: KeeprrMomentsManager, onDelete: @escaping () -> Void) {
        self.initialPair = initialPair
        self.allPairs = allPairs
        self.manager = manager
        self.onDelete = onDelete
        _currentPairIndex = State(initialValue: allPairs.firstIndex(where: { $0.id == initialPair.id }) ?? 0)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if windowedPairs.isEmpty {
                VStack(spacing: 20) {
                    ProgressView()
                        .tint(.white)
                    Text("Loading photos...")
                        .foregroundColor(.white)
                }
                .onAppear {
                    updateWindow(around: currentPairIndex)
                }
            } else {
                TabView(selection: $currentPairIndex) {
                    ForEach(Array(windowedPairs.enumerated()), id: \.element.id) { index, pair in
                        ZStack {
                            Color.black
                            
                            // Determine which photo is on top
                            let isMainOnTop = showingMainPhoto[pair.id] ?? true
                            let bottomPhoto = isMainOnTop ? (pair.overlayPhoto ?? pair.mainPhoto) : pair.mainPhoto
                            let topPhoto = isMainOnTop ? pair.mainPhoto : (pair.overlayPhoto ?? pair.mainPhoto)
                            
                            // Bottom photo (background)
                            let bottomPhotoId = bottomPhoto.localIdentifier
                            if let bottomImage = images[bottomPhotoId] {
                                Image(uiImage: bottomImage)
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
                                    loadFullImage(for: bottomPhoto)
                                }
                            }
                            
                            // Top photo (overlay) - only show if there's an overlay photo
                            if let overlayPhoto = pair.overlayPhoto {
                                let topPhotoId = topPhoto.localIdentifier
                                if let topImage = images[topPhotoId] {
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            
                                            Button(action: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    showingMainPhoto[pair.id] = !(showingMainPhoto[pair.id] ?? true)
                                                }
                                            }) {
                                                Image(uiImage: topImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(
                                                        width: UIScreen.main.bounds.width * 0.35,
                                                        height: UIScreen.main.bounds.width * 0.47
                                                    )
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                                    )
                                                    .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 5)
                                                    .rotationEffect(.degrees(isMainOnTop ? -8 : 8))
                                                    .offset(x: isMainOnTop ? -20 : 20, y: isMainOnTop ? -30 : -30)
                                            }
                                            .padding(.trailing, 30)
                                            .padding(.bottom, 80)
                                        }
                                    }
                                } else {
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            ProgressView()
                                                .tint(.white)
                                                .frame(
                                                    width: UIScreen.main.bounds.width * 0.35,
                                                    height: UIScreen.main.bounds.width * 0.47
                                                )
                                                .padding(.trailing, 30)
                                                .padding(.bottom, 80)
                                        }
                                    }
                                    .onAppear {
                                        loadFullImage(for: topPhoto)
                                    }
                                }
                            }
                        }
                        .tag(windowStartIndex + index)
                        .onAppear {
                            // Initialize showingMainPhoto for this pair if not set
                            if showingMainPhoto[pair.id] == nil {
                                showingMainPhoto[pair.id] = true
                            }
                            // Load both photos
                            loadFullImage(for: pair.mainPhoto)
                            if let overlay = pair.overlayPhoto {
                                loadFullImage(for: overlay)
                            }
                        }
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .onChange(of: currentPairIndex) { oldValue, newValue in
                    let globalIndex = newValue
                    if globalIndex >= 0 && globalIndex < allPairs.count {
                        let currentPair = allPairs[globalIndex]
                        
                        // Initialize showingMainPhoto for this pair if not set
                        if showingMainPhoto[currentPair.id] == nil {
                            showingMainPhoto[currentPair.id] = true
                        }
                        
                        // Check if we need to update window
                        if let currentDate = currentPair.mainPhoto.creationDate {
                            let calendar = Calendar.current
                            let startDate = calendar.date(byAdding: .day, value: -daysBuffer, to: currentDate)!
                            let endDate = calendar.date(byAdding: .day, value: daysBuffer, to: currentDate)!
                            
                            let windowStart = windowedPairs.first?.mainPhoto.creationDate ?? currentDate
                            let windowEnd = windowedPairs.last?.mainPhoto.creationDate ?? currentDate
                            
                            if windowStart < startDate || windowEnd > endDate {
                                updateWindow(around: globalIndex)
                            }
                        }
                        
                        // Load current photo
                        loadFullImage(for: currentPair.mainPhoto)
                        if let overlay = currentPair.overlayPhoto {
                            loadFullImage(for: overlay)
                        }
                    }
                }
            }
            
            // Header
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
                    
                    VStack(spacing: 4) {
                        if currentPairIndex >= 0 && currentPairIndex < allPairs.count,
                           let currentPair = allPairs[safe: currentPairIndex] {
                            let isShowingMain = showingMainPhoto[currentPair.id] ?? true
                            let photoToShow = isShowingMain ? currentPair.mainPhoto : (currentPair.overlayPhoto ?? currentPair.mainPhoto)
                            
                            if let creationDate = photoToShow.creationDate {
                                Text(creationDate.formatted(date: .long, time: .omitted))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(creationDate.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                // Day photo counter
                                let dayPairs = getDayPairs(for: currentPair)
                                if dayPairs.count > 1 {
                                    if let position = dayPairs.firstIndex(where: { $0.id == currentPair.id }) {
                                        Text("\(position + 1) of \(dayPairs.count)")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.7))
                                            .padding(.top, 2)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button(role: .destructive, action: {
                            showDeleteAlert = true
                        }) {
                            Label("Delete Memory", systemImage: "trash")
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
                
                // Bottom controls
                if currentPairIndex >= 0 && currentPairIndex < allPairs.count,
                   let currentPair = allPairs[safe: currentPairIndex],
                   currentPair.overlayPhoto != nil {
                    VStack(spacing: 8) {
                        Text("Tap the top photo to switch views")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                    }
                    .padding(.bottom, 60)
                }
            }
        }
        .onAppear {
            updateWindow(around: currentPairIndex)
            if currentPairIndex >= 0 && currentPairIndex < allPairs.count {
                let currentPair = allPairs[currentPairIndex]
                showingMainPhoto[currentPair.id] = true
                loadFullImage(for: currentPair.mainPhoto)
                if let overlay = currentPair.overlayPhoto {
                    loadFullImage(for: overlay)
                }
            }
        }
        .alert("Delete Memory", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if currentPairIndex >= 0 && currentPairIndex < allPairs.count {
                    let currentPair = allPairs[currentPairIndex]
                    manager.deletePhoto(currentPair.mainPhoto)
                    if let overlay = currentPair.overlayPhoto {
                        manager.deletePhoto(overlay)
                    }
                    onDelete()
                    dismiss()
                }
            }
        } message: {
            if currentPairIndex >= 0 && currentPairIndex < allPairs.count,
               let currentPair = allPairs[safe: currentPairIndex],
               currentPair.overlayPhoto != nil {
                Text("Deleting this memory will remove both pictures from your camera roll. This action cannot be undone.")
            } else {
                Text("Deleting this memory will remove the photo from your camera roll. This action cannot be undone.")
            }
        }
    }
    
    private func updateWindow(around index: Int) {
        guard index >= 0 && index < allPairs.count else { return }
        
        let currentPair = allPairs[index]
        guard let currentDate = currentPair.mainPhoto.creationDate else { return }
        
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -daysBuffer, to: currentDate)!
        let endDate = calendar.date(byAdding: .day, value: daysBuffer, to: currentDate)!
        
        let windowPairs = allPairs.filter { pair in
            guard let date = pair.mainPhoto.creationDate else { return false }
            return date >= startDate && date <= endDate
        }
        
        windowedPairs = windowPairs
        if let firstPair = windowPairs.first,
           let firstIndex = allPairs.firstIndex(where: { $0.id == firstPair.id }) {
            windowStartIndex = firstIndex
        }
        
        // Adjust current index to window position
        if let currentPair = allPairs[safe: index],
           let windowIndex = windowPairs.firstIndex(where: { $0.id == currentPair.id }) {
            currentPairIndex = windowStartIndex + windowIndex
        }
    }
    
    private func getDayPairs(for pair: PhotoPair) -> [PhotoPair] {
        guard let date = pair.mainPhoto.creationDate else { return [pair] }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        
        return allPairs.filter { otherPair in
            guard let otherDate = otherPair.mainPhoto.creationDate else { return false }
            return calendar.isDate(otherDate, inSameDayAs: dayStart)
        }
    }
    
    private func loadFullImage(for asset: PHAsset) {
        let assetId = asset.localIdentifier
        guard images[assetId] == nil else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isSynchronous = false
        
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


