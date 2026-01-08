//
//  KeeprrMomentsManager.swift
//  Keeprr
//
//  Created by Ethan Um on 2026-01-04.
//

import SwiftUI
import Photos
import Combine

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Keeprr Moments Manager

class KeeprrMomentsManager: ObservableObject {
    @Published var moments: [Moment] = []
    @Published var momentsByDate: [Date: [Moment]] = [:]
    @Published var momentAssets: [String: (front: PHAsset?, back: PHAsset?)] = [:]
    @Published var isLoading = false
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    private let momentStore = MomentStore.shared
    private var cancellables = Set<AnyCancellable>()
    
    let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    // Cache monthsWithMoments to avoid recalculating
    private var cachedMonthsWithMoments: [Date]?
    
    var monthsWithMoments: [Date] {
        if let cached = cachedMonthsWithMoments {
            return cached
        }
        let calendar = Calendar.current
        let monthSet = Set(momentsByDate.keys.map { calendar.startOfDay(for: calendar.date(from: calendar.dateComponents([.year, .month], from: $0))!) })
        let months = Array(monthSet).sorted(by: >)
        cachedMonthsWithMoments = months
        return months
    }
    
    init() {
        // Observe moment store changes
        momentStore.$moments
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newMoments in
                self?.moments = newMoments
                self?.groupMomentsByDate()
                // Only attempt to resolve PHAssets when we have photo permission.
                if self?.authorizationStatus == .authorized || self?.authorizationStatus == .limited {
                    self?.loadAssetsForMoments()
                }
            }
            .store(in: &cancellables)
        
        // Load initial moments
        moments = momentStore.moments
        groupMomentsByDate()
        
        // Establish current permission and load assets when available.
        requestAuthorization()
    }
    
    func requestAuthorization() {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = currentStatus
        
        if currentStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    if status == .authorized || status == .limited {
                        self?.loadAssetsForMoments()
                    } else {
                        // Can't load assets without permission
                        self?.isLoading = false
                    }
                }
            }
        } else if currentStatus == .authorized || currentStatus == .limited {
            loadAssetsForMoments()
        } else {
            isLoading = false
        }
    }
    
    private func groupMomentsByDate() {
        let calendar = Calendar.current
        var grouped: [Date: [Moment]] = [:]
        
        for moment in moments {
            let dayStart = calendar.startOfDay(for: moment.createdAt)
            if grouped[dayStart] == nil {
                grouped[dayStart] = []
            }
            grouped[dayStart]?.append(moment)
        }
        
        // Sort moments within each day (newest first)
        for (date, dayMoments) in grouped {
            grouped[date] = dayMoments.sorted { $0.createdAt > $1.createdAt }
        }
        
        momentsByDate = grouped
        cachedMonthsWithMoments = nil // Invalidate cache
    }
    
    private func loadAssetsForMoments() {
        // Don't try to fetch assets until we have photo permission.
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
            }
            return
        }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var newMomentAssets: [String: (front: PHAsset?, back: PHAsset?)] = [:]
            var momentsToDelete: [String] = []
            
            for moment in self.moments {
                let frontAsset = PHAsset.fetchAssets(withLocalIdentifiers: [moment.frontAssetId], options: nil).firstObject
                let backAsset = PHAsset.fetchAssets(withLocalIdentifiers: [moment.backAssetId], options: nil).firstObject
                
                // If either asset is missing, the moment is incomplete - mark for deletion
                if frontAsset == nil || backAsset == nil {
                    momentsToDelete.append(moment.id)
                } else {
                    newMomentAssets[moment.id] = (front: frontAsset, back: backAsset)
                }
            }
            
            DispatchQueue.main.async {
                // Delete moments with missing assets
                if !momentsToDelete.isEmpty {
                    for momentId in momentsToDelete {
                        self.momentStore.deleteMoment(withId: momentId)
                    }
                    // The moment store's published property will trigger the sink in init,
                    // which will update moments and reload assets
                    // Note: isLoading will be set to false in the next loadAssetsForMoments call
                } else {
                    self.momentAssets = newMomentAssets
                    self.isLoading = false
                }
            }
        }
    }
    
    #if canImport(UIKit)
    func loadThumbnail(for asset: PHAsset?, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        guard let asset = asset else {
            completion(nil)
            return
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isSynchronous = false
        options.isNetworkAccessAllowed = false
        
        let scale = UIScreen.main.scale
        let scaledSize = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: scaledSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    func loadFullImage(for asset: PHAsset?, completion: @escaping (UIImage?) -> Void) {
        guard let asset = asset else {
            completion(nil)
            return
        }
        
        let options = PHImageRequestOptions()
        // Important: return a single callback (DispatchGroup callers assume 1 completion).
        // Opportunistic may callback multiple times (degraded then final), which can crash callers.
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        options.version = .current
        
        let screenSize = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        // Keep memory bounded: request a high-quality *screen-sized* image, not full-res.
        let desiredMax = max(screenSize.width, screenSize.height) * scale * 1.5
        let assetMax = CGFloat(max(asset.pixelWidth, asset.pixelHeight))
        // Never request a thumbnail larger than the original asset (prevents CGImageSource warnings).
        let targetMax = max(1, min(desiredMax, assetMax))
        let targetSize = CGSize(width: targetMax, height: targetMax)
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            guard let image else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Reduce swipe stutter: pre-decode off the main thread.
            DispatchQueue.global(qos: .userInitiated).async {
                let prepared = image.preparingForDisplay() ?? image
                DispatchQueue.main.async {
                    completion(prepared)
                }
            }
        }
    }
    #endif
    
    func getAssets(for momentId: String) -> (front: PHAsset?, back: PHAsset?) {
        return momentAssets[momentId] ?? (front: nil, back: nil)
    }
}
