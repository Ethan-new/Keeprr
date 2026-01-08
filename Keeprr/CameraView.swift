//
//  CameraView.swift
//  Keeprr
//
//  Created by Ethan Um on 2026-01-04.
//

import SwiftUI
import AVFoundation
import Photos
import CoreImage
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Camera View

#if canImport(UIKit)
struct CameraView: View {
    @Binding var selectedTab: Int
    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?
    @State private var frontAssetId: String?
    @State private var backAssetId: String?
    @State private var didTapCapture: Bool = false
    @State private var didTapReverseInt: Int = 0
    @State private var isFront = true
    @State private var isCapturing = false
    @State private var countdown = 3
    @State private var showCountdown = false
    @State private var shouldCaptureSecondPhoto = false
    @State private var zoomFactorBack: CGFloat = 1.0
    @State private var zoomFactorFront: CGFloat = 1.0
    @State private var hasUltraWide: Bool = false
    @State private var isReviewingCapture = false
    @State private var secondCaptureIsFront = false
    
    private var isUserZoomEnabled: Bool {
        // During the 2-photo capture flow (especially after the auto switch), lock zoom.
        !isCapturing && !showCountdown && !shouldCaptureSecondPhoto && !isReviewingCapture
    }
    
    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
    }
    
    var body: some View {
        GeometryReader { geo in
            // Keep these in sync with `SingleCameraController` card layout.
            let previewWidthMultiplier: CGFloat = 0.96
            let previewAspect: CGFloat = 4.0 / 3.0
            let previewHeight = geo.size.width * previewWidthMultiplier * previewAspect
            let previewBottomInset: CGFloat = 140
            let computedPreviewTop = geo.size.height - geo.safeAreaInsets.bottom - previewBottomInset - previewHeight
            let previewTop = max(geo.safeAreaInsets.top + 10, computedPreviewTop)
            
            ZStack {
                // Solid black background everywhere (removes any gray safe-area bleed).
                Color.black.ignoresSafeArea()
                
                CustomCameraRepresentable(
                    frontImage: $frontImage,
                    backImage: $backImage,
                    frontAssetId: $frontAssetId,
                    backAssetId: $backAssetId,
                    didTapCapture: $didTapCapture,
                    didTapReverseInt: $didTapReverseInt,
                    isFront: $isFront,
                    isCapturing: $isCapturing,
                    showCountdown: $showCountdown,
                    countdown: $countdown,
                    shouldCaptureSecondPhoto: $shouldCaptureSecondPhoto,
                    zoomFactorBack: $zoomFactorBack,
                    zoomFactorFront: $zoomFactorFront,
                    hasUltraWide: $hasUltraWide,
                    isUserZoomEnabled: Binding(
                        get: { isUserZoomEnabled },
                        set: { _ in }
                    ),
                    isReviewingCapture: $isReviewingCapture,
                    secondCaptureIsFront: $secondCaptureIsFront
                )
                
                if isReviewingCapture {
                    captureReviewOverlay
                        .transition(.opacity)
                        .zIndex(50)
                }
                
                // Countdown overlay
                if showCountdown {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        Text("\(countdown)")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Top-left X (exit)
                VStack {
                    HStack {
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedTab = 0
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.35))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 16)
                        // Keep it inside the tappable safe-area (not in the status bar region).
                        .padding(.top, geo.safeAreaInsets.top + 8)
                        .zIndex(10)
                        
                        Spacer()
                    }
                    Spacer()
                }
                .allowsHitTesting(true)
                
                // Zoom chips overlayed on top of the camera preview "card"
                zoomControls
                    .position(
                        x: geo.size.width / 2,
                        y: previewTop + previewHeight - 34
                    )
                    .zIndex(10)
                
                // Bottom controls (no tab bar visible)
                VStack {
                    Spacer()
                    
                    if !isReviewingCapture {
                        HStack {
                            // Placeholder for balance (keeps shutter centered)
                            Spacer()
                                .frame(width: 70, height: 70)
                            
                            CaptureButtonView()
                                .onTapGesture {
                                    if !isCapturing && !isReviewingCapture {
                                        isCapturing = true
                                        didTapCapture = true
                                    }
                                }
                                .disabled(isCapturing || isReviewingCapture)
                                .opacity((isCapturing || isReviewingCapture) ? 0.5 : 1.0)
                            
                            // Camera rotation button (right side)
                            Button {
                                isFront.toggle()
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 24))
                                    .frame(width: 70, height: 70)
                                    .foregroundColor(.white)
                            }
                            .disabled(isCapturing || isReviewingCapture)
                            .opacity((isCapturing || isReviewingCapture) ? 0.5 : 1.0)
                        }
                        .padding(.horizontal, 20)
                        // Less bottom padding (controls closer to the bottom edge)
                        .padding(.bottom, max(10, geo.safeAreaInsets.bottom + 6))
                    }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .statusBarHidden(true)
        .onAppear {
            Task {
                _ = await PhotoAlbumService.shared.requestAuth()
            }
        }
    }
    
    private var zoomControls: some View {
        HStack(spacing: 10) {
            if !isFront {
                if hasUltraWide {
                    ZoomChip(label: "0.5×", isSelected: abs(zoomFactorBack - 0.5) < 0.05) {
                        zoomFactorBack = 0.5
                    }
                }
                ZoomChip(label: "1×", isSelected: abs(zoomFactorBack - 1.0) < 0.05) {
                    zoomFactorBack = 1.0
                }
                ZoomChip(label: "2×", isSelected: abs(zoomFactorBack - 2.0) < 0.05) {
                    zoomFactorBack = 2.0
                }
            } else {
                ZoomChip(label: "1×", isSelected: true) {
                    zoomFactorFront = 1.0
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .allowsHitTesting(isUserZoomEnabled)
        .opacity(isUserZoomEnabled ? 1.0 : 0.45)
    }
    
    private var captureReviewOverlay: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let backImage {
                    MomentCompositeDisplayView(
                        backImage: backImage,
                        frontImage: frontImage
                    )
                } else {
                    ProgressView().tint(.white)
                }

                VStack {
                    Spacer()
                    reviewButtons(bottomInset: max(10, geo.safeAreaInsets.bottom + 6))
                }
                .allowsHitTesting(true)
            }
        }
    }
    
    @ViewBuilder
    private func reviewButtons(bottomInset: CGFloat) -> some View {
        HStack {
            Button {
                resetCaptureForRedo()
            } label: {
                Text("Redo")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            Button {
                saveMomentFromCapture()
            } label: {
                Text("Save")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .disabled(frontAssetId == nil || backAssetId == nil)
            .opacity((frontAssetId == nil || backAssetId == nil) ? 0.6 : 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, bottomInset)
    }
    
    private func resetCaptureForRedo() {
        isReviewingCapture = false
        isCapturing = false
        showCountdown = false
        shouldCaptureSecondPhoto = false
        countdown = 3
        
        frontImage = nil
        backImage = nil
        frontAssetId = nil
        backAssetId = nil
        
        // Reset preview to front by default (matches initial flow).
        isFront = true
        secondCaptureIsFront = false
        
        // Reset zoom defaults for next run.
        zoomFactorFront = 1.0
        zoomFactorBack = hasUltraWide ? 0.5 : 1.0
    }
    
    private func saveMomentFromCapture() {
        guard let frontId = frontAssetId, let backId = backAssetId else { return }
        MomentStore.shared.addMoment(frontAssetId: frontId, backAssetId: backId)
        resetCaptureForRedo()
    }
}

// MARK: - Review display (matches Keeprr Moments viewer)

private struct MomentCompositeDisplayView: View {
    let backImage: UIImage
    let frontImage: UIImage?

    @State private var isSwapped = false
    @State private var overlayOffset: CGSize = .zero
    @State private var overlayDragTranslation: CGSize = .zero
    @State private var canSwap = true
    @GestureState private var isPressingBaseImage = false

    var body: some View {
        GeometryReader { geo in
            let container = geo.size
            let baseImage: UIImage = (isSwapped ? (frontImage ?? backImage) : backImage)
            let overlayImage: UIImage? = (isSwapped ? backImage : frontImage)

            let imgSize = baseImage.size
            let safeW = max(imgSize.width, CGFloat(1))
            let safeH = max(imgSize.height, CGFloat(1))
            let scale = min(container.width / safeW, container.height / safeH)
            let fitted = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)

            // Keep the overlay within the displayed base-photo frame (account for padding).
            let overlayPaddingX: CGFloat = 18
            let overlayPaddingY: CGFloat = 24
            let overlayMaxWidth = max(CGFloat(0), fitted.width - (overlayPaddingX * 2))
            let overlayMaxHeight = max(CGFloat(0), fitted.height - (overlayPaddingY * 2))
            let overlayWidth = min(CGFloat(140), overlayMaxWidth)
            let overlayHeight = min(CGFloat(190), overlayMaxHeight)

            let currentOverlayOffset = clampedOverlayOffset(
                raw: CGSize(
                    width: overlayOffset.width + overlayDragTranslation.width,
                    height: overlayOffset.height + overlayDragTranslation.height
                ),
                fitted: fitted,
                overlaySize: CGSize(width: overlayWidth, height: overlayHeight),
                paddingX: overlayPaddingX,
                paddingY: overlayPaddingY
            )

            ZStack(alignment: .topLeading) {
                Image(uiImage: baseImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: fitted.width, height: fitted.height)
                    .clipped()
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5, maximumDistance: 10)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .updating($isPressingBaseImage) { value, state, _ in
                                switch value {
                                case .second(true, _):
                                    state = true
                                default:
                                    state = false
                                }
                            }
                    )

                if let overlayImage {
                    Image(uiImage: overlayImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: overlayWidth, height: overlayHeight)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
                        .opacity(isPressingBaseImage ? 0 : 1)
                        .animation(.easeInOut(duration: 0.15), value: isPressingBaseImage)
                        .offset(
                            x: overlayPaddingX + currentOverlayOffset.width,
                            y: overlayPaddingY + currentOverlayOffset.height
                        )
                        .onTapGesture {
                            // Only swap if we actually have both photos loaded.
                            guard frontImage != nil, canSwap else { return }
                            canSwap = false
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isSwapped.toggle()
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                canSwap = true
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 2)
                                .onChanged { value in
                                    overlayDragTranslation = value.translation
                                }
                                .onEnded { _ in
                                    overlayOffset = currentOverlayOffset
                                    overlayDragTranslation = .zero
                                }
                        )
                }
            }
            .frame(width: fitted.width, height: fitted.height)
            .position(x: container.width / 2, y: container.height / 2)
        }
    }

    private func clampedOverlayOffset(
        raw: CGSize,
        fitted: CGSize,
        overlaySize: CGSize,
        paddingX: CGFloat,
        paddingY: CGFloat
    ) -> CGSize {
        let minX = -paddingX
        let maxX = max(CGFloat(0), fitted.width - overlaySize.width - paddingX)
        let minY = -paddingY
        let maxY = max(CGFloat(0), fitted.height - overlaySize.height - paddingY)

        return CGSize(
            width: min(max(raw.width, minX), maxX),
            height: min(max(raw.height, minY), maxY)
        )
    }
}

