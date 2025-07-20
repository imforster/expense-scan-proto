import Foundation
import AVFoundation
import UIKit
import SwiftUI

/// Service for managing camera access, permissions, and image capture
@MainActor
class CameraService: NSObject, ObservableObject {
    static let shared = CameraService()
    
    @Published var isAuthorized = false
    @Published var isSessionRunning = false
    @Published var capturedImage: UIImage?
    @Published var errorMessage: String?
    
    let session = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((Result<UIImage, Error>) -> Void)?
    
    override init() {
        super.init()
        checkCameraPermission()
    }
    
    // MARK: - Permission Handling
    
    /// Checks current camera permission status
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            requestCameraPermission()
        case .denied, .restricted:
            isAuthorized = false
            errorMessage = "Camera access is required to scan receipts. Please enable camera access in Settings."
        @unknown default:
            isAuthorized = false
            errorMessage = "Unknown camera permission status."
        }
    }
    
    /// Requests camera permission from the user
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if !granted {
                    self?.errorMessage = "Camera access is required to scan receipts. Please enable camera access in Settings."
                }
            }
        }
    }
    
    // MARK: - Session Management
    
    /// Sets up the camera capture session
    func setupCaptureSession() {
        guard isAuthorized else {
            errorMessage = "Camera access not authorized"
            return
        }
        
        // Don't setup if already configured
        if !session.inputs.isEmpty && !session.outputs.isEmpty {
            return
        }
        
        session.beginConfiguration()
        
        // Remove any existing inputs and outputs first
        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }
        
        // Configure session preset for high quality photos
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
        
        // Add video input
        do {
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                throw CameraError.deviceNotFound
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                throw CameraError.cannotAddInput
            }
        } catch {
            errorMessage = "Failed to set up camera input: \(error.localizedDescription)"
            session.commitConfiguration()
            return
        }
        
        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            // Configure photo output settings
            photoOutput.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024)
            if let connection = photoOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
        } else {
            errorMessage = "Cannot add photo output to the session"
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
    }
    
    /// Starts the camera capture session
    func startSession() {
        guard isAuthorized else {
            checkCameraPermission()
            return
        }
        
        if !session.isRunning {
            Task {
                await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        guard let self = self else {
                            continuation.resume()
                            return
                        }
                        self.session.startRunning()
                        DispatchQueue.main.async {
                            Task { @MainActor in
                                self.isSessionRunning = self.session.isRunning
                            }
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }
    
    /// Stops the camera capture session
    func stopSession() {
        if session.isRunning {
            Task {
                await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        guard let self = self else {
                            continuation.resume()
                            return
                        }
                        self.session.stopRunning()
                        DispatchQueue.main.async {
                            Task { @MainActor in
                                self.isSessionRunning = false
                            }
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Image Capture
    
    /// Captures a photo using the camera
    /// - Parameter completion: Completion handler with the captured image or error
    func capturePhoto(completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard isSessionRunning else {
            completion(.failure(CameraError.sessionNotRunning))
            return
        }
        
        self.captureCompletion = completion
        
        var settings = AVCapturePhotoSettings()
        
        // Configure photo settings
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        }
        
        // Enable high resolution capture if available
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        
        // Configure flash mode
        if let videoDeviceInput = videoDeviceInput,
           videoDeviceInput.device.isFlashAvailable {
            settings.flashMode = .auto
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    /// Captures a photo and stores it temporarily
    func capturePhotoAsync() async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            capturePhoto { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // MARK: - Focus and Exposure
    
    /// Sets focus and exposure point
    /// - Parameter point: The point to focus on (normalized coordinates 0-1)
    func setFocusAndExposure(at point: CGPoint) {
        guard let device = videoDeviceInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Set focus point
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            
            // Set exposure point
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error setting focus and exposure: \(error)")
        }
    }
    
    // MARK: - Torch Control
    
    /// Toggles the camera torch (flash)
    func toggleTorch() {
        guard let device = videoDeviceInput?.device, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            device.unlockForConfiguration()
        } catch {
            print("Error toggling torch: \(error)")
        }
    }
    
    /// Gets the current torch state
    var isTorchOn: Bool {
        return videoDeviceInput?.device.torchMode == .on
    }
    
    // MARK: - Image Orientation Correction
    
    /// Corrects the orientation of captured images to ensure proper display
    /// - Parameter image: The original captured image
    /// - Returns: Image with corrected orientation
    private func correctImageOrientation(_ image: UIImage) -> UIImage {
        // For receipt scanning, images with .up orientation often appear upside down
        // Apply 180-degree rotation to fix this common camera capture issue
        if image.imageOrientation == .up {
            return rotateImage180Degrees(image)
        }
        
        // Calculate the proper size for the corrected image
        var correctedSize = image.size
        
        // For orientations that require 90 or 270 degree rotation, swap width and height
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            correctedSize = CGSize(width: image.size.height, height: image.size.width)
        default:
            break
        }
        
        // Create a graphics context with the corrected size
        UIGraphicsBeginImageContextWithOptions(correctedSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return image
        }
        
        // Apply the appropriate transformation based on the image orientation
        switch image.imageOrientation {
        case .down, .downMirrored:
            context.translateBy(x: correctedSize.width, y: correctedSize.height)
            context.rotate(by: .pi)
        case .left, .leftMirrored:
            context.translateBy(x: correctedSize.width, y: 0)
            context.rotate(by: .pi / 2)
        case .right, .rightMirrored:
            context.translateBy(x: 0, y: correctedSize.height)
            context.rotate(by: -.pi / 2)

        default:
            break
        }
        
        // Handle mirrored orientations
        switch image.imageOrientation {
        case .upMirrored, .downMirrored:
            context.translateBy(x: correctedSize.width, y: 0)
            context.scaleBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            context.translateBy(x: correctedSize.height, y: 0)
            context.scaleBy(x: -1, y: 1)
        default:
            break
        }
        
        // Draw the image in the corrected orientation
        if let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
        }
        
        guard let correctedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            // If correction fails, return the original image
            return image
        }
        
        return correctedImage
    }
    
    /// Rotates an image 180 degrees for upside-down correction
    /// - Parameter image: The image to rotate
    /// - Returns: Image rotated 180 degrees
    private func rotateImage180Degrees(_ image: UIImage) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return image
        }
        
        // Move to center, rotate 180 degrees, then move back
        context.translateBy(x: image.size.width / 2, y: image.size.height / 2)
        context.rotate(by: .pi)
        context.translateBy(x: -image.size.width / 2, y: -image.size.height / 2)
        
        // Draw the image
        image.draw(in: CGRect(origin: .zero, size: image.size))
        
        guard let rotatedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return image
        }
        
        return rotatedImage
    }
    
    // MARK: - Cleanup
    
    deinit {
        if session.isRunning {
            session.stopRunning()
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: @preconcurrency AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // Handle completion on main thread to access main actor properties
        DispatchQueue.main.async { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    self.captureCompletion?(.failure(error))
                    return
                }
                
                guard let imageData = photo.fileDataRepresentation(),
                      let image = UIImage(data: imageData) else {
                    self.captureCompletion?(.failure(CameraError.imageProcessingFailed))
                    return
                }
                
                // Store the captured image as-is since users are guided to proper orientation
                self.capturedImage = image
                self.captureCompletion?(.success(image))
                self.captureCompletion = nil
            }
        }
    }
}

// MARK: - Camera Errors

enum CameraError: LocalizedError {
    case deviceNotFound
    case cannotAddInput
    case cannotAddOutput
    case sessionNotRunning
    case imageProcessingFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Camera device not found"
        case .cannotAddInput:
            return "Cannot add camera input to session"
        case .cannotAddOutput:
            return "Cannot add photo output to session"
        case .sessionNotRunning:
            return "Camera session is not running"
        case .imageProcessingFailed:
            return "Failed to process captured image"
        case .permissionDenied:
            return "Camera permission denied"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .deviceNotFound:
            return "Please ensure your device has a working camera"
        case .cannotAddInput, .cannotAddOutput:
            return "Please restart the app and try again"
        case .sessionNotRunning:
            return "Please ensure camera permissions are granted"
        case .imageProcessingFailed:
            return "Please try taking the photo again"
        case .permissionDenied:
            return "Please enable camera access in Settings"
        }
    }
}