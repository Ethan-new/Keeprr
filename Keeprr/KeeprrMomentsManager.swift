//
//  KeeprrMomentsManager.swift
//  Keeprr
//
//  Created by Ethan Um on 2026-01-04.
//

import SwiftUI
import Photos

// MARK: - Keeprr Moments Manager

class KeeprrMomentsManager: ObservableObject {
    @Published var photosByDate: [Date: [PHAsset]] = [:]
    @Published var photoPairsByDate: [Date: [PhotoPair]] = [:]
    @Published var allPhotoPairs: [PhotoPair] = []
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var thumbnailCache: [String: UIImage] = [:]
    @Published var isLoading = false
    
    let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private let imageManager = PHImageManager.default()
    private let thumbnailSize = CGSize(width: 80, height: 80)
    private let maxCacheSize = 500
    private let keeprrPhotosKey = "keeprrPhotos"
    
    var totalPhotoCount: Int {
        photosByDate.values.reduce(0) { $0 + $1.count }
    }
    
    var monthsWithPhotos: [Date] {
        let calendar = Calendar.current
        let monthSet = Set(photosByDate.keys.map { 
            calendar.startOfDay(for: calendar.date(from: calendar.dateComponents([.year, .month], from: $0))!) 
        })
        return Array(monthSet).sorted(by: >)
    }
    