// MARK: - Custom Camera Representable

struct CustomCameraRepresentable: UIViewControllerRepresentable {
    @Binding var frontImage: UIImage?
    @Binding var backImage: UIImage?
    @Binding var frontAssetId: String?
    @Binding var backAssetId: String?
    @Binding var didTapCapture: Bool
    @Binding var didTapReverseInt: Int
    @Binding var isFront: Bool
    @Binding var isCapturing: Bool
    @Binding var showCountdown: Bool
    @Binding var countdown: Int
    @Binding var shouldCaptureSecondPhoto: Bool
    @Binding var zoomFactorBack: CGFloat
    @Binding var zoomFactorFront: CGFloat
    @Binding var hasUltraWide: Bool
    @Binding var isUserZoomEnabled: Bool
    @Binding var isReviewingCapture: Bool
    @Binding var secondCaptureIsFront: Bool
    
    func makeUIViewController(context: Context) -> SingleCameraController {
        let controller = SingleCameraController()
        controller.isFront = isFront
        controller.isUserZoomEnabled = isUserZoomEnabled
        let coordinator1 = Coordinator1(self, controller: controller)
        let coordinator2 = Coordinator2(self, controller: controller)
        controller.delegate1 = coordinator1
        controller.delegate2 = coordinator2
        controller.onUltraWideAvailable = { available in
            hasUltraWide = available
        }
        controller.onBackZoomChanged = { zoom in
            zoomFactorBack = zoom
        }
        controller.onFrontZoomChanged = { zoom in
            zoomFactorFront = zoom
        }
        return controller
    }
    
