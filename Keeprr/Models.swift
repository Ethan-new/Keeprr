//
//  Models.swift
//  Keeprr
//
//  Created by Ethan Um on 2026-01-04.
//

import Photos

// MARK: - Keeprr Moments Data Structures

struct PhotoPair: Identifiable {
    let id: String
    let mainPhoto: PHAsset
    var overlayPhoto: PHAsset?
    let timestamp: TimeInterval
}

struct KeeprrPhotoData: Codable {
    let id: String
    let uri: String
    let filename: String?
    let creationTime: TimeInterval
    let takenAt: TimeInterval
}


