import Foundation
import AVFoundation
import UIKit
import Combine
import SwiftUI

class CameraService: NSObject {
    enum CameraError: Error {
        case cameraUnavailable
        case cannotAddInput
        case cannotAddOutput
        case createCaptureInput(Error)
        case deniedAuthorization
        case restrictedAuthorization
        case unknownAuthorization
        case photoProcessingFailed
        case captureError
        case noImageData
    }
    
    // MARK: - Properties
    var session: AVCaptureSession?
    var delegate: AVCapturePhotoCaptureDelegate?
    
    let output = AVCapturePhotoOutput()
    let previewLayer = AVCaptureVideoPreviewLayer()
    
    private let sessionQueue = DispatchQueue(label: "com.receiptscanner.sessionQueue")
    private let photoOutput = AVCapturePhotoOutput()
    
    private var isCaptureSessionConfigured = false
    private var setupResult: SessionSetupResult = .success
    
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    
    private var photoCaptureCompletions = [Int64: (Result<UIImage, Error>) -> Void]()
    
    private var photoData = PassthroughSubject<Data, Error>()
    
    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    // MARK: - Combine Publishers
    var isSessionRunning: Bool {
        guard let session = session else { return false }
        return session.isRunning
    }
    
    // MARK: - Permission Handling
    func checkPermissions() -> AnyPublisher<Bool, CameraError> {
        return Future<Bool, CameraError> { promise in
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                promise(.success(true))
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        promise(.success(true))
                    } else {
                        promise(.failure(.deniedAuthorization))
                    }
                }
            case .denied:
                promise(.failure(.deniedAuthorization))
            case .restricted:
                promise(.failure(.restrictedAuthorization))
            @unknown default:
                promise(.failure(.unknownAuthorization))
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Session Configuration
    func setupAndStartCaptureSession() -> AnyPublisher<Bool, CameraError> {
        return Future<Bool, CameraError> { [weak self] promise in
            guard let self = self else { return }
            
            self.sessionQueue.async {
                self.configureSession()
                
                switch self.setupResult {
                case .success:
                    self.session?.startRunning()
                    promise(.success(true))
                case .notAuthorized:
                    promise(.failure(.deniedAuthorization))
                case .configurationFailed:
                    promise(.failure(.cameraUnavailable))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    private func configureSession() {
        guard setupResult == .success else { return }
        
        session = AVCaptureSession()
        guard let session = session else {
            setupResult = .configurationFailed
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Add video input
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                defaultVideoDevice = frontCameraDevice
            }
            
            guard let videoDevice = defaultVideoDevice else {
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
            } else {
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .quality
        } else {
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
        
        // Configure preview layer
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }
    
    // MARK: - Capture Photo
    func capturePhoto() -> AnyPublisher<UIImage, Error> {
        return Future<UIImage, Error> { [weak self] promise in
            guard let self = self else { return }
            
            guard let session = self.session, session.isRunning else {
                promise(.failure(CameraError.captureError))
                return
            }
            
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.photoQualityPrioritization = .quality
            
            let photoCaptureProcessor = PhotoCaptureProcessor(
                requestedPhotoSettings: photoSettings,
                willCapturePhotoAnimation: {
                    // Flash animation can be added here
                },
                completionHandler: { [weak self] processor in
                    guard let self = self else { return }
                    
                    self.sessionQueue.async {
                        self.inProgressPhotoCaptureDelegates[processor.requestedPhotoSettings.uniqueID] = nil
                    }
                },
                photoProcessingHandler: { [weak self] success in
                    guard let self = self else { return }
                    
                    if success {
                        if let photoData = processor.photoData, let image = UIImage(data: photoData) {
                            promise(.success(image))
                        } else {
                            promise(.failure(CameraError.noImageData))
                        }
                    } else {
                        promise(.failure(CameraError.photoProcessingFailed))
                    }
                }
            )
            
            self.sessionQueue.async {
                self.inProgressPhotoCaptureDelegates[photoSettings.uniqueID] = photoCaptureProcessor
                self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Session Management
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.session else { return }
            if !session.isRunning && self.setupResult == .success {
                session.startRunning()
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.session else { return }
            if session.isRunning {
                session.stopRunning()
            }
        }
    }
    
    // MARK: - Temporary Storage
    func saveImageToTemporaryStorage(_ image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving image to temporary storage: \(error)")
            return nil
        }
    }
}

// MARK: - Photo Capture Processor
class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private(set) var requestedPhotoSettings: AVCapturePhotoSettings
    private let willCapturePhotoAnimation: () -> Void
    private let completionHandler: (PhotoCaptureProcessor) -> Void
    private let photoProcessingHandler: (Bool) -> Void
    
    private var photoData: Data?
    
    init(requestedPhotoSettings: AVCapturePhotoSettings,
         willCapturePhotoAnimation: @escaping () -> Void,
         completionHandler: @escaping (PhotoCaptureProcessor) -> Void,
         photoProcessingHandler: @escaping (Bool) -> Void) {
        self.requestedPhotoSettings = requestedPhotoSettings
        self.willCapturePhotoAnimation = willCapturePhotoAnimation
        self.completionHandler = completionHandler
        self.photoProcessingHandler = photoProcessingHandler
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        willCapturePhotoAnimation()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error processing photo: \(error)")
            photoProcessingHandler(false)
            return
        }
        
        self.photoData = photo.fileDataRepresentation()
        photoProcessingHandler(true)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        completionHandler(self)
    }
}

// MARK: - Camera Preview View
class CameraPreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}