    func requestAuthorization() {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = currentStatus
        
        if currentStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    if status == .authorized || status == .limited {
                        self?.loadPhotos()
                    }
                }
            }
        } else if currentStatus == .authorized || currentStatus == .limited {
            loadPhotos()
        }
    }
    
    func loadPhotos() {
        guard !isLoading else { return }
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Load tracked photos from UserDefaults
            var trackedPhotos: [KeeprrPhotoData] = []
            if let data = UserDefaults.standard.data(forKey: self.keeprrPhotosKey),
               let decoded = try? JSONDecoder().decode([KeeprrPhotoData].self, from: data) {
                trackedPhotos = decoded
            }
            
            // Also check for "Keeprr" album
            var albumPhotos: [PHAsset] = []
            do {
                let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
                var keeprrAlbum: PHAssetCollection?
                
                albums.enumerateObjects { collection, _, stop in
                    if collection.localizedTitle == "Keeprr" {
                        keeprrAlbum = collection
                        stop.pointee = true
                    }
                }
                
                if let album = keeprrAlbum {
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                    let assets = PHAsset.fetchAssets(in: album, options: fetchOptions)
                    
                    let trackedIds = Set(trackedPhotos.map { $0.id })
                    assets.enumerateObjects { asset, _, _ in
                        if !trackedIds.contains(asset.localIdentifier) {
                            albumPhotos.append(asset)
                        }
                    }
                }
            }
            
            // Convert tracked photos to PHAssets
            var allAssets: [PHAsset] = []
            let trackedIds = trackedPhotos.map { $0.id }
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            for trackedId in trackedIds {
                if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [trackedId], options: nil).firstObject {
                    allAssets.append(asset)
                }
            }
            
            // Add album photos
            allAssets.append(contentsOf: albumPhotos)
            
            // Group by date
            var grouped: [Date: [PHAsset]] = [:]
            let calendar = Calendar.current
            
            for asset in allAssets {
                if let creationDate = asset.creationDate {
                    let dayStart = calendar.startOfDay(for: creationDate)
                    if grouped[dayStart] == nil {
                        grouped[dayStart] = []
                    }
                    grouped[dayStart]?.append(asset)
                }
            }
            
            // Sort photos within each day
            for (date, photos) in grouped {
                grouped[date] = photos.sorted { asset1, asset2 in
                    guard let date1 = asset1.creationDate, let date2 = asset2.creationDate else { return false }
                    return date1 < date2
                }
            }
            
            // Create photo pairs
            var pairsByDate: [Date: [PhotoPair]] = [:]
            var allPairs: [PhotoPair] = []
            
            for (date, photos) in grouped {
                let dayPairs = self.createPhotoPairs(from: photos)
                pairsByDate[date] = dayPairs
                allPairs.append(contentsOf: dayPairs)
            }
            
            // Sort all pairs chronologically
            allPairs.sort { $0.timestamp < $1.timestamp }
            
            DispatchQueue.main.async {
                print("📸 Keeprr Moments: Loaded \(allAssets.count) assets, \(grouped.count) days with photos, \(allPairs.count) photo pairs")
                self.photosByDate = grouped
                self.photoPairsByDate = pairsByDate
                self.allPhotoPairs = allPairs
                self.isLoading = false
            }
        }
    }
    
    private func createPhotoPairs(from photos: [PHAsset]) -> [PhotoPair] {
        guard !photos.isEmpty else { return [] }
        
        var pairs: [PhotoPair] = []
        var usedPhotos = Set<String>()
        
        for i in 0..<photos.count {
            let currentPhoto = photos[i]
            if usedPhotos.contains(currentPhoto.localIdentifier) { continue }
            
            var pairedPhoto: PHAsset?
            
            // Look for a photo taken within 10 seconds
            if let currentDate = currentPhoto.creationDate {
                for j in (i + 1)..<photos.count {
                    if usedPhotos.contains(photos[j].localIdentifier) { continue }
                    
                    if let otherDate = photos[j].creationDate {
                        let timeDiff = abs(otherDate.timeIntervalSince(currentDate))
                        if timeDiff <= 10.0 { // 10 seconds
                            pairedPhoto = photos[j]
                            usedPhotos.insert(photos[j].localIdentifier)
                            break
                        }
                    }
                }
            }
            
            pairs.append(PhotoPair(
                id: currentPhoto.localIdentifier,
                mainPhoto: currentPhoto,
                overlayPhoto: pairedPhoto,
                timestamp: currentPhoto.creationDate?.timeIntervalSince1970 ?? 0
            ))
            
            usedPhotos.insert(currentPhoto.localIdentifier)
        }
        
        return pairs
    }
    
    func loadThumbnail(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = asset.localIdentifier
        
        if let cachedImage = thumbnailCache[cacheKey] {
            completion(cachedImage)
            return
        }
        
        if thumbnailCache.count >= maxCacheSize {
            let keysToRemove = Array(thumbnailCache.keys.prefix(maxCacheSize / 5))
            for key in keysToRemove {
                thumbnailCache.removeValue(forKey: key)
            }
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isSynchronous = false
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
                    // Remove from UserDefaults
                    if var trackedPhotos = self?.getTrackedPhotos() {
                        trackedPhotos.removeAll { $0.id == asset.localIdentifier }
                        self?.saveTrackedPhotos(trackedPhotos)
                    }
                    
                    // Remove from local state
                    let calendar = Calendar.current
                    if let creationDate = asset.creationDate {
                        let dayStart = calendar.startOfDay(for: creationDate)
                        if var dayPhotos = self?.photosByDate[dayStart] {
                            dayPhotos.removeAll { $0.localIdentifier == asset.localIdentifier }
                            if dayPhotos.isEmpty {
                                self?.photosByDate.removeValue(forKey: dayStart)
                                self?.photoPairsByDate.removeValue(forKey: dayStart)
                            } else {
                                self?.photosByDate[dayStart] = dayPhotos
                                // Regenerate pairs for this day
                                if let photos = self?.photosByDate[dayStart] {
                                    self?.photoPairsByDate[dayStart] = self?.createPhotoPairs(from: photos) ?? []
                                }
                            }
                        }
                    }
                    
                    // Update all pairs
                    self?.allPhotoPairs.removeAll { $0.mainPhoto.localIdentifier == asset.localIdentifier || $0.overlayPhoto?.localIdentifier == asset.localIdentifier }
                    self?.thumbnailCache.removeValue(forKey: asset.localIdentifier)
                }
            }
        }
    }
    
    func savePhoto(_ asset: PHAsset) {
        guard let creationDate = asset.creationDate else { return }
        
        var trackedPhotos = getTrackedPhotos()
        let photoData = KeeprrPhotoData(
            id: asset.localIdentifier,
            uri: asset.localIdentifier, // Using identifier as URI
            filename: nil,
            creationTime: creationDate.timeIntervalSince1970,
            takenAt: creationDate.timeIntervalSince1970
        )
        
        // Check if already exists
        if !trackedPhotos.contains(where: { $0.id == asset.localIdentifier }) {
            trackedPhotos.append(photoData)
            saveTrackedPhotos(trackedPhotos)
        }
    }
    
    private func getTrackedPhotos() -> [KeeprrPhotoData] {
        if let data = UserDefaults.standard.data(forKey: keeprrPhotosKey),
           let decoded = try? JSONDecoder().decode([KeeprrPhotoData].self, from: data) {
            return decoded
        }
        return []
    }
    
    private func saveTrackedPhotos(_ photos: [KeeprrPhotoData]) {
        if let encoded = try? JSONEncoder().encode(photos) {
            UserDefaults.standard.set(encoded, forKey: keeprrPhotosKey)
        }
    }
}