    func updateUIViewController(_ cameraViewController: SingleCameraController, context: Context) {
        cameraViewController.isUserZoomEnabled = isUserZoomEnabled
        
        if didTapCapture {
            // Immediately reset to prevent multiple triggers
            didTapCapture = false
            
            // Decide capture order based on current preview.
            // This prevents the preview from "unzooming" unexpectedly when the user starts on the back camera.
            let firstIsFront = isFront
            secondCaptureIsFront = !firstIsFront
            
            // Create callbacks and pass directly to controller
            let firstPhotoCallback: () -> Void = {
                // First photo taken, switch preview camera and start countdown
                // When switching to the other side for the second photo: force zoom out and lock user zoom.
                if secondCaptureIsFront {
                    zoomFactorFront = 1.0
                } else {
                    zoomFactorBack = hasUltraWide ? 0.5 : 1.0
                }
                isFront = secondCaptureIsFront // preview the camera we are about to capture second
                showCountdown = true
                countdown = 3
                
                // Start countdown timer
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    countdown -= 1
                    
                    if countdown <= 0 {
                        timer.invalidate()
                        showCountdown = false
                        
                        // Trigger second photo capture
                        shouldCaptureSecondPhoto = true
                    }
                }
            }
            
            let secondPhotoCallback: () -> Void = {
                // Both photos taken
                isCapturing = false
                shouldCaptureSecondPhoto = false
                isReviewingCapture = true
                
                // Moment creation is now controlled by the review UI ("Save").
            }
            
            // Map delegate callbacks (front delegate = onFirstPhotoComplete, back delegate = onSecondPhotoComplete)
            // to the "first/second" capture flow depending on which side we start on.
            if firstIsFront {
                cameraViewController.onFirstPhotoComplete = firstPhotoCallback
                cameraViewController.onSecondPhotoComplete = secondPhotoCallback
                cameraViewController.captureFront()
            } else {
                cameraViewController.onSecondPhotoComplete = firstPhotoCallback
                cameraViewController.onFirstPhotoComplete = secondPhotoCallback
                cameraViewController.captureBack()
            }
        }
        
        if shouldCaptureSecondPhoto {
            // Explicitly capture the other side second.
            if secondCaptureIsFront {
                zoomFactorFront = 1.0
                cameraViewController.captureFront()
            } else {
                // Ensure the second (back) capture is always fully zoomed out (0.5× if ultra-wide exists).
                zoomFactorBack = hasUltraWide ? 0.5 : 1.0
                cameraViewController.captureBack()
            }
            shouldCaptureSecondPhoto = false
        }
        
        // Update zoom when state changes
        if !isFront {
            // Handle back camera zoom using virtual zoom
            cameraViewController.setBackVirtualZoom(zoomFactorBack, ramp: true)
        } else {
            cameraViewController.setZoom(zoomFactorFront, for: .front, ramp: true)
        }
        
        if isFront != cameraViewController.isFront {
            if isFront {
                cameraViewController.setFrontCam()
                cameraViewController.setZoom(zoomFactorFront, for: .front, ramp: false)
            } else {
                cameraViewController.setBackCam()
                cameraViewController.setBackVirtualZoom(zoomFactorBack, ramp: false)
            }
            cameraViewController.isFront = isFront
        }
    }
    
    class Coordinator1: NSObject, UINavigationControllerDelegate, AVCapturePhotoCaptureDelegate {
        let parent: CustomCameraRepresentable
        weak var controller: SingleCameraController?
        
        init(_ parent: CustomCameraRepresentable, controller: SingleCameraController) {
            self.parent = parent
            self.controller = controller
        }
        
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            guard error == nil else {
                print("Photo output 1 error: \(error!.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.controller?.onFirstPhotoComplete?()
                }
                return
            }
            
            guard let data = photo.fileDataRepresentation(),
                  let ui = UIImage(data: data) else {
                print("Photo output 1 - failed to get image data")
                DispatchQueue.main.async { [weak self] in
                    self?.controller?.onFirstPhotoComplete?()
                }
                return
            }

            let saveMode = UserDefaults.standard.integer(forKey: "front_camera_save_mode_v1") // 0 = unmirrored (default), 1 = mirrored
            let finalFrontImage: UIImage
            let finalFrontData: Data
            let finalFrontUTI: String

            if saveMode == 1 {
                // Save "as seen" (mirrored).
                finalFrontImage = ui.horizontallyMirrored()
                finalFrontData = finalFrontImage.jpegData(compressionQuality: 0.95) ?? data
                finalFrontUTI = "public.jpeg"
            } else {
                // Default behavior: save the original capture bytes.
                finalFrontImage = ui
                finalFrontData = data
                finalFrontUTI = "public.image"
            }

            parent.frontImage = finalFrontImage

            Task { @MainActor in
                do {
                    guard await PhotoAlbumService.shared.requestAuth() else {
                        print("Photo library authorization denied")
                        self.controller?.onFirstPhotoComplete?()
                        return
                    }
                    
                    // `AVCaptureResolvedPhotoSettings` doesn't expose the file type in all SDKs.
                    // Use a safe generic UTI; Photos will still store the bytes correctly.
                    let id = try await PhotoAlbumService.shared.saveImageDataToAlbum(finalFrontData, uniformTypeIdentifier: finalFrontUTI)
                    parent.frontAssetId = id
                    print("Front photo saved with asset ID: \(id)")
                } catch {
                    print("Save front failed:", error)
                }
                
                self.controller?.onFirstPhotoComplete?()
            }
        }
    }
    
    class Coordinator2: NSObject, UINavigationControllerDelegate, AVCapturePhotoCaptureDelegate {
        let parent: CustomCameraRepresentable
        weak var controller: SingleCameraController?
        
        init(_ parent: CustomCameraRepresentable, controller: SingleCameraController) {
            self.parent = parent
            self.controller = controller
        }
        
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            guard error == nil else {
                print("Photo output 2 error: \(error!.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.controller?.onSecondPhotoComplete?()
                }
                return
            }
            
            guard let data = photo.fileDataRepresentation(),
                  let ui = UIImage(data: data) else {
                print("Photo output 2 - failed to get image data")
                DispatchQueue.main.async { [weak self] in
                    self?.controller?.onSecondPhotoComplete?()
                }
                return
            }

            // Filters removed: always keep original bytes/metadata (Camera-app-like).
            parent.backImage = ui

            Task { @MainActor in
                do {
                    guard await PhotoAlbumService.shared.requestAuth() else {
                        print("Photo library authorization denied")
                        self.controller?.onSecondPhotoComplete?()
                        return
                    }
                    
                    // `AVCaptureResolvedPhotoSettings` doesn't expose the file type in all SDKs.
                    // Use a safe generic UTI; Photos will still store the bytes correctly.
                    let id = try await PhotoAlbumService.shared.saveImageDataToAlbum(data, uniformTypeIdentifier: "public.image")
                    parent.backAssetId = id
                    print("Back photo saved with asset ID: \(id)")
                } catch {
                    print("Save back failed:", error)
                }
                
                self.controller?.onSecondPhotoComplete?()
            }
        }
    }
}

