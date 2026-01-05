//
//  PhotoManager.swift
//  Keeprr
//
//  Created by Ethan Um on 2026-01-04.
//

import SwiftUI
import Photos

// MARK: - Photo Manager

class PhotoManager: ObservableObject {
    @Published var photosByDate: [Date: [PHAsset]] = [:]
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var totalPhotoCount: Int = 0
    @Published var thumbnailCache: [String: UIImage] = [:]
    @Published var isLoadingMore = false
    
    let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private let imageManager = PHImageManager.default()
    // Thumbnail size optimized for calendar cells - reduced for better performance
    private let thumbnailSize = CGSize(width: 80, height: 80)
    
    var loadedPhotoCount = 0
    private var allPhotosFetchResult: PHFetchResult<PHAsset>?
    private let batchSize = 200
    private let initialLoadLimit = 1000 // Load first 1000 photos initially
    
    // Cache monthsWithPhotos to avoid recalculating
    private var cachedMonthsWithPhotos: [Date]?
    
    var monthsWithPhotos: [Date] {
        if let cached = cachedMonthsWithPhotos {
            return cached
        }
        let calendar = Calendar.current
        let monthSet = Set(photosByDate.keys.map { calendar.startOfDay(for: calendar.date(from: calendar.dateComponents([.year, .month], from: $0))!) })
        let months = Array(monthSet).sorted(by: >)
        cachedMonthsWithPhotos = months
        return months
    }
    
    // Maximum cache size to prevent unbounded growth
    private let maxCacheSize = 500
    
    func requestAuthorization() {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = currentStatus
        
        if currentStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    if status == .authorized || status == .limited {
                        self?.fetchPhotos()
                    }
                }
            }
        } else if currentStatus == .authorized || currentStatus == .limited {
            fetchPhotos()
        }
    }
    
    func fetchPhotos() {
        // Perform heavy work on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            let photoCount = allPhotos.count
            
            // Store the fetch result for pagination
            DispatchQueue.main.async {
                self.allPhotosFetchResult = allPhotos
                self.totalPhotoCount = photoCount
                self.loadedPhotoCount = 0
            }
            
            // Load initial batches up to 1000 photos (or all if less than 1000)
            let initialCount = min(self.initialLoadLimit, photoCount)
            self.loadInitialPhotos(upTo: initialCount)
        }
    }
    
    private func loadInitialPhotos(upTo count: Int) {
        // Load photos in batches up to the initial limit
        let batches = (count + batchSize - 1) / batchSize // Ceiling division
        
        func loadNextBatch(currentIndex: Int) {
            guard currentIndex < batches else { return }
            
            let startIndex = currentIndex * batchSize
            let batchCount = min(batchSize, count - startIndex)
            
            self.loadPhotosBatch(startIndex: startIndex, count: batchCount) {
                let nextIndex = currentIndex + 1
                if nextIndex < batches {
                    // Load next batch after a small delay to avoid blocking
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
                        loadNextBatch(currentIndex: nextIndex)
                    }
                }
            }
        }
        
        loadNextBatch(currentIndex: 0)
    }
    
    func loadMorePhotos() {
        guard !isLoadingMore,
              allPhotosFetchResult != nil,
              loadedPhotoCount < totalPhotoCount else {
            return
        }
        
        isLoadingMore = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let startIndex = self.loadedPhotoCount
            let remainingCount = self.totalPhotoCount - startIndex
            let batchCount = min(self.batchSize, remainingCount)
            
            self.loadPhotosBatch(startIndex: startIndex, count: batchCount)
        }
    }
    
    private func loadPhotosBatch(startIndex: Int, count: Int, completion: (() -> Void)? = nil) {
        guard let fetchResult = allPhotosFetchResult else {
            completion?()
            return
        }
        
        var grouped: [Date: [PHAsset]] = [:]
        let calendar = Calendar.current
        
        // Enumerate the batch
        let endIndex = min(startIndex + count, fetchResult.count)
        for i in startIndex..<endIndex {
            let asset = fetchResult.object(at: i)
            if let creationDate = asset.creationDate {
                let dayStart = calendar.startOfDay(for: creationDate)
                if grouped[dayStart] == nil {
                    grouped[dayStart] = []
                }
                grouped[dayStart]?.append(asset)
            }
        }
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion?()
                return
            }
            
            // Merge new photos with existing ones
            for (date, photos) in grouped {
                if self.photosByDate[date] == nil {
                    self.photosByDate[date] = []
                }
                // Add photos that aren't already in the array
                let existingIds = Set(self.photosByDate[date]!.map { $0.localIdentifier })
                let newPhotos = photos.filter { !existingIds.contains($0.localIdentifier) }
                self.photosByDate[date]?.append(contentsOf: newPhotos)
            }
            
            self.loadedPhotoCount = endIndex
            self.isLoadingMore = false
            
            // Invalidate months cache since we added new photos
            self.cachedMonthsWithPhotos = nil
            
            completion?()
        }
    }
    
    func loadThumbnail(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = asset.localIdentifier
        
        // Check cache first
        if let cachedImage = thumbnailCache[cacheKey] {
            completion(cachedImage)
            return
        }
        
        // Enforce cache size limit - remove oldest entries if needed
        if thumbnailCache.count >= maxCacheSize {
            // Remove 20% of oldest entries (simple FIFO approach)
            let keysToRemove = Array(thumbnailCache.keys.prefix(maxCacheSize / 5))
            for key in keysToRemove {
                thumbnailCache.removeValue(forKey: key)
            }
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isSynchronous = false
        // Use low quality for faster loading
        options.isNetworkAccessAllowed = false
        
        imageManager.requestImage(
            for: asset,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self?.thumbnailCache[cacheKey] = image
                    completion(image)
                }
            } else {
                completion(nil)
            }
        }
    }
    
    func deletePhoto(_ asset: PHAsset) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    // Remove from local state
                    let calendar = Calendar.current
                    if let creationDate = asset.creationDate {
                        let dayStart = calendar.startOfDay(for: creationDate)
                        if var dayPhotos = self?.photosByDate[dayStart] {
                            dayPhotos.removeAll { $0.localIdentifier == asset.localIdentifier }
                            if dayPhotos.isEmpty {
                                self?.photosByDate.removeValue(forKey: dayStart)
                            } else {
                                self?.photosByDate[dayStart] = dayPhotos
                            }
                        }
                    }
                    self?.thumbnailCache.removeValue(forKey: asset.localIdentifier)
                    self?.totalPhotoCount = max(0, self?.totalPhotoCount ?? 0 - 1)
                    // Invalidate months cache
                    self?.cachedMonthsWithPhotos = nil
                }
            }
        }
    }
}


