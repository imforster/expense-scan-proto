import Foundation
import AVFoundation
import UIKit
import Combine

// This is a placeholder for the CameraService that will be implemented in task 2.1
class CameraService {
    enum CameraError: Error {
        case cameraUnavailable
        case cannotAddInput
        case cannotAddOutput
        case createCaptureInput(Error)
        case deniedAuthorization
        case restrictedAuthorization
        case unknownAuthorization
    }
    
    // Will be implemented in task 2.1
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
}