// MARK: - Custom Camera Controller

/// Single-camera controller that switches between front/back to allow full-resolution still capture
/// (MultiCam commonly caps still capture resolution to ~1080p due to bandwidth constraints).
final class SingleCameraController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var image: UIImage?
    
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let previewOutput = AVCaptureVideoDataOutput()
    private var currentInput: AVCaptureDeviceInput?
    
    private var backWideCamera: AVCaptureDevice?
    private var backUltraWideCamera: AVCaptureDevice?
    private var frontCamera: AVCaptureDevice?
    
    private var currentPosition: AVCaptureDevice.Position = .front
    
    var cameraPreviewLayer: UIImageView?
    private let previewContainerView = UIView()
    
    var delegate1: AVCapturePhotoCaptureDelegate?
    var delegate2: AVCapturePhotoCaptureDelegate?
    
    var isFront = false
    
    // Callback for ultra-wide availability
    var onUltraWideAvailable: ((Bool) -> Void)?
    
    // Callback for zoom changes (to update UI)
    var onBackZoomChanged: ((CGFloat) -> Void)?
    var onFrontZoomChanged: ((CGFloat) -> Void)?
    
    var onFirstPhotoComplete: (() -> Void)?
    var onSecondPhotoComplete: (() -> Void)?

    /// Controls whether the user can change zoom (pinch). Programmatic zoom updates still apply.
    var isUserZoomEnabled: Bool = true
    
    // Zoom state
    private var pinchStartZoom: CGFloat = 1.0
    private var currentBackVirtualZoom: CGFloat = 1.0   // can be 0.5 ... max
    private var currentFrontZoom: CGFloat = 1.0
    private var isUsingUltraWide: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    func setFrontCam() {
        isFront = true
        currentPosition = .front
        switchToDevice(frontCamera)
        setZoom(currentFrontZoom, for: .front, ramp: false)
    }
    
    func setBackCam() {
        isFront = false
        currentPosition = .back
        // Ensure we actually switch to a back device when coming from front.
        switchToDevice(currentBackDevice())
        setBackVirtualZoom(currentBackVirtualZoom, ramp: false)
    }
    
    func captureFront() {
        if currentPosition != .front { setFrontCam() }
        setZoom(currentFrontZoom, for: .front, ramp: false)
        
        let settings = AVCapturePhotoSettings()
        if #available(iOS 16.0, *), let device = frontCamera, let dims = bestMaxPhotoDimensions(for: device) {
            settings.maxPhotoDimensions = dims
        }
        if #available(iOS 13.0, *) {
            settings.photoQualityPrioritization = .quality
        }
        
        photoOutput.capturePhoto(with: settings, delegate: delegate1!)
    }
    
    func captureBack() {
        if currentPosition != .back { setBackCam() }
        setBackVirtualZoom(currentBackVirtualZoom, ramp: false)
        
        let settings = AVCapturePhotoSettings()
        if #available(iOS 16.0, *), let device = currentBackDevice(), let dims = bestMaxPhotoDimensions(for: device) {
            settings.maxPhotoDimensions = dims
        }
        if #available(iOS 13.0, *) {
            settings.photoQualityPrioritization = .quality
        }
        
        photoOutput.capturePhoto(with: settings, delegate: delegate2!)
    }
    
    func getZoom(for position: AVCaptureDevice.Position) -> CGFloat {
        let device = (position == .front) ? frontCamera : currentBackDevice()
        return CGFloat(device?.videoZoomFactor ?? 1.0)
    }
    
    func setZoom(_ requested: CGFloat, for position: AVCaptureDevice.Position, ramp: Bool) {
        guard let device = (position == .front) ? frontCamera : currentBackDevice() else { return }
        
        let minZoom: CGFloat
        if #available(iOS 15.0, *) {
            minZoom = CGFloat(device.minAvailableVideoZoomFactor)
        } else {
            minZoom = 1.0
        }
        let maxZoom = min(CGFloat(device.activeFormat.videoMaxZoomFactor), 6.0)
        let clamped = max(minZoom, min(requested, maxZoom))
        
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            if ramp {
                device.ramp(toVideoZoomFactor: clamped, withRate: 8.0)
            } else {
                device.videoZoomFactor = clamped
            }
            
            if position == .front {
                currentFrontZoom = clamped
                onFrontZoomChanged?(clamped)
            } else {
                currentBackVirtualZoom = clamped
            }
        } catch {
            // ignore
        }
    }
    
    func setBackVirtualZoom(_ requestedVirtual: CGFloat, ramp: Bool) {
        let minVirtual: CGFloat = (backUltraWideCamera != nil) ? 0.5 : 1.0
        let maxVirtual: CGFloat = {
            guard let wide = backWideCamera else { return 6.0 }
            return min(CGFloat(wide.activeFormat.videoMaxZoomFactor), 6.0)
        }()
        
        let v = max(minVirtual, min(requestedVirtual, maxVirtual))
        currentBackVirtualZoom = v
        onBackZoomChanged?(v)
        
        // Ultra-wide region
        if let ultra = backUltraWideCamera, v < 1.0 {
            if currentInput?.device.uniqueID != ultra.uniqueID {
                switchToDevice(ultra)
            }
            
            // Map virtual [0.5 .. 1.0] to ultra zoom [1.0 .. 2.0]
            let ultraZoom = max(1.0, min(v / 0.5, min(CGFloat(ultra.activeFormat.videoMaxZoomFactor), 2.0)))
            do {
                try ultra.lockForConfiguration()
                defer { ultra.unlockForConfiguration() }
                if ramp {
                    ultra.ramp(toVideoZoomFactor: ultraZoom, withRate: 8.0)
                } else {
                    ultra.videoZoomFactor = ultraZoom
                }
            } catch {}
            
            isUsingUltraWide = true
            currentPosition = .back
            return
        }
        
        // Wide region
        if let wide = backWideCamera, currentInput?.device.uniqueID != wide.uniqueID {
            // Ensure the wide lens is the active device when virtual zoom >= 1.0.
            switchToDevice(wide)
        }
        guard let wide = backWideCamera else { return }
        let wideZoom = max(1.0, min(v, min(CGFloat(wide.activeFormat.videoMaxZoomFactor), 6.0)))
        do {
            try wide.lockForConfiguration()
            defer { wide.unlockForConfiguration() }
            if ramp {
                wide.ramp(toVideoZoomFactor: wideZoom, withRate: 8.0)
            } else {
                wide.videoZoomFactor = wideZoom
            }
        } catch {}
        
        isUsingUltraWide = false
        currentPosition = .back
    }
    
    private func setup() {
        setupDevice()
        
        view.backgroundColor = .black
        
        // BeReal-like preview "card" (rounded rectangle), centered near the top.
        previewContainerView.translatesAutoresizingMaskIntoConstraints = false
        previewContainerView.backgroundColor = .black
        previewContainerView.layer.cornerRadius = 26
        previewContainerView.layer.cornerCurve = .continuous
        previewContainerView.clipsToBounds = true
        view.insertSubview(previewContainerView, at: 0)
        
        let minTop = previewContainerView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 10)
        minTop.priority = .defaultHigh
        
        NSLayoutConstraint.activate([
            previewContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            // Wider card (less left/right padding)
            previewContainerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.96),
            // 3:4 aspect ratio like the screenshot (tall card)
            previewContainerView.heightAnchor.constraint(equalTo: previewContainerView.widthAnchor, multiplier: 4.0 / 3.0),
            
            // Push the preview down near the shutter area.
            // This is intentionally "camera-app-like" where the preview sits lower on the screen.
            previewContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -140),
            minTop
        ])
        
        cameraPreviewLayer = UIImageView()
        cameraPreviewLayer!.translatesAutoresizingMaskIntoConstraints = false
        cameraPreviewLayer!.contentMode = .scaleAspectFill
        cameraPreviewLayer!.clipsToBounds = true
        previewContainerView.addSubview(cameraPreviewLayer!)
        NSLayoutConstraint.activate([
            cameraPreviewLayer!.leadingAnchor.constraint(equalTo: previewContainerView.leadingAnchor),
            cameraPreviewLayer!.trailingAnchor.constraint(equalTo: previewContainerView.trailingAnchor),
            cameraPreviewLayer!.topAnchor.constraint(equalTo: previewContainerView.topAnchor),
            cameraPreviewLayer!.bottomAnchor.constraint(equalTo: previewContainerView.bottomAnchor)
        ])
        
        configureSessionIfNeeded()
        if isFront { setFrontCam() } else { setBackCam() }
        startRunningCaptureSession()
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)
    }
    
    private func setupDevice() {
        let wideAngleSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        
        for device in wideAngleSession.devices {
            switch device.position {
            case .front:
                self.frontCamera = device
            case .back:
                self.backWideCamera = device
            default:
                break
            }
        }
        
        if let ultraWide = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            self.backUltraWideCamera = ultraWide
            onUltraWideAvailable?(true)
        } else {
            onUltraWideAvailable?(false)
        }
        
        currentPosition = isFront ? .front : .back
    }
    
    private func startRunningCaptureSession() {
        DispatchQueue(label: "startRunningCaptureSession").async {
            self.captureSession.startRunning()
        }
    }
    
    private func configureSessionIfNeeded() {
        guard captureSession.inputs.isEmpty, captureSession.outputs.isEmpty else { return }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            if #available(iOS 13.0, *) {
                photoOutput.maxPhotoQualityPrioritization = .quality
            }
        }
        
        previewOutput.alwaysDiscardsLateVideoFrames = true
        previewOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        if captureSession.canAddOutput(previewOutput) {
            captureSession.addOutput(previewOutput)
            previewOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        }
        
        if let c = previewOutput.connection(with: .video) { applyPortraitRotation(to: c) }
        if let c = photoOutput.connection(with: .video) { applyPortraitRotation(to: c) }
        
        captureSession.commitConfiguration()
    }
    
    private func switchToDevice(_ device: AVCaptureDevice?) {
        guard let device else { return }
        configureSessionIfNeeded()
        
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        if let currentInput {
            captureSession.removeInput(currentInput)
            self.currentInput = nil
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                self.currentInput = input
            }
        } catch {
            print("Failed to switch device:", error)
            return
        }
        
        if #available(iOS 16.0, *), let dims = bestMaxPhotoDimensions(for: device) {
            photoOutput.maxPhotoDimensions = dims
        }

        if let c = previewOutput.connection(with: .video) {
            applyPortraitRotation(to: c)
            // Preview should behave like the system camera (mirror the front camera preview).
            c.isVideoMirrored = (device.position == .front)
        }
        if let c = photoOutput.connection(with: .video) {
            applyPortraitRotation(to: c)
            // Don't force mirroring for the actual captured photo bytes.
        }
    }
    
    private func currentBackDevice() -> AVCaptureDevice? {
        if isUsingUltraWide, let ultra = backUltraWideCamera { return ultra }
        return backWideCamera
    }
    
    @available(iOS 16.0, *)
    private func bestMaxPhotoDimensions(for device: AVCaptureDevice) -> CMVideoDimensions? {
        let dims = device.activeFormat.supportedMaxPhotoDimensions
        return dims.max(by: { Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height) })
    }
    
    @objc private func handlePinch(_ gr: UIPinchGestureRecognizer) {
        guard isUserZoomEnabled else { return }
        let isPreviewFront = isFront
        
        switch gr.state {
        case .began:
            pinchStartZoom = isPreviewFront ? currentFrontZoom : currentBackVirtualZoom
        case .changed:
            let target = pinchStartZoom * gr.scale
            if isPreviewFront {
                setZoom(target, for: .front, ramp: true)
            } else {
                setBackVirtualZoom(target, ramp: true)
            }
        case .ended, .cancelled, .failed:
            if !isPreviewFront {
                let v = currentBackVirtualZoom
                if abs(v - 0.5) < 0.06 {
                    setBackVirtualZoom(0.5, ramp: true)
                } else if abs(v - 1.0) < 0.06 {
                    setBackVirtualZoom(1.0, ramp: true)
                }
            } else {
                currentFrontZoom = getZoom(for: .front)
                onFrontZoomChanged?(currentFrontZoom)
            }
        default:
            break
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var ciImage = CIImage(cvPixelBuffer: imageBuffer)
        // Rotation is handled by the AVCaptureConnection rotation/mirroring settings.
        
        DispatchQueue.main.async {
            if let cg = ImageEncode.ciContext.createCGImage(ciImage, from: ciImage.extent) {
                self.cameraPreviewLayer?.image = UIImage(cgImage: cg)
            }
        }
    }
    
    private func applyPortraitRotation(to connection: AVCaptureConnection) {
        // iOS 17+ best practice
        connection.videoRotationAngle = 90
    }
}

