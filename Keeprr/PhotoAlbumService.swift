//
//  PhotoAlbumService.swift
//  Keeprr
//
//  Created by Ethan Um on 2026-01-04.
//

import Photos
#if canImport(UIKit)
import UIKit
#endif

final class PhotoAlbumService {
    static let shared = PhotoAlbumService()
    private init() {}

    // Change this to whatever you want
    private let albumName = "Keeprr Moments"

    // Call once early (e.g., onAppear) so you aren't prompting during capture.
    func requestAuth() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited { return true }
        
        let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return newStatus == .authorized || newStatus == .limited
    }
    
    // Legacy method name for compatibility
    func requestAuthReadWrite() async -> Bool {
        return await requestAuth()
    }

    @MainActor
    func saveImageDataToAlbum(_ data: Data, uniformTypeIdentifier: String) async throws -> String {
        let album = try await ensureAlbum()
        
        return try await withCheckedThrowingContinuation { cont in
            var createdId: String?
            
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetCreationRequest.forAsset()
                let opts = PHAssetResourceCreationOptions()
                opts.uniformTypeIdentifier = uniformTypeIdentifier
                req.addResource(with: .photo, data: data, options: opts)
                
                createdId = req.placeholderForCreatedAsset?.localIdentifier
                
                if let change = PHAssetCollectionChangeRequest(for: album),
                   let ph = req.placeholderForCreatedAsset {
                    change.addAssets([ph] as NSArray)
                }
            }, completionHandler: { success, error in
                if let error = error {
                    print("PhotoAlbumService: Save image data error - \(error.localizedDescription)")
                    cont.resume(throwing: error)
                    return
                }
                guard success, let id = createdId else {
                    cont.resume(throwing: NSError(domain: "PhotoAlbumService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Save failed"]))
                    return
                }
                cont.resume(returning: id)
            })
        }
    }

    @MainActor
    func saveJPEGToAlbum(_ jpegData: Data) async throws -> String {
        try await saveImageDataToAlbum(jpegData, uniformTypeIdentifier: "public.jpeg")
    }
    

    // MARK: - Album creation/fetch

    private func ensureAlbum() async throws -> PHAssetCollection {
        if let existing = fetchAlbum(named: albumName) { return existing }
        
        return try await withCheckedThrowingContinuation { cont in
            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumName)
                placeholder = req.placeholderForCreatedAssetCollection
            }, completionHandler: { success, error in
                if let error = error {
                    print("PhotoAlbumService: Album creation error - \(error.localizedDescription)")
                    cont.resume(throwing: error)
                    return
                }
                guard success, let ph = placeholder else {
                    cont.resume(throwing: NSError(domain: "PhotoAlbumService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Album creation failed"]))
                    return
                }
                let fetch = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [ph.localIdentifier], options: nil)
                guard let album = fetch.firstObject else {
                    cont.resume(throwing: NSError(domain: "PhotoAlbumService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Album fetch failed"]))
                    return
                }
                cont.resume(returning: album)
            })
        }
    }

    private func fetchAlbum(named name: String) -> PHAssetCollection? {
        let fetch = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        var result: PHAssetCollection?
        fetch.enumerateObjects { collection, _, stop in
            if collection.localizedTitle == name {
                result = collection
                stop.pointee = true
            }
        }
        return result
    }
}

