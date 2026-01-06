//
//  Models.swift
//  Keeprr
//
//  Created by Ethan Um on 2026-01-04.
//

import Photos
import Foundation

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

// MARK: - Moment Model

struct Moment: Codable, Identifiable {
    let id: String
    let createdAt: Date
    let frontAssetId: String
    let backAssetId: String
}

// MARK: - Moment Store

final class MomentStore: ObservableObject {
    static let shared = MomentStore()
    private init() { load() }

    @Published private(set) var moments: [Moment] = []

    private let key = "moments_v1"

    func addMoment(frontAssetId: String, backAssetId: String) {
        let m = Moment(id: UUID().uuidString,
                       createdAt: Date(),
                       frontAssetId: frontAssetId,
                       backAssetId: backAssetId)
        moments.insert(m, at: 0)
        save()
    }
    
    func deleteMoment(withId id: String) {
        moments.removeAll { $0.id == id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(moments) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Moment].self, from: data) else { return }
        moments = decoded
    }
}


