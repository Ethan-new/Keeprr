//
//  Extensions.swift
//  Keeprr
//
//  Created by Ethan Um on 2026-01-04.
//

import SwiftUI
import Photos
import CoreImage
import ImageIO

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Collection Extension

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Async Image Helper
#if canImport(UIKit)
struct AsyncImage<Content: View, Placeholder: View>: View {
    let asset: PHAsset
    @ObservedObject var manager: KeeprrMomentsManager
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 267),
            contentMode: .aspectFill,
            options: options
        ) { img, _ in
            image = img
        }
    }
}
#endif

// MARK: - Image Encoding Helper

#if canImport(UIKit)
enum ImageEncode {
    static let ciContext = CIContext()
    
    static func jpegData(from ciImage: CIImage, quality: CGFloat = 0.92) -> Data? {
        guard let cg = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        let ui = UIImage(cgImage: cg)
        return ui.jpegData(compressionQuality: quality)
    }
}
#else
enum ImageEncode {
    static let ciContext = CIContext()
}
#endif

// MARK: - UIImage helpers
#if canImport(UIKit)
extension UIImage {
    /// Returns a horizontally mirrored copy of the image (left-right flip).
    func horizontallyMirrored() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        guard let ctx = UIGraphicsGetCurrentContext() else { return self }
        ctx.translateBy(x: size.width, y: 0)
        ctx.scaleBy(x: -1, y: 1)
        draw(in: CGRect(origin: .zero, size: size))
        let out = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return out ?? self
    }
}
#endif

// MARK: - Filter Helper
// (Filters removed)
