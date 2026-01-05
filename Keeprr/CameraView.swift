//
//  CameraView.swift
//  Keeprr
//
//  Created by Ethan Um on 2026-01-04.
//

import SwiftUI
import AVFoundation
import Photos

// MARK: - Filter Type

enum FilterType: String, CaseIterable {
    case None = "None"
    case Chrome = "CIPhotoEffectChrome"
    case Fade = "CIPhotoEffectFade"
    case Instant = "CIPhotoEffectInstant"
    case Mono = "CIPhotoEffectMono"
    case Noir = "CIPhotoEffectNoir"
    case Process = "CIPhotoEffectProcess"
    case Tonal = "CIPhotoEffectTonal"
    case Transfer = "CIPhotoEffectTransfer"
    case Bloom = "CIBloom"
    case ComicEffect = "CIComicEffect"
    case Crystallize = "CICrystallize"
    case EdgeWork = "CIEdgeWork"
    case Gloom = "CIGloom"
    case HexagonalPixellate = "CIHexagonalPixellate"
    case Pixellate = "CIPixellate"
    case SepiaTone = "CISepiaTone"
    case Vignette = "CIVignette"
    
    func getNext() -> FilterType {
        guard let currentIndex = Self.allCases.firstIndex(of: self) else {
            return Self.allCases.first!
        }
        let nextIndex = (currentIndex + 1) % Self.allCases.count
        return Self.allCases[nextIndex]
    }
}

// MARK: - Camera View

struct CameraView: View {
    enum SelectedCameraMenu {
        case filters
        case effect
        case none
    }
    