class CustomCameraController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var image: UIImage?
    
    var captureSession = AVCaptureMultiCamSession()
    var backCamera: AVCaptureDevice? // Wide angle
    var backUltraWideCamera: AVCaptureDevice? // Ultra-wide
    var frontCamera: AVCaptureDevice?
    var currentCamera: AVCaptureDevice?
    var photoOutput1: AVCapturePhotoOutput?
    var photoOutput2: AVCapturePhotoOutput?
    var cameraPreviewLayer: UIImageView?
    
    var frontCameraVideoDataOutput = AVCapturePhotoOutput()
    var backCameraVideoDataOutput = AVCapturePhotoOutput()
    var backPreviewCameraVideoDataOutput = AVCaptureVideoDataOutput()
    var frontPreviewCameraVideoDataOutput = AVCaptureVideoDataOutput()
    
    // Back camera inputs (wide and ultra-wide)
    var backWideInput: AVCaptureDeviceInput?
    var backUltraWideInput: AVCaptureDeviceInput?
    var activeBackInput: AVCaptureDeviceInput? // Currently active input
    
    var captureDeviceInput1Thing: AVCaptureInput? = nil
    
    var delegate1: AVCapturePhotoCaptureDelegate?
    var delegate2: AVCapturePhotoCaptureDelegate?
    
    var isFront = false
    
    // Callback for ultra-wide availability
    var onUltraWideAvailable: ((Bool) -> Void)?
    
    // Callback for zoom changes (to update UI)
    var onBackZoomChanged: ((CGFloat) -> Void)?
    
    // Zoom state
    private var pinchStartZoom: CGFloat = 1.0
    private var currentBackVirtualZoom: CGFloat = 1.0   // can be 0.5 ... max
    private var currentFrontZoom: CGFloat = 1.0
    private var isUsingUltraWide: Bool = false
    
    func setFrontCam() {
        backPreviewCameraVideoDataOutput.setSampleBufferDelegate(nil, queue: DispatchQueue(label: "videoQueue"))
        frontPreviewCameraVideoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
    }
    
    func setBackCam() {
        backPreviewCameraVideoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        frontPreviewCameraVideoDataOutput.setSampleBufferDelegate(nil, queue: DispatchQueue(label: "videoQueue"))
    }
    
    var onFirstPhotoComplete: (() -> Void)?
    var onSecondPhotoComplete: (() -> Void)?
    
    func captureFront() {
        print("captureFront")
        setZoom(currentFrontZoom, for: .front, ramp: false)
        let settings = AVCapturePhotoSettings()
        if #available(iOS 13.0, *) {
            settings.photoQualityPrioritization = .quality
        }
        frontCameraVideoDataOutput.capturePhoto(with: settings, delegate: delegate1!)
    }
    
    func captureBack() {
        print("captureBack")
        // Ensure correct zoom/device is set before capture
        setBackVirtualZoom(currentBackVirtualZoom, ramp: false)
        let settings = AVCapturePhotoSettings()
        if #available(iOS 13.0, *) {
            settings.photoQualityPrioritization = .quality
        }
        backCameraVideoDataOutput.capturePhoto(with: settings, delegate: delegate2!)
    }
    
    func getZoom(for position: AVCaptureDevice.Position) -> CGFloat {
        let device = (position == .front) ? frontCamera : backCamera
        return CGFloat(device?.videoZoomFactor ?? 1.0)
    }
    
    func setZoom(_ requested: CGFloat, for position: AVCaptureDevice.Position, ramp: Bool) {
        guard let device = (position == .front) ? frontCamera : backCamera else { return }
        
        // Clamp
        let minZoom: CGFloat
        if #available(iOS 15.0, *) {
            minZoom = CGFloat(device.minAvailableVideoZoomFactor)
        } else {
            minZoom = 1.0
        }
        let maxZoom = min(CGFloat(device.activeFormat.videoMaxZoomFactor), 6.0) // keep it camera-like
        
        let clamped = max(minZoom, min(requested, maxZoom))
        
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            if ramp {
                device.ramp(toVideoZoomFactor: clamped, withRate: 8.0) // smooth
            } else {
                device.videoZoomFactor = clamped
            }
            
            if position == .front {
                currentFrontZoom = clamped
            } else {
                // For back camera, use virtual zoom - but this shouldn't be called for back
                // Back camera should use setBackVirtualZoom instead
                currentBackVirtualZoom = clamped
            }
        } catch {
            // ignore; device might be busy
        }
    }
    
    func setBackVirtualZoom(_ requestedVirtual: CGFloat, ramp: Bool) {
        // Clamp virtual zoom range
        let minVirtual: CGFloat = (backUltraWideCamera != nil) ? 0.5 : 1.0
        let maxVirtual: CGFloat = {
            guard let wide = backCamera else { return 6.0 }
            return min(CGFloat(wide.activeFormat.videoMaxZoomFactor), 6.0)
        }()
        
        let v = max(minVirtual, min(requestedVirtual, maxVirtual))
        currentBackVirtualZoom = v
        
        // Notify UI of zoom change
        onBackZoomChanged?(v)
        
        // If ultra-wide exists and v < 1.0, use ultra-wide and zoom it digitally up to 2.0
        if let ultra = backUltraWideCamera, v < 1.0 {
            if !isUsingUltraWide { switchToUltraWide() }
            
            // Map virtual [0.5 .. 1.0] to ultra device zoom [1.0 .. 2.0]
            let ultraZoom = max(1.0, min(v / 0.5, min(CGFloat(ultra.activeFormat.videoMaxZoomFactor), 2.0)))
            
            do {
                try ultra.lockForConfiguration()
                defer { ultra.unlockForConfiguration() }
                if ramp {
                    ultra.ramp(toVideoZoomFactor: ultraZoom, withRate: 8.0)
                } else {
                    ultra.videoZoomFactor = ultraZoom
                }
            } catch {
                // ignore
            }
            
            isUsingUltraWide = true
            return
        }
        
        // Otherwise use wide lens: virtual >= 1.0 maps directly to wide zoom
        if isUsingUltraWide { switchToWide() }
        
        guard let wide = backCamera else { return }
        let wideZoom = max(1.0, min(v, min(CGFloat(wide.activeFormat.videoMaxZoomFactor), 6.0)))
        
        do {
            try wide.lockForConfiguration()
            defer { wide.unlockForConfiguration() }
            if ramp {
                wide.ramp(toVideoZoomFactor: wideZoom, withRate: 8.0)
            } else {
                wide.videoZoomFactor = wideZoom
            }
        } catch {
            // ignore
        }
        
        isUsingUltraWide = false
    }
    
    private func switchToUltraWide() {
        guard let ultraWideInput = backUltraWideInput,
              let wideInput = backWideInput,
              let ultraWide = backUltraWideCamera else { return }
        
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        // Remove wide connections
        if let widePort = wideInput.ports(for: .video,
                                          sourceDeviceType: backCamera?.deviceType,
                                          sourceDevicePosition: .back).first {
            // Find and remove connections using wide port
            for connection in backPreviewCameraVideoDataOutput.connections {
                if connection.inputPorts.contains(widePort) {
                    captureSession.removeConnection(connection)
                }
            }
            for connection in backCameraVideoDataOutput.connections {
                if connection.inputPorts.contains(widePort) {
                    captureSession.removeConnection(connection)
                }
            }
        }
        
        // Add ultra-wide connections
        if let ultraWidePort = ultraWideInput.ports(for: .video,
                                                    sourceDeviceType: ultraWide.deviceType,
                                                    sourceDevicePosition: .back).first {
            let backPreviewConnection = AVCaptureConnection(inputPorts: [ultraWidePort], output: backPreviewCameraVideoDataOutput)
            let backPhotoConnection = AVCaptureConnection(inputPorts: [ultraWidePort], output: backCameraVideoDataOutput)
            backPhotoConnection.videoRotationAngle = 90
            
            captureSession.addConnection(backPreviewConnection)
            captureSession.addConnection(backPhotoConnection)
        }
        
        activeBackInput = ultraWideInput
        isUsingUltraWide = true
    }
    
    private func switchToWide() {
        guard let ultraWideInput = backUltraWideInput,
              let wideInput = backWideInput,
              let wide = backCamera else { return }
        
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        // Remove ultra-wide connections
        if let ultraWidePort = ultraWideInput.ports(for: .video,
                                                   sourceDeviceType: backUltraWideCamera?.deviceType,
                                                   sourceDevicePosition: .back).first {
            for connection in backPreviewCameraVideoDataOutput.connections {
                if connection.inputPorts.contains(ultraWidePort) {
                    captureSession.removeConnection(connection)
                }
            }
            for connection in backCameraVideoDataOutput.connections {
                if connection.inputPorts.contains(ultraWidePort) {
                    captureSession.removeConnection(connection)
                }
            }
        }
        
        // Add wide connections
        if let widePort = wideInput.ports(for: .video,
                                         sourceDeviceType: wide.deviceType,
                                         sourceDevicePosition: .back).first {
            let backPreviewConnection = AVCaptureConnection(inputPorts: [widePort], output: backPreviewCameraVideoDataOutput)
            let backPhotoConnection = AVCaptureConnection(inputPorts: [widePort], output: backCameraVideoDataOutput)
            backPhotoConnection.videoRotationAngle = 90
            
            captureSession.addConnection(backPreviewConnection)
            captureSession.addConnection(backPhotoConnection)
        }
        
        activeBackInput = wideInput
        isUsingUltraWide = false
    }
    
    @objc private func handlePinch(_ gr: UIPinchGestureRecognizer) {
        let isPreviewFront = isFront
        
        switch gr.state {
        case .began:
            pinchStartZoom = isPreviewFront ? currentFrontZoom : currentBackVirtualZoom
            
        case .changed:
            let target = pinchStartZoom * gr.scale
            if isPreviewFront {
                setZoom(target, for: .front, ramp: true)
            } else {
                // For back camera, use virtual zoom
                setBackVirtualZoom(target, ramp: true)
            }
            
        case .ended, .cancelled, .failed:
            // Snap to nearby values for magnetic feel
            if !isPreviewFront {
                let v = currentBackVirtualZoom
                if abs(v - 0.5) < 0.06 {
                    setBackVirtualZoom(0.5, ramp: true)
                } else if abs(v - 1.0) < 0.06 {
                    setBackVirtualZoom(1.0, ramp: true)
                }
            } else {
                // Front camera: store final zoom
                currentFrontZoom = getZoom(for: .front)
            }
            
        default:
            break
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    func setup() {
        setupDevice()
        
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            print("Multi-camera capture is not supported!")
            return
        }
        
        guard let frontCamera = self.frontCamera,
              let rearCamera = self.backCamera else {
            print("Failed to get cameras")
            return
        }
        
        let frontCameraDeviceInput = try! AVCaptureDeviceInput(device: frontCamera)
        let backWideDeviceInput = try! AVCaptureDeviceInput(device: rearCamera)
        self.backWideInput = backWideDeviceInput
        
        captureSession.addInputWithNoConnections(frontCameraDeviceInput)
        captureSession.addInputWithNoConnections(backWideDeviceInput)
        
        // Add ultra-wide input if available
        if let ultraWide = self.backUltraWideCamera {
            let backUltraWideDeviceInput = try! AVCaptureDeviceInput(device: ultraWide)
            self.backUltraWideInput = backUltraWideDeviceInput
            captureSession.addInputWithNoConnections(backUltraWideDeviceInput)
        }
        
        // Start with wide camera active
        self.activeBackInput = backWideDeviceInput
        
        captureSession.addOutputWithNoConnections(backPreviewCameraVideoDataOutput)
        captureSession.addOutputWithNoConnections(frontPreviewCameraVideoDataOutput)
        captureSession.addOutputWithNoConnections(frontCameraVideoDataOutput)
        captureSession.addOutputWithNoConnections(backCameraVideoDataOutput)

        // Match system Camera behavior as closely as possible: prioritize quality.
        if #available(iOS 13.0, *) {
            frontCameraVideoDataOutput.maxPhotoQualityPrioritization = .quality
            backCameraVideoDataOutput.maxPhotoQualityPrioritization = .quality
        }
        
        let frontCameraVideoPort = frontCameraDeviceInput.ports(for: .video,
                                                                 sourceDeviceType: frontCamera.deviceType,
                                                                 sourceDevicePosition: AVCaptureDevice.Position(rawValue: frontCamera.position.rawValue) ?? .front).first
        
        // Create connections for wide camera (default)
        let backWideVideoPort = backWideDeviceInput.ports(for: .video,
                                                          sourceDeviceType: backCamera?.deviceType,
                                                          sourceDevicePosition: AVCaptureDevice.Position(rawValue: (backCamera?.position)!.rawValue) ?? .back).first
        
        let backPreviewCameraVideoDataOutputConnection = AVCaptureConnection(inputPorts: [backWideVideoPort!], output: backPreviewCameraVideoDataOutput)
        let frontPreviewCameraVideoDataOutputConnection = AVCaptureConnection(inputPorts: [frontCameraVideoPort!], output: frontPreviewCameraVideoDataOutput)
        let frontCameraVideoDataOutputConnection = AVCaptureConnection(inputPorts: [frontCameraVideoPort!], output: frontCameraVideoDataOutput)
        let backCameraVideoDataOutputConnection = AVCaptureConnection(inputPorts: [backWideVideoPort!], output: backCameraVideoDataOutput)
        
        captureSession.addConnection(backPreviewCameraVideoDataOutputConnection)
        frontCameraVideoDataOutputConnection.videoRotationAngle = 90
        captureSession.addConnection(frontPreviewCameraVideoDataOutputConnection)
        frontCameraVideoDataOutputConnection.videoRotationAngle = 90
        captureSession.addConnection(frontCameraVideoDataOutputConnection)
        frontCameraVideoDataOutputConnection.videoRotationAngle = 90
        captureSession.addConnection(backCameraVideoDataOutputConnection)
        backCameraVideoDataOutputConnection.videoRotationAngle = 90
        
        cameraPreviewLayer = UIImageView(frame: UIScreen.main.bounds)
        cameraPreviewLayer!.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(cameraPreviewLayer!, at: 0)
        
        cameraPreviewLayer!.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        cameraPreviewLayer!.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        cameraPreviewLayer!.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        cameraPreviewLayer!.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        frontPreviewCameraVideoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        captureSession.commitConfiguration()
        startRunningCaptureSession()
        
        // Add pinch gesture for zoom
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)
    }
    
    func setupDevice() {
        // Discover wide angle cameras
        let wideAngleSession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
                                                                  mediaType: AVMediaType.video,
                                                                  position: AVCaptureDevice.Position.unspecified)
        for device in wideAngleSession.devices {
            switch device.position {
            case .front:
                self.frontCamera = device
            case .back:
                self.backCamera = device
            default:
                break
            }
        }
        
        // Discover ultra-wide camera
        if let ultraWide = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            self.backUltraWideCamera = ultraWide
            onUltraWideAvailable?(true)
        } else {
            onUltraWideAvailable?(false)
        }
        
        self.currentCamera = self.backCamera
    }
    
    func startRunningCaptureSession() {
        DispatchQueue(label: "startRunningCaptureSession").async {
            self.captureSession.startRunning()
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var ciImage = CIImage(cvPixelBuffer: imageBuffer)
        ciImage = ciImage.oriented(forExifOrientation: 6)

        // Filters removed: always show original image (render to CGImage).
        DispatchQueue.main.async {
            let aspectRatio = ciImage.extent.width / ciImage.extent.height
            let newWidth = self.view.frame.height * aspectRatio
            let newFrame = CGRect(x: self.view.frame.origin.x, y: self.view.frame.origin.y, width: newWidth, height: self.view.frame.height)
            self.cameraPreviewLayer!.frame = newFrame
            
            if let cg = ImageEncode.ciContext.createCGImage(ciImage, from: ciImage.extent) {
                self.cameraPreviewLayer!.image = UIImage(cgImage: cg)
            }
        }
    }
}

// MARK: - Capture Button View

struct CaptureButtonView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 64, height: 64)
            
            Circle()
                .strokeBorder(Color.white, lineWidth: 4)
                .frame(width: 80, height: 80)
        }
        .padding()
    }
}

// MARK: - Zoom Chip View

struct ZoomChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.white.opacity(0.25) : Color.clear)
                .clipShape(Capsule())
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
}

#else

// Non-iOS fallback to keep tooling/lints happy in environments without UIKit.
struct CameraView: View {
    init(selectedTab: Binding<Int> = .constant(0)) {}
    var body: some View {
        Text("Camera is only available on iOS.")
    }
}

#endif

// MARK: - UIImage Extension
#if canImport(UIKit)
extension UIImage {
    static func convert(from ciImage: CIImage) -> UIImage {
        let context: CIContext = CIContext(options: nil)
        let cgImage: CGImage = context.createCGImage(ciImage, from: ciImage.extent)!
        let image: UIImage = UIImage(cgImage: cgImage)
        return image
    }
}
#endif