    @State private var selectedCameraMenu = SelectedCameraMenu.none
    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?
    @State private var didTapCapture: Bool = false
    @State private var didTapReverseInt: Int = 0
    @State private var filterType = FilterType.None
    @State private var isFront = true
    @State private var isCapturing = false
    @State private var countdown = 3
    @State private var showCountdown = false
    @State private var shouldCaptureSecondPhoto = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            CustomCameraRepresentable(
                frontImage: $frontImage,
                backImage: $backImage,
                didTapCapture: $didTapCapture,
                didTapReverseInt: $didTapReverseInt,
                filterType: $filterType,
                isFront: $isFront,
                isCapturing: $isCapturing,
                showCountdown: $showCountdown,
                countdown: $countdown,
                shouldCaptureSecondPhoto: $shouldCaptureSecondPhoto
            )
            .background(
                VStack {
                    ProgressView()
                        .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: UIColor.systemGray6))
            )
            
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
            
            VStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        if selectedCameraMenu == .filters || selectedCameraMenu == .none {
                            Button {
                                withAnimation(.spring()) {
                                    if selectedCameraMenu == .filters {
                                        selectedCameraMenu = .none
                                    } else if selectedCameraMenu == .none {
                                        selectedCameraMenu = .filters
                                    }
                                }
                            } label: {
                                Image(systemName: "camera.filters")
                                    .font(.system(size: 28))
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .padding(4)
                                    .foregroundColor(.white)
                            }
                        }
                        if selectedCameraMenu == .effect || selectedCameraMenu == .none {
                            Button {
                                withAnimation(.spring()) {
                                    if selectedCameraMenu == .effect {
                                        selectedCameraMenu = .none
                                    } else if selectedCameraMenu == .none {
                                        selectedCameraMenu = .effect
                                    }
                                }
                            } label: {
                                Image(systemName: "camera")
                                    .font(.system(size: 28))
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .padding(4)
                                    .foregroundColor(.white)
                            }
                        }
                        if selectedCameraMenu == .filters {
                            Group {
                                ForEach(FilterType.allCases, id: \.self) { filter in
                                    Button(action: {
                                        filterType = filter
                                    }) {
                                        Text(filter.rawValue)
                                            .font(.headline)
                                            .padding(8)
                                            .background(.ultraThinMaterial)
                                            .overlay {
                                                Capsule()
                                                    .stroke(lineWidth: 4)
                                                    .foregroundColor(filterType == filter ? Color.gray : Color.clear)
                                            }
                                            .foregroundColor(.white)
                                            .clipShape(Capsule())
                                            .shadow(radius: 8)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                HStack {
                    // Camera rotation button
                    Button {
                        isFront.toggle()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 24))
                            .padding(.horizontal, 20)
                            .foregroundColor(.white)
                    }
                    .disabled(isCapturing)
                    .opacity(isCapturing ? 0.5 : 1.0)
                    
                    // Capture button (centered)
                    CaptureButtonView()
                        .onTapGesture {
                            if !isCapturing {
                                isCapturing = true
                                didTapCapture = true
                            }
                        }
                        .disabled(isCapturing)
                        .opacity(isCapturing ? 0.5 : 1.0)
                    
                    // Placeholder for balance
                    Spacer()
                        .frame(width: 70, height: 70)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Custom Camera Representable

struct CustomCameraRepresentable: UIViewControllerRepresentable {
    @Binding var frontImage: UIImage?
    @Binding var backImage: UIImage?
    @Binding var didTapCapture: Bool
    @Binding var didTapReverseInt: Int
    @Binding var filterType: FilterType
    @Binding var isFront: Bool
    @Binding var isCapturing: Bool
    @Binding var showCountdown: Bool
    @Binding var countdown: Int
    @Binding var shouldCaptureSecondPhoto: Bool
    
    func makeUIViewController(context: Context) -> CustomCameraController {
        let controller = CustomCameraController()
        if filterType != .None {
            controller.filter = CIFilter(name: filterType.rawValue)
        } else {
            controller.filter = nil
        }
        controller.isFront = isFront
        let coordinator1 = Coordinator1(self, controller: controller)
        let coordinator2 = Coordinator2(self, controller: controller)
        controller.delegate1 = coordinator1
        controller.delegate2 = coordinator2
        return controller
    }
    
    func updateUIViewController(_ cameraViewController: CustomCameraController, context: Context) {
        if filterType == .None {
            cameraViewController.filter = nil
        } else {
            if cameraViewController.filter?.name != CIFilter(name: filterType.rawValue)?.name {
                cameraViewController.filter = CIFilter(name: filterType.rawValue)
            }
        }
        
        if didTapCapture {
            // Immediately reset to prevent multiple triggers
            didTapCapture = false
            
            // Create callbacks and pass directly to controller
            let firstPhotoCallback: () -> Void = {
                // First photo taken, switch camera and start countdown
                isFront.toggle()
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
            }
            
            cameraViewController.didTapRecord(isFront: isFront, onFirstPhotoComplete: firstPhotoCallback, onSecondPhotoComplete: secondPhotoCallback)
        }
        
        if shouldCaptureSecondPhoto {
            cameraViewController.didTapRecordSecondPhoto(isFront: isFront)
            shouldCaptureSecondPhoto = false
        }
        
        if isFront != cameraViewController.isFront {
            if isFront {
                cameraViewController.setFrontCam()
            } else {
                cameraViewController.setBackCam()
            }
            cameraViewController.isFront = isFront
        }
    }
    
    class Coordinator1: NSObject, UINavigationControllerDelegate, AVCapturePhotoCaptureDelegate {
        let parent: CustomCameraRepresentable
        weak var controller: CustomCameraController?
        
        init(_ parent: CustomCameraRepresentable, controller: CustomCameraController) {
            self.parent = parent
            self.controller = controller
        }
        
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            print("Photo output 1")
            if let imageData = photo.fileDataRepresentation() {
                let im = UIImage(data: imageData)
                let ciImage: CIImage = CIImage(cgImage: im!.cgImage!).oriented(forExifOrientation: 6)
                
                var finalImage: UIImage
                if parent.filterType == .None {
                    print("Setting front image (no filter)")
                    finalImage = UIImage(ciImage: ciImage)
                } else {
                    let filter = CIFilter(name: parent.filterType.rawValue)
                    filter?.setValue(ciImage, forKey: "inputImage")
                    
                    print("Setting front image")
                    finalImage = UIImage.convert(from: filter!.outputImage!)
                }
                
                parent.frontImage = finalImage
                
                // Save to photo library
                savePhotoToLibrary(finalImage)
            }
            
            // Notify first photo is complete
            DispatchQueue.main.async { [weak self] in
                self?.controller?.onFirstPhotoComplete?()
            }
        }
        
        private func savePhotoToLibrary(_ image: UIImage) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    print("Photo library authorization denied or restricted: \(status.rawValue)")
                    return
                }
                
                PHPhotoLibrary.shared().performChanges({
                    _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            print("Photo saved to library successfully")
                        } else if let error = error {
                            print("Error saving photo: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    class Coordinator2: NSObject, UINavigationControllerDelegate, AVCapturePhotoCaptureDelegate {
        let parent: CustomCameraRepresentable
        weak var controller: CustomCameraController?
        
        init(_ parent: CustomCameraRepresentable, controller: CustomCameraController) {
            self.parent = parent
            self.controller = controller
        }
        
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            print("Photo output 2", photo)
            
            if let error = error {
                print("Error capturing photo: \(error)")
                return
            }
            
            if let imageData = photo.fileDataRepresentation() {
                let im = UIImage(data: imageData)
                let ciImage: CIImage = CIImage(cgImage: im!.cgImage!).oriented(forExifOrientation: 6)
                
                var finalImage: UIImage
                if parent.filterType == .None {
                    print("Setting back image (no filter)")
                    finalImage = UIImage(ciImage: ciImage)
                } else {
                    print("filter name is for 2", parent.filterType.rawValue)
                    let filter = CIFilter(name: parent.filterType.rawValue)
                    filter?.setValue(ciImage, forKey: "inputImage")
                    
                    print("Setting back image")
                    finalImage = UIImage.convert(from: filter!.outputImage!)
                }
                
                parent.backImage = finalImage
                
                // Save to photo library
                savePhotoToLibrary(finalImage)
            } else {
                print("failed to get data from image 2")
            }
            
            // Notify second photo is complete
            DispatchQueue.main.async { [weak self] in
                self?.controller?.onSecondPhotoComplete?()
            }
        }
        
        private func savePhotoToLibrary(_ image: UIImage) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    print("Photo library authorization denied or restricted: \(status.rawValue)")
                    return
                }
                
                PHPhotoLibrary.shared().performChanges({
                    _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            print("Photo saved to library successfully")
                        } else if let error = error {
                            print("Error saving photo: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Custom Camera Controller

class CustomCameraController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var image: UIImage?
    var filter: CIFilter?
    
    var captureSession = AVCaptureMultiCamSession()
    var backCamera: AVCaptureDevice?
    var frontCamera: AVCaptureDevice?
    var currentCamera: AVCaptureDevice?
    var photoOutput1: AVCapturePhotoOutput?
    var photoOutput2: AVCapturePhotoOutput?
    var cameraPreviewLayer: UIImageView?
    
    var frontCameraVideoDataOutput = AVCapturePhotoOutput()
    var backCameraVideoDataOutput = AVCapturePhotoOutput()
    var backPreviewCameraVideoDataOutput = AVCaptureVideoDataOutput()
    var frontPreviewCameraVideoDataOutput = AVCaptureVideoDataOutput()
    
    var captureDeviceInput1Thing: AVCaptureInput? = nil
    
    var delegate1: AVCapturePhotoCaptureDelegate?
    var delegate2: AVCapturePhotoCaptureDelegate?
    
    var isFront = false
    
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
    
    func didTapRecord(isFront: Bool, onFirstPhotoComplete: @escaping () -> Void, onSecondPhotoComplete: @escaping () -> Void) {
        print("record tapped")
        
        self.onFirstPhotoComplete = onFirstPhotoComplete
        self.onSecondPhotoComplete = onSecondPhotoComplete
        
        let photoSettings = AVCapturePhotoSettings()
        
        // Take photo from current camera only
        if isFront {
            frontCameraVideoDataOutput.capturePhoto(with: photoSettings, delegate: delegate1!)
        } else {
            backCameraVideoDataOutput.capturePhoto(with: photoSettings, delegate: delegate1!)
        }
    }
    
    func didTapRecordSecondPhoto(isFront: Bool) {
        print("record second photo")
        
        let photoSettings = AVCapturePhotoSettings()
        
        // Take photo from the other camera
        if isFront {
            backCameraVideoDataOutput.capturePhoto(with: photoSettings, delegate: delegate2!)
        } else {
            frontCameraVideoDataOutput.capturePhoto(with: photoSettings, delegate: delegate2!)
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
        
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let rearCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get cameras")
            return
        }
        
        let frontCameraDeviceInput = try! AVCaptureDeviceInput(device: frontCamera)
        let backCameraDeviceInput = try! AVCaptureDeviceInput(device: rearCamera)
        
        captureSession.addInputWithNoConnections(frontCameraDeviceInput)
        captureSession.addInputWithNoConnections(backCameraDeviceInput)
        
        captureSession.addOutputWithNoConnections(backPreviewCameraVideoDataOutput)
        captureSession.addOutputWithNoConnections(frontPreviewCameraVideoDataOutput)
        captureSession.addOutputWithNoConnections(frontCameraVideoDataOutput)
        captureSession.addOutputWithNoConnections(backCameraVideoDataOutput)
        
        let frontCameraVideoPort = frontCameraDeviceInput.ports(for: .video,
                                                                 sourceDeviceType: frontCamera.deviceType,
                                                                 sourceDevicePosition: AVCaptureDevice.Position(rawValue: frontCamera.position.rawValue) ?? .front).first
        
        let backCameraVideoPort = backCameraDeviceInput.ports(for: .video,
                                                              sourceDeviceType: backCamera?.deviceType,
                                                              sourceDevicePosition: AVCaptureDevice.Position(rawValue: (backCamera?.position)!.rawValue) ?? .back).first
        
        let backPreviewCameraVideoDataOutputConnection = AVCaptureConnection(inputPorts: [backCameraVideoPort!], output: backPreviewCameraVideoDataOutput)
        let frontPreviewCameraVideoDataOutputConnection = AVCaptureConnection(inputPorts: [frontCameraVideoPort!], output: frontPreviewCameraVideoDataOutput)
        let frontCameraVideoDataOutputConnection = AVCaptureConnection(inputPorts: [frontCameraVideoPort!], output: frontCameraVideoDataOutput)
        let backCameraVideoDataOutputConnection = AVCaptureConnection(inputPorts: [backCameraVideoPort!], output: backCameraVideoDataOutput)
        
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
    }
    
    func setupDevice() {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
                                                                      mediaType: AVMediaType.video,
                                                                      position: AVCaptureDevice.Position.unspecified)
        for device in deviceDiscoverySession.devices {
            switch device.position {
            case .front:
                self.frontCamera = device
            case .back:
                self.backCamera = device
            default:
                break
            }
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
        
        if let filter = filter {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            
            if let outputImage = filter.outputImage {
                DispatchQueue.main.async {
                    let aspectRatio = ciImage.extent.width / ciImage.extent.height
                    let newWidth = self.view.frame.height * aspectRatio
                    let newFrame = CGRect(x: self.view.frame.origin.x, y: self.view.frame.origin.y, width: newWidth, height: self.view.frame.height)
                    self.cameraPreviewLayer!.frame = newFrame
                    self.cameraPreviewLayer!.image = UIImage(ciImage: outputImage)
                }
            }
        } else {
            // No filter - show original image
            DispatchQueue.main.async {
                let aspectRatio = ciImage.extent.width / ciImage.extent.height
                let newWidth = self.view.frame.height * aspectRatio
                let newFrame = CGRect(x: self.view.frame.origin.x, y: self.view.frame.origin.y, width: newWidth, height: self.view.frame.height)
                self.cameraPreviewLayer!.frame = newFrame
                self.cameraPreviewLayer!.image = UIImage(ciImage: ciImage)
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

// MARK: - UIImage Extension

extension UIImage {
    static func convert(from ciImage: CIImage) -> UIImage {
        let context: CIContext = CIContext(options: nil)
        let cgImage: CGImage = context.createCGImage(ciImage, from: ciImage.extent)!
        let image: UIImage = UIImage(cgImage: cgImage)
        return image
    }
